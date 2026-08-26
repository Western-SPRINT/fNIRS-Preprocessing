classdef ConnectivityGroup < internal.PipelineStep
    %% Parameters
    properties
        Suffix                                                                                          = "Group"
        MinShortChannels    (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(MinShortChannels, 0)} = 0
        MinLongChannels     (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(MinLongChannels, 0)}  = 0
        MinDurationSeconds  (1,1) double {mustBeGreaterThanOrEqual(MinDurationSeconds, 0)}              = 0
        MinDurationFlexibility (1,1) double {mustBeGreaterThanOrEqual(MinDurationFlexibility, 0)}       = 1 % accept durations that are within 1s of MinDurationSeconds 
        FigureZThresh       (1,1) double {mustBeGreaterThanOrEqual(FigureZThresh,0)}                    = 0
        FigurepThresh       (1,1) double {mustBeBetween(FigurepThresh,0,1)}                             = 1;
        FigureqThresh       (1,1) double {mustBeBetween(FigureqThresh,0,1)}                             = 1;
    end

    %% Core Properties
    properties (Constant)
        Name        = "Calculate Group Connectivity"
        Description = ""
    end
    properties (SetAccess = protected, Hidden)
        % LatestDataAffectingUpdate - Tracks changes to core logic and critical defaults
        %
        % 2026-08-12: first version
        LatestDataAffectingUpdate = datetime(2026, 08, 12)

        % TableFields - required fields and validation for acquisition table
        TableFields = []
    end
    properties (Constant, Hidden)
        PropertiesThatAffectData = ["MinShortChannels" , "MinLongChannels" , "MinDurationSeconds" , "MinDurationFlexibility"]
        CanGenerateFigure   = true
        MustGenerateFigure  = false
        SavesData           = true
        IncludeInSummary    = false
        RunType             = "Group"
    end

    %% Overrides
    methods (Access = protected)
        function ProcessGroup(obj, pipeline, suffixIn, suffixOut)
            %% Requires PipelineSteps.Connectivity
            if ~pipeline.ContainsStep("PipelineSteps.Connectivity")
                error("PipelineSteps.Connectivity must be run before PipelineSteps.ConnectivityGroup")
            end


            %% Exists?
            filepathOut = pipeline.FolderOut + "derivatives" + filesep + "Group" + suffixOut + ".mat";
            if exist(filepathOut, "file") && ~pipeline.Overwrite
                %TODO: log
                return
            end
            

            %% Group Estimate

            % Initialize table
            groupInfo = pipeline.Table(:, ["Subject_Number" "Session_Number" "Run_Number"]);
            groupInfo.ViableSDC(:) = nan;
            groupInfo.ViableLDC(:) = nan;
            groupInfo.Duration(:) = nan;

            % for each acquisition...
            for acq = 1:pipeline.countAcquisitions
                % get filepath
                filepathIn = obj.getAcquisitionFilepath(pipeline, pipeline.Table(acq,:), suffixIn);

                % load
                file = load(filepathIn);

                % Count viable SDC
                %   If SDC regression was run, use SDCReg_ViableSDCs
                %   Otherwise, use Connectivity_DeletedViableSDCs
                if file.data.demographics.iskey('SDCReg_ViableSDCs')
                    groupInfo.ViableSDC(acq) = file.data.demographics.SDCReg_ViableSDCs;
                elseif file.data.demographics.iskey('Connectivity_DeletedViableSDCs')
                    groupInfo.ViableSDC(acq) = file.data.demographics.Connectivity_DeletedViableSDCs;
                else
                    % possible if there weren't any SDC
                    groupInfo.ViableSDC(acq) = 0;
                end

                % Count viable LDC
                channels = getChannels(file.data);
                groupInfo.ViableLDC(acq) = nnz(~channels.ShortSeperation & ~channels.Excluded);

                % Store duration
                groupInfo.Duration(acq) = range(file.data.demographics.SCIPSP.time);

                % Initialize R matrices and channel viability
                if acq==1
                    allZ = nan([size(file.data.R) pipeline.countAcquisitions]);

                    LDCExclusions = removevars(channels, ["ShortSeperation" "Excluded"]);
                    LDCExclusions.Exclusions = false(height(LDCExclusions), pipeline.countAcquisitions);
                end

                % Get Z, set excluded to NaN
                Z = file.data.Z;
                Z(file.data.probe.link.Excluded, :) = nan;
                Z(:, file.data.probe.link.Excluded) = nan;

                % Store viable LDC
                LDCExclusions.Exclusions(:,acq) = channels.Excluded;

                % Store Z
                allZ(:,:,acq) = Z;
            end
            
            % Which acquisitions to use?
            groupInfo.Selected = (groupInfo.ViableSDC >= obj.MinShortChannels) & ...
                           (groupInfo.ViableLDC >= obj.MinLongChannels) & ...
                           (groupInfo.Duration >= (obj.MinDurationSeconds - obj.MinDurationFlexibility));
            
            % Write table to csv
            filepath = obj.getFolderFigure(pipeline) + "Group_" + suffixOut.extractAfter(1) + ".csv";
            if exist(filepath, "dir")
                delete(filepath);
            end
            writetable(groupInfo, filepath);

            % Display table
            disp(groupInfo)

            % Stop if no datasets were selected
            if ~any(groupInfo.Selected)
                warningTraceless("No acquisitions were selected for the criteria. Stopping early!")
                if obj.GenerateFigure
                    close(obj.FigureData.Handle) % prevents save and background bloat
                end
                return
            end

            % WARNING: currently, all acquisitions are weighted equally
            % which can cause issues if a subject has more sessions/runs

            % Calculate group average Z
            Z = nanmean(allZ(:,:,groupInfo.Selected), 3);

            % Convert back to R
            R = tanh(Z);                  % inverse Fisher
            R(logical(eye(size(R)))) = 1; % set diagonal to exactly 1

            % Reduce to selected channels, count viable acq per channel
            LDCExclusions.Exclusions = LDCExclusions.Exclusions(:, groupInfo.Selected);
            LDCExclusions.NumberViable = size(LDCExclusions.Exclusions, 2) - sum(LDCExclusions.Exclusions, 2);

            % Store in an sFCStats
            data = file.data;
            data.R = R;
            data.dfe = nnz(groupInfo.Selected) - 1; % df is number of acquisitions selected minus 1
            data.demographics = Dictionary;
            data.demographics.LDCExclusions = LDCExclusions;
            data.demographics.GroupAcquisitionInfo = groupInfo;
            data.probe.link.Excluded = isnan(data.R(:, 1));

            % Save
            save(filepathOut, "data", "pipeline")

            %% Figure
            if obj.GenerateFigure
                % Percent Viable
                subplot(1,8,1:3)
                obj.DrawPercentChannelViability(data, LDCExclusions);

                % HbO/HbR Matrix
                subplot(1,8,4:5)
                obj.DrawDataCorrMatrix(data);
                title("Group: All Z-Values")

                % HbT 2D Montage
                subplot(1,8,6:8)
                obj.DrawData2DConnectivity(data, "Group: HbT Z-Values", "hbt", obj.FigureZThresh, obj.FigurepThresh, obj.FigureqThresh);
            end

        end
    end

    %% Figures
    methods (Access = protected)
        function StepSpecificFigureSetup(obj)
            obj.SetFigureSize(60,20);
        end

        function DrawPercentChannelViability(obj, data, LDCExclusions)
            % Counts
            nChannel = height(LDCExclusions);
            nAcq = size(LDCExclusions.Exclusions, 2);

            % Colour map
            colourGreat = [0.1 0.8 0.1];
            colourPoor =  [0.8 0.1 0.1];
            n = 1 + nAcq;
            cmap = cell2mat(arrayfun(@(a,b) linspace(a,b,n)', colourPoor, colourGreat, 'UniformOutput', false));

            hold on

                % Draw coloured channel lines
                srcUsed = false(1, size(data.probe.srcPos, 1));
                detUsed = false(1, size(data.probe.detPos, 1));
                for i = 1:nChannel
                    s = LDCExclusions.source(i);
                    d = LDCExclusions.detector(i);

                    srcUsed(s) = true;
                    detUsed(d) = true;

                    x = [data.probe.srcPos(s,1) data.probe.detPos(d,1)];
                    y = [data.probe.srcPos(s,2) data.probe.detPos(d,2)];

                    colour = cmap(1 + LDCExclusions.NumberViable(i), :);

                    plot(x, y, Color=colour, LineWidth=3);
                end

                % Draw optodes
                markerSize = 3;
                plot(data.probe.srcPos(srcUsed,1), data.probe.srcPos(srcUsed,2), "ro", MarkerFaceColor="r", MarkerSize=markerSize);
                plot(data.probe.detPos(detUsed,1), data.probe.detPos(detUsed,2), "bo", MarkerFaceColor="b", MarkerSize=markerSize);
                
            hold off

            axis equal off

            cb = colorbar;
            colormap(gca, cmap)
            clim([0 nAcq])
            if nAcq < 15
                cb.XTick = 0:nAcq;
            end

            title("Number of Acquisitions with Viable Data")
        end
    end
end