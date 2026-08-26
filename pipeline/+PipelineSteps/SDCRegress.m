classdef SDCRegress < internal.PipelineStep
    %% Parameters
    properties
        Suffix                                                                                      = "SDCReg"
        MaxComponents       (1,1) double                                                            = 6
        IndependentOxyDeoxy (1,1) logical                                                           = false
        ParallelPools       (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(ParallelPools,0)} = 0
    end

    %% Core Properties
    properties (Constant)
        Name        = "Regress out Short Distanec Channels (SDCs)"
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
        PropertiesThatAffectData = ["MaxComponents" , "IndependentOxyDeoxy"]
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
            % Count viable SDCs
            isViableSDC = (data.probe.link.ShortSeperation & ~data.probe.link.Excluded);
            countViableSDC = nnz(isViableSDC) / length(data.probe.types);

            % Only run regression if there is one or more viable SDC
            data.demographics.SDCReg_Performed = (countViableSDC > 0);
            data.demographics.SDCReg_ViableSDCs = countViableSDC;
            if data.demographics.SDCReg_Performed
                % SDC Regression (AR-IRLS) from NIRS Toolbox
                jobs = advanced.nirs.modules.ShortDistanceFilter;
                jobs.maxnumcomp = obj.MaxComponents; 
                jobs.splittypes = obj.IndependentOxyDeoxy; 

                % Delete excluded SDCs
                % Remaining SDCs will be used for regression and then also deleted right after
                toRemove = (data.probe.link.ShortSeperation & data.probe.link.Excluded);
                data.probe.link(toRemove, :) = [];
                data.data(:, toRemove) = [];

                % Run regression (using only the non-excluded SDCs)
                text = evalc('data = jobs.run(data);'); %redirect messages
            end

            % Remove SDCs
            jobs = nirs.modules.RemoveShortSeperations;
            data = jobs.run(data);
        end
    end

    %% Figure
    methods (Access = protected)
        function StepSpecificFigurePre(obj, pipeline, data, tableRow)
            % Set channels per column
			obj.SetNumberOfColumns(data);

            % Set figure size
            obj.SetFigureSize(5 + ((obj.FigureData.nColumn + 2)*25), 30)

            % Set scaling
            values = data.data(:, ~data.probe.link.Excluded);
            if obj.FigureNormalize
                values = values ./ nanstd(values, 1);
            end
            obj.FigureData.scale = nanmean(nanstd(values, 1)) * 3.0;

            % Setup tiles
            tiledlayout(2, obj.FigureData.nColumn + 2, TileSpacing="tight")

            % Input name
            name = "Before SDC Regression";

            % Draw stacked plots in nColumn
            obj.DrawStackedPlotColumns(data, name, obj.FigureNormalize);

            % Fourier
            nexttile
            obj.DrawFourier(pipeline, data, name);

            % Correlation
            nexttile
            obj.DrawDataCorrMatrix(data, name);
        end

        function StepSpecificFigurePost(obj, pipeline, data, tableRow)
            % Output name
            name = "After SDC Regression";

            % Draw stacked plots in nColumn
            obj.DrawStackedPlotColumns(data, name, obj.FigureNormalize);

            % Fourier
            nexttile
            obj.DrawFourier(pipeline, data, name);

            % Correlation
            nexttile
            obj.DrawDataCorrMatrix(data, name);

            % Main title
            sgtitle(strrep(data.demographics.FullName, "_", "\_"), FontSize=obj.FONT_SIZE_TITLE, FontWeight="bold")
        end
    end

end