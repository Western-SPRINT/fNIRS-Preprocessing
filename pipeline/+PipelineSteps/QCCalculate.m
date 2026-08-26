classdef QCCalculate < internal.PipelineStep
    %% Parameters
    properties
        Suffix                                                                                = "SCIPSP"
        WindowSeconds (1,1) double {mustBePositive}                                           = 3.0
        ParallelPools (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(ParallelPools,0)} = 0
    end

    %% Core Properties
    properties (Constant)
        Name        = "Calculate SCI and PSP in a Sliding Window"
        Description = ""
    end
    properties (SetAccess = protected, Hidden)
        % LatestDataAffectingUpdate - Tracks changes to core logic and critical defaults
        %
        % 2026-08-12: first version
        LatestDataAffectingUpdate = datetime(2026, 08, 12)

        % TableFields - required fields and validation for acquisition table
        TableFields = { 
                        "Cardiac_Min_bpm" , @(x) isnumeric(x) && ~isnan(x) && x>0;
                        "Cardiac_Max_bpm" , @(x) isnumeric(x) && ~isnan(x) && x>0;
                      }
    end
    properties (Constant, Hidden)
        PropertiesThatAffectData = ["WindowSeconds"]
        CanGenerateFigure        = true
        MustGenerateFigure       = false
        SavesData                = true
        IncludeInSummary         = false
        RunType                  = "PerAcquisition"
    end

    %% Overrides

    methods (Access = protected)
        function StepSpecificSetup(obj)
            % Setup parallel pools
            if obj.ParallelPools > 0
                try
                    % get current pool
                    p = gcp('nocreate');
    
                    % close current pool?
                    if ~isempty(p)
                        if ~isa(p, "parallel.ThreadPool") || (p.NumWorkers ~= obj.ParallelPools)
                            delete(p);
                        end
                    end
    
                    % start new pool?
                    if isempty(p) || ~isvalid(p)
                        parpool("Threads", obj.ParallelPools);
                    end
                catch
                    warningTraceless("Failed to configure Parallel Pools, but will continue without this. Processing will be slower but results will be the same.")
                end
            end
        end

        function [data] = StepSpecificAcquisitionProcessing(obj, pipeline, data, tableRow)
            % Verify Cardiac_Max_bpm > Cardiac_Min_bpm
            if tableRow.Cardiac_Max_bpm <= tableRow.Cardiac_Min_bpm
                error("Cardiac_Max_bpm must be greater than Cardiac_Min_bpm! Error during: %s", data.demographics.FullName)
            end

            % Setup custom job
            jobs                            = calcSlidingSCI_v3;
            jobs.window_length_seconds      = obj.WindowSeconds;
            jobs.expected_cardiac_bpm_min   = tableRow.Cardiac_Min_bpm;
            jobs.expected_cardiac_bpm_max   = tableRow.Cardiac_Max_bpm;
            jobs.calc_PSP                   = true;
            jobs.samples_to_run             = []; % leave this empty to run all windows

            % Run
            data.demographics.SCIPSP = jobs.run(data);

            % If QC Motion Correction was run, restore timeseries to raw and remove the backup
            if pipeline.ContainsStep("PipelineSteps.QCMotionCorrection")
                data.data = data.demographics.RawTimecourse;
                data.demographics = data.demographics.remove('RawTimecourse');
            end

            % Store cardiac range used
            data.demographics.CardiacRange_bpm = [tableRow.Cardiac_Min_bpm tableRow.Cardiac_Max_bpm];
        end
    end

    %% Figure
    methods (Access = protected)
        function StepSpecificFigureSetup(obj)
            obj.SetFigureSize(30,30);
        end

        % function StepSpecificFigurePre(obj, pipeline, data, tableRow)
        %     % Store current data.data in case MC was performed
        %     obj.FigureData.values = data.data;
        % end

        function StepSpecificFigurePost(obj, pipeline, data, tableRow)
            %% Setup

            % % Use motion-corrected if it was run
            % data.data = obj.FigureData.values;

            metrics = data.demographics.SCIPSP;

            colourGreat = [0.1 0.8 0.1];
            colourMid =   [0.8 0.8 0.1];
            colourPoor =  [0.8 0.1 0.1];

            tiledlayout(3, 1, TileSpacing="tight")


            % Remove excluded channels...
            channels = getChannels(data);

            select = data.probe.link.Excluded;
            data.data(:, select) = [];
            data.probe.link(select, :) = [];

            for i = find(channels.Excluded)'
                toRemove = (metrics.channels.source == channels.source(i)) & (metrics.channels.detector == channels.detector(i));
                metrics.channels(toRemove,:) = [];
                metrics.SCI(toRemove,:) = [];
                metrics.PSP(toRemove,:) = [];
            end

            % sample times to label
            samples = round(linspace(1, length(data.time), 10));
            times = round(data.time(samples));


            %% Grid Plot
            % % nexttile
            % % 
            % % % order by channel, not datatype
            % % [~,~,order] = unique(data.probe.link(:, ["source" "detector"]));
            % % 
            % % % center and normalize
            % % values = data.data(:, order);
            % % values = values - nanmean(values, 1);
            % % values = values ./ nanstd(values, 1);
            % % 
            % % % grid plot
            % % imagesc(values')
            % % set(gca, XTick=samples, XTickLabel=times)
            % % colormap(gca, bone)
            % % title("Normalized Raw Intensities")
            % % ylabel("Channels x Wavelengths")
            % % xlabel("Time (sec)")


            %% Basic Plot

            nexttile

            nDatatypes = length(data.probe.types);
            [datatypeNames, datatypeColours] = getDatatypeNamesColours(data.probe.types);
            datatypeColours(:,4) = 0.5;

            p = nan(1, nDatatypes);
            hold on
            for i = 1:nDatatypes
                select = selectLinkDatatype(data, data.probe.types(i));
                plot(data.data(:, select), Color=datatypeColours(i,:));
                p(i) = plot(nan, nan, Color=datatypeColours(i,:), LineWidth=5);
            end
            hold off
            
            legend(p, datatypeNames, Location="NorthEast")

            title("Raw Intensity")
            xlim([1 length(data.time)])
            xlabel("Time (sec)")
            set(gca, XTick=samples, XTickLabel=times)


            %% SCI

            nexttile

            imagesc(metrics.SCI)
            set(gca, XTick=samples, XTickLabel=times)
            clim([0 1])
            colorbar
            ylabel("Channels")
            xlabel("Time (sec)")
            title("Scalp Coupling Index")

            n = 60;
            cmap = cell2mat(arrayfun(@(a,b) linspace(a,b,n)', colourPoor, colourMid, 'UniformOutput', false));
            n = 30;
            cmap = [cmap; cell2mat(arrayfun(@(a,b) linspace(a,b,n)', colourMid, colourGreat, 'UniformOutput', false))];
            n = 10;
            cmap = [cmap; cell2mat(arrayfun(@(a,b) linspace(a,b,n)', colourGreat, colourGreat, 'UniformOutput', false))];
            colormap(gca, cmap)


            %% PSP

            nexttile

            imagesc(metrics.PSP)
            set(gca, XTick=samples, XTickLabel=times)
            clim([0 1])
            colorbar
            ylabel("Channels")
            xlabel("Time (sec)")
            title("Peak Spectral Power")

            n = 10;
            cmap = cell2mat(arrayfun(@(a,b) linspace(a,b,n)', colourPoor, colourMid, 'UniformOutput', false));
            n = 15;
            cmap = [cmap; cell2mat(arrayfun(@(a,b) linspace(a,b,n)', colourMid, colourGreat, 'UniformOutput', false))];
            n = 75;
            cmap = [cmap; cell2mat(arrayfun(@(a,b) linspace(a,b,n)', colourGreat, colourGreat, 'UniformOutput', false))];
            colormap(gca, cmap)


            %% Label

            % Main title
            sgtitle(strrep(data.demographics.FullName, "_", "\_"), FontSize=obj.FONT_SIZE_TITLE, FontWeight="bold")
        end
    end

end