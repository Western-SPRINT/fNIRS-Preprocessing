classdef ImportRaw < internal.PipelineStep
    %% Parameters
    properties
        Suffix                                      = "Raw"
        SDCThresholdMM    (1,1) double              = 10        % if non-NaN: channel lengths less than this are flagged as short channels (in mm)
        SDCFixedLengthMM  (1,1) double              = 8         % if non-NaN: SDCs have their lengths overwritten with this fixed value (in mm)
        ScaleToHeadSize   (1,1) logical             = true      % if true: all channel lengths are linearly scaled to acquisition's head size (HeadSize_cm in the AcquisitionTable)
        ReplaceMesh       (1,1) logical             = true      % if true: replace NIRS Toolbox default head mesh with corresponding NIRSite mesh
        CustomFunction    (1,1) {mustBeFcnOrMissing}= missing   % if non-missing: this function is called on each acquisition during import, must accept data+tableRow and return data
                                                                %               getFunctionHandleFromPath(filepath) is included for convenience
        DeleteDemographics (1,1) logical            = true      % delete potentially identifying information in "data.demographics"
    end

    %% Core Properties
    properties (Constant)
        Name        = "Import Raw Data"
        Description = ""
    end
    properties (SetAccess = protected, Hidden)
        % LatestDataAffectingUpdate - Tracks changes to core logic and critical defaults
        %
        % 2026-08-12: first version
        LatestDataAffectingUpdate = datetime(2026, 08, 12)

        % TableFields - required fields and validation for acquisition table
        TableFields = { 
                        "Head_Circumference_cm" , @(x) isnumeric(x) && ~isnan(x) && x>0;
                        "Subject_Number"        , @(x) isnumeric(x) && ~isnan(x) && x>0 && (x==round(x));
                        "Session_Number"        , @(x) isnumeric(x) && ~isnan(x) && x>0 && (x==round(x));
                        "Run_Number"            , @(x) isnumeric(x) && ~isnan(x) && x>0 && (x==round(x));
                      }
    end
    properties (Constant, Hidden)
        PropertiesThatAffectData = ["SDCThresholdMM" , "SDCFixedLengthMM", "ScaleToHeadSize", "ReplaceMesh", "CustomFunction", "DeleteDemographics"]
        CanGenerateFigure        = true
        MustGenerateFigure       = false
        SavesData                = true
        IncludeInSummary         = true
        RunType                  = "PerAcquisition"
    end

    %% Getters

    methods
        function TableFields = get.TableFields(obj)
            % only require "Head_Circumference_cm" if ScaleToHeadSize==true
            if ~obj.ScaleToHeadSize
                TableFields = obj.TableFields(2:end,:);
            else
                TableFields = obj.TableFields;
            end
        end
    end

    %% Overrides

    methods (Access = protected)
        % Loads from NIRx raw files instead of .mat
        function [data, pipelinePrior] = LoadAcquisition(obj, pipeline, tableRow, label, suffixIn)
            % path to raw data folder
            folder = pipeline.FolderRaw + tableRow.Path_To_Raw;

            % folder must end with filesep
            if ~folder.endsWith("/") && ~folder.endsWith("\")
                folder = folder + filesep;
            end

            % load
            data = loadNIRx_NoDotNIRS(folder.char);

            % import is always first step, there is no prior pipeline
            pipelinePrior = [];

            % get head template from probeInfo
            list = dir(folder + filesep + "*_probeInfo.mat");
            if length(list)~=1
                error("Failed to located exactly one probeInfo.mat file in: %s", folder)
            else
                file = load([list.folder filesep list.name]);
                data.demographics.probeInfo = file.probeInfo;
            end

            % if no triggers were loaded, look for lsl.tri file instead
            if ~data.stimulus.count
                list = dir(folder + "*_lsl.tri");
                switch length(list)
                    case 0
                        % no file, nothing to do
                    case 1
                        % add triggers...
 
                        % load lsl triggers
                        triggers = readtable([list.folder filesep list.name], FileType="text");
                        triggers.Properties.VariableNames = ["Timestamp" "ZeroBasedIndex" "TriggerID"];
                        triggers.Sample = triggers.ZeroBasedIndex + 1;

                        % add each trigger
                        unique_trigger_IDs = unique(triggers.TriggerID(:)');
                        for id = unique_trigger_IDs
                            % find onsets
                            samples = triggers.Sample(triggers.TriggerID == id);
                            onsets = data.time(samples);

                            % create StimulusEvents
                            s = nirs.design.StimulusEvents();
                            s.name=['stim_channel' num2str(id)];
                            s.onset=onsets;
                            s.dur=ones(size(s.onset)) * (1 / data.Fs); % default duration to 1 sample
                            s.amp=ones(size(s.onset));

                            % store
                            data.stimulus(s.name)=s;
                        end
                    otherwise
                        % should not contain multiple tri files
                        error("No triggers were loaded, but multiple *_lsl.tri file were found. There should be only one of these files.")
                end
            end
        end

        function [data] = StepSpecificAcquisitionProcessing(obj, pipeline, data, tableRow)
            % Get probeInfo from load
            probeInfo = data.demographics.probeInfo;
            data.demographics = data.demographics.remove('probeInfo');
            template = probeInfo.headmodel;

            % (Optional) delete potentially identifying information in "data.demographics"
            %   Keep headmodel
            if obj.DeleteDemographics
                data.demographics = Dictionary;
            end

            % Add labels to demographics
            labels = parseBIDSLabelsFromRow(pipeline, tableRow);
            for f = string(fields(labels))'
                data.demographics.(f.char) = labels.(f).char;
            end

            % Set description
            data.description = labels.FullName.char;

            % Store the montage head model and the template's size
            switch template
                case "ICBM152"
                    template_mm = 610;
                case "Infant_00_02"
                    template_mm = 376;
                case "Infant_02_05"
                    template_mm = 411;
                case "Infant_05_08"
                    template_mm = 434;
                otherwise
                    error("Unsupported template: %s", template)
            end
            data.demographics.headTemplate = template;
            data.demographics.headTemplate_mm = template_mm;
            headsizeUsed_mm = template_mm;

            % Backup template channel lengths
            templateLengths = data.probe.distances;

            % (Optional) Scale channel lengths to head size
            if obj.ScaleToHeadSize
                % get distances
                fd = data.probe.distances;

                % linear scaling
                headsizeUsed_mm = tableRow.Head_Circumference_cm * 10;
                scale = headsizeUsed_mm / template_mm;
                fd = fd * scale;

                % store as fixed values
                data.probe.fixeddistances = fd;
            end

            % store the headsize used (template or resized)
            data.demographics.headsizeUsed_mm = headsizeUsed_mm;

            % update the "headsize" (even though it won't be used)
            headsize = Dictionary();
            headsize('circumference') = headsizeUsed_mm;
            data.probe = nirs.util.registerprobe1020(data.probe, headsize);

            % (Optional) Flag SDCs based on channel length
            if ~isnan(obj.SDCThresholdMM)
                data.probe.link.ShortSeperation = data.probe.distances < obj.SDCThresholdMM;
            else
                data.probe.link.ShortSeperation(:) = false;
            end

            % (Optional) Override SDC lengths to fixed value
            if ~isnan(obj.SDCFixedLengthMM)
                % get distances
                fd = data.probe.distances;

                % apply override
                fd(data.probe.link.ShortSeperation) = obj.SDCFixedLengthMM;

                % store as fixed values
                data.probe.fixeddistances = fd;

                % also apply to templateLengths
                templateLengths(data.probe.link.ShortSeperation) = obj.SDCFixedLengthMM;
            end

            % (Optional) Override mesh for visualization on NIRSite heads
            if obj.ReplaceMesh
                [scalp,brain,fiducials] = loadTemplate(template);
                
                % Match probe fiducials to template fiducials
                [found, inds] = ismember(probeInfo.probes.labels_s, fiducials.Name);
                probeInfo.probes.index_s = inds(found);
                [found, inds] = ismember(probeInfo.probes.labels_d, fiducials.Name);
                probeInfo.probes.index_d = inds(found);

                % scalp
                ind = 1;
                BEM(ind) = nirs.core.Mesh(scalp.nodes(:,end-2:end)*10, scalp.belems(:,end-2:end),[]);
                BEM(ind).transparency = 0.2;
                BEM(ind).fiducials = fiducials;

                % brain
                ind = 2;
                BEM(ind) = nirs.core.Mesh(brain.nodes(:,end-2:end)*10, brain.belems(:,end-2:end),[]);
                BEM(ind).transparency = 1.0;

                % forward model
                lambda=unique(data.probe.link.type);
                prop{1} = nirs.media.tissues.skin(lambda);
                prop{2} = nirs.media.tissues.bone(lambda);
                prop{3} = nirs.media.tissues.water(lambda);
                prop{4} = nirs.media.tissues.brain(lambda,0.7, 50);
                fwdBEM = nirs.forward.NirfastBEM;
                fwdBEM.mesh = BEM;
                fwdBEM.prop = prop;

                % apply 
                data.probe = data.probe.register_mesh2probe(fwdBEM.mesh, true);
                data.probe.opticalproperties = prop;

                % correct locations
                lst=[probeInfo.probes.index_s(:); probeInfo.probes.index_d(:)];
                XYZ=[fiducials.X(lst) fiducials.Y(lst) fiducials.Z(lst)];
                data.probe.optodes_registered = data.probe.optodes;
                data.probe.optodes_registered.X(1:length(lst))=XYZ(:,1);
                data.probe.optodes_registered.Y(1:length(lst))=XYZ(:,2);
                data.probe.optodes_registered.Z(1:length(lst))=XYZ(:,3);
            end

            % Mark all channels as non-excluded
            data.probe.link.Excluded(:) = false;

            % Store TemplateLengths
            tbl = data.probe.link;
            tbl.Length = templateLengths;
            tbl = tbl(tbl.type == data.probe.types(1), :);
            tbl = removevars(tbl, ["type" "Excluded"]);
            data.demographics.TemplateLengths = tbl;

            % (Optional) Custom function
            if ~ismissing(obj.CustomFunction)
                data = obj.CustomFunction(data, tableRow);
            end

            % Need to temporarily convert TemplateLengths to a matrix
            % because nirs.io.saveSNIRF cannot save tables.
            %
            % Note that TemplateLengths cannot be moved later because
            % CustomFunction might need to adjust it (e.g., global channel
            % exclusions)
            backup = data.demographics.TemplateLengths;
            data.demographics.TemplateLengths = table2array(data.demographics.TemplateLengths);

            % Save to SNIRF
            label = parseBIDSLabelsFromRow(pipeline, tableRow);
            folder = pipeline.FolderOut + label.Subject + filesep + label.Session + filesep + "nirs" + filesep;
            if ~exist(folder, "dir")
                mkdir(folder)
            end
            filepath = folder + label.FullName;
            nirs.io.saveSNIRF(data, [filepath.char '_fnirs.snirf'], false, true);
            nirs.bids.stim2JSON(data.stimulus, [filepath.char '_event.json']);
            nirs.bids.data2JSON(data, [filepath.char '_fnirs.json'], pipeline.TaskName.char);
            nirs.bids.probe2JSON(data.probe, [filepath.char '_coordsystem.json']);

            % Restore TemplateLengths
            data.demographics.TemplateLengths = backup;
        end
    end

    %% Figure
    methods (Access = protected)
        function StepSpecificFigureSetup(obj)
            obj.SetFigureSize(30,20);
        end

        function StepSpecificFigurePre(obj, pipeline, data, tableRow)
            % 2xN tiles
            numberWavelengths = length(data.probe.types);
            tiledlayout(2, numberWavelengths, TileSpacing="tight");
            obj.SetFigureSize(10 + (20*numberWavelengths),20);

            % Both will use the original time range
            obj.FigureData.xlim = data.time([1 end]);

            % Draw (before any processing)
            for wl = data.probe.types(:)'
                nexttile
                obj.DrawData(data, wl);
                title(sprintf("Loaded Timecourses and Triggers: %dnm", wl))
            end
        end

        function StepSpecificFigurePost(obj, pipeline, data, tableRow)
            % Draw (after any processing)
            for wl = data.probe.types(:)'
                nexttile
                obj.DrawData(data, wl);
                title(sprintf("Saved Timecourses and Events: %dnm", wl))
            end

            % Main title
            sgtitle(strrep(data.demographics.FullName, "_", "\_"), FontSize=obj.FONT_SIZE_TITLE, FontWeight="bold")
        end

        function DrawData(obj, data, wavelength)
            % reduce wavelengths
            select = (data.probe.link.type == wavelength);
            data.data = data.data(:, select);
            data.probe.link = data.probe.link(select, :);

            % Get y-limits
            yl = [nanmin(data.data(:)) nanmax(data.data(:))];

            hold on

            % Trigger/Event colours
            colours = jet(data.stimulus.count);

            % Draw triggers / events
            p = [];
            labels = "";
            for i = 1:data.stimulus.count
                labels(i) = string(data.stimulus.values{i}.name).replace("_","\_");
                colour = colours(i,:);
                p(i) = plot(nan, nan, Color=colour, LineWidth=5);

                for j = 1:data.stimulus.values{i}.count
                    on = data.stimulus.values{i}.onset(j);
                    dur = data.stimulus.values{i}.dur(j);
                    rectangle(Position=[on yl(1) dur range(yl)], FaceColor=colour, FaceAlpha=0.8, EdgeColor=colour);
                end
            end
            
            % Placeholder if no triggers / events
            if isempty(p)
                p = plot(nan, nan, "w");
                labels = "No triggers or events";
            end

            % Draw raw intensities
            plot(data.time, data.data);

            hold off

            % Legend
            legend(p, labels, Location="EastOutside")

            % Set limits
            xlim(obj.FigureData.xlim)
            ylim(yl);

            % Labels
            xlabel("Time (sec)")
            ylabel("Intensity")
        end
    end
end