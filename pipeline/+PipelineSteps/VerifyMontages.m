classdef VerifyMontages < internal.PipelineStep
    %% Parameters
    properties
        Suffix = "Montage"
    end
    
    %% Core Properties
    properties (Constant)
        Name        = "Verify Montages"
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
        PropertiesThatAffectData = [];
        CanGenerateFigure        = true
        MustGenerateFigure       = false
        SavesData                = false
        IncludeInSummary         = false
        RunType                  = "Group"
    end

    %% Overrides
    methods (Access = protected)
        function ProcessGroup(obj, pipeline, suffixIn, suffixout)
            % for each acquisition...
            for acq = 1:pipeline.countAcquisitions
                % get filepath
                filepathIn = obj.getAcquisitionFilepath(pipeline, pipeline.Table(acq,:), suffixIn);

                % load
                file = load(filepathIn);

                % get probe
                probe = file.data.probe;

                % if this is the first, store it for comparison
                if acq == 1
                    target = probe;
                else
                    % if this is acquisition 2+, compare to the target...
                    if ~PipelineSteps.VerifyMontages.compareMontage(probe, target, false)
                        error("The following acquisition has a different montage: %s", data.demographics.FullName)
                    end
                end
            end

            % create figure?
            if obj.GenerateFigure
                obj.DrawMontage(file.data);
            end
        end
    end

    %% Private Static

    methods (Access = private, Static)
        function [same] = compareMontage(montage_source, montage_target, link_only)

            %default
            same = true;

            %link table
            if any(size(montage_source.link) ~= size(montage_target.link))
                same = false;
                return
            else
                %check S/D index
                check = (montage_source.link.detector ~= montage_target.link.detector) | ...
                    (montage_source.link.source ~= montage_target.link.source);

                %check data type
                if isnumeric(montage_source.link.type(1))
                    check = check | (montage_source.link.type ~= montage_target.link.type);
                else
                    check = check | ~strcmp(montage_source.link.type, montage_target.link.type);
                end

                if any(check(:))
                    same = false;
                    return
                end
            end

            %source positions
            if link_only
                ind_to_check = unique(montage_source.link.source);
                srcPos = montage_source.srcPos(ind_to_check,:);
                trgPos = montage_target.srcPos(ind_to_check,:);
            else
                srcPos = montage_source.srcPos;
                trgPos = montage_target.srcPos;
            end
            if any(size(srcPos) ~= size(trgPos))
                same = false;
                return
            else
                check = srcPos ~= trgPos;
                if any(check(:))
                    same = false;
                    return
                end
            end

            %detector positions
            if link_only
                ind_to_check = unique(montage_source.link.detector);
                srcPos = montage_source.detPos(ind_to_check,:);
                trgPos = montage_target.detPos(ind_to_check,:);
            else
                srcPos = montage_source.detPos;
                trgPos = montage_target.detPos;
            end
            if any(size(srcPos) ~= size(trgPos))
                same = false;
                return
            else
                check = srcPos ~= trgPos;
                if any(check(:))
                    same = false;
                    return
                end
            end
        end
    end

    %% Figure
    methods (Access = protected)
        function StepSpecificFigureSetup(obj)
            obj.SetFigureSize(60,20);
        end

        function DrawMontage(obj, data)
            %% Shortcuts and Counts
            probe = data.probe;
            templateLengths = data.demographics.TemplateLengths;
            nSource = size(probe.srcPos, 1);
            nDetector = size(probe.detPos, 1);
            nChannel = height(templateLengths);
            
            % Flag SDC detectors to draw as circles
            detectorSDCOnly = false(nDetector, 1);
            for d = 1:nDetector
                rows = find(templateLengths.detector == d);
                detectorSDCOnly(d) = length(rows)==1  && templateLengths.ShortSeperation(rows);
            
                % move to source position
                if detectorSDCOnly(d)
                    % 2D: draw on top of source
                    ind = strcmp(probe.optodes.Name, sprintf("Detector-%04d", d));
                    probe.optodes(ind,["X" "Y" "Z"]) = num2cell(probe.srcPos(templateLengths.source(rows), :));
            
                    % 3D; don't draw
                    ind = strcmp(probe.optodes_registered.Name, sprintf("Detector-%04d", d));
                    probe.optodes_registered(ind,["X" "Y" "Z"]) = {nan, nan, nan};
                end
            end
            
            
            %% 2D Montage
            subplot(2, 6, [1 2 7 8])
            
            hold on
            
            % Draw LDCs
            x = [];
            y = [];
            for i = 1:nChannel
                s = templateLengths.source(i);
                d = templateLengths.detector(i);
                if ~detectorSDCOnly(d)
                    x = [x nan probe.srcPos(s,1) probe.detPos(d,1)];
                    y = [y nan probe.srcPos(s,2) probe.detPos(d,2)];
                end
            end
            plot(x, y, "k", LineWidth=1);
            
            % Draw SDCs
            plot(probe.detPos(detectorSDCOnly,1), probe.detPos(detectorSDCOnly,2), "bo", MarkerFaceColor="b", MarkerSize=8)
            
            % Area size
            smallerDim = min([range(xlim) range(ylim)]);
            
            % Draw optodes
            markerSize = 3;
            textOffset = smallerDim * 0.01;
            plot(probe.srcPos(:,1), probe.srcPos(:,2), "ro", MarkerFaceColor="r", MarkerSize=markerSize);
            for i = 1:nSource
                text(probe.srcPos(i,1)+textOffset, probe.srcPos(i,2)+(textOffset*2), sprintf("S%d", i), Color="r")
            end
            plot(probe.detPos(~detectorSDCOnly,1), probe.detPos(~detectorSDCOnly,2), "bo", MarkerFaceColor="b", MarkerSize=markerSize);
            for i = 1:nDetector
                if detectorSDCOnly(i)
                    yOff = -textOffset * 2;
                else
                    yOff = +textOffset * 2;
                end
                text(probe.detPos(i,1)+textOffset, probe.detPos(i,2)+yOff, sprintf("D%d", i), Color="b")
            end
            
            hold off
            
            axis equal off
            
            %% 3D Montage
            
            % 4 views...
            for mode = 1:4
                switch mode
                    case 1
                        % Front
                        sp        = 3;
                        viewAngle = [180 40];
                    case 2
                        % Back
                        sp        = 4;
                        viewAngle = [0 40];
                    case 3
                        % Right
                        sp        = 9;
                        viewAngle = [90 20];
                    case 4
                        % Left
                        sp        = 10;
                        viewAngle = [-90 20];
                end
            
                % Set up 3D view
                subplot(2, 6, sp)
            
                % NIRS Toolbox 3D Ball
                probe = probe.SetFiducials_Visibility(false);
                probe.defaultdrawfcn = '3D ball';
                probe.draw(gca);
            
                % Fix lighting at back of head
                view([-30 20])
                camlight
            
                % Set view angle
                view(viewAngle);
            end
            
            %% Template Channel Lengths
            
            subplot(2, 6, [5 6 11 12])
            
            % Source-by-Detector Matrix
            lengths = nan(nSource, nDetector);
            for i = 1:nChannel
                lengths(templateLengths.source(i), templateLengths.detector(i)) = templateLengths.Length(i);
            end
            
            h = heatmap(lengths);
            xlabel("Detector")
            ylabel("Source")
            title(sprintf("Channel Lengths (on %dmm template)", data.demographics.headTemplate_mm))
        end
    end
end