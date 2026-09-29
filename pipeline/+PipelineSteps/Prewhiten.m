classdef Prewhiten < internal.PipelineStep
    %% Parameters
    properties
        Suffix = "Prewhiten"
        MaxSeconds     (1,1) double {mustBePositive}                                           = 5
        DeleteArtifact (1,1) logical                                                           = true
        ParallelPools  (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(ParallelPools,0)} = 0
    end

    %% Core Properties
    properties (Constant)
        Name        = "Autoregressive prewhitening"
        Description = "Model order uses BIC up to specified max duration in seconds"
    end
    properties (SetAccess = protected, Hidden)
        % LatestDataAffectingUpdate - Tracks changes to core logic and critical defaults
        %
        % 2026-08-12: first version
        LatestDataAffectingUpdate = datetime(2026, 09, 28)

        % TableFields - required fields and validation for acquisition table
        TableFields = []
    end
    properties (Constant, Hidden)
        PropertiesThatAffectData = ["MaxSeconds" , "DeleteArtifact"]
        CanGenerateFigure        = true
        MustGenerateFigure       = false
        SavesData                = true
        IncludeInSummary         = true
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
            % Autoregressive prewhitening from NIRS Toolbox
            jobs = advanced.nirs.modules.AR_Prewhiten;
            jobs.modelorder = obj.MaxSeconds;

            % Run job
            data = jobs.run(data);

            % Delete first "MaxSeconds" plus one to remove potential massive artifact
            if obj.DeleteArtifact
                removeBefore = obj.MaxSeconds + 1;
                toRemove = (data.time - data.time(1)) <= removeBefore;
                data.time(toRemove) = [];
                data.data(toRemove, :) = [];
            end
        end
    end

    %% Figure
    methods (Access = protected)
        function StepSpecificFigurePre(obj, pipeline, data, tableRow)
            % Set channels per column
			obj.SetNumberOfColumns(data);

            % Set figure size
            obj.SetFigureSize(5 + ((obj.FigureData.nColumn + 3)*25), 30)

            % Set scaling
            values = data.data(:, ~data.probe.link.Excluded);
            if obj.FigureNormalize
                values = values ./ nanstd(values, 1);
            end
            obj.FigureData.scale = nanmean(nanstd(values, 1)) * 3.0;

            % Setup tiles
            tiledlayout(2, obj.FigureData.nColumn + 3, TileSpacing="tight")

            % Input name
            name = "Before Prewhiten";

            % Draw stacked plots in nColumn
            obj.DrawStackedPlotColumns(data, name, obj.FigureNormalize);

            % Fourier
            nexttile
            obj.DrawFourier(pipeline, data, name);

            % Correlation
            nexttile
            obj.DrawDataCorrMatrix(data, name);

            % Autocorrelation
            nexttile
            obj.DrawAutocorr(data, name);
        end

        function StepSpecificFigurePost(obj, pipeline, data, tableRow)
            % Output name
            name = "After Prewhiten";

            % Adjust scaling
            values = data.data(:, ~data.probe.link.Excluded);
            if obj.FigureNormalize
                values = values ./ nanstd(values, 1);
            end
            obj.FigureData.scale = nanmean(nanstd(values, 1)) * 3.0;

            % Draw stacked plots in nColumn
            obj.DrawStackedPlotColumns(data, name, obj.FigureNormalize);

            % Fourier
            nexttile
            obj.DrawFourier(pipeline, data, name);

            % Correlation
            nexttile
            obj.DrawDataCorrMatrix(data, name);

            % Autocorrelation
            nexttile
            obj.DrawAutocorr(data, name);

            % Main title
            sgtitle(strrep(data.demographics.FullName, "_", "\_"), FontSize=obj.FONT_SIZE_TITLE, FontWeight="bold")
        end
    end

end