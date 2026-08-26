classdef SummaryFigure < internal.PipelineStep
    %% Parameters
    properties
        Suffix = "Summary"
    end

    %% Core Properties
    properties (Constant)
        Name        = "Generate Figures to Summarize Core Steps"
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
        PropertiesThatAffectData = []
        CanGenerateFigure        = true
        MustGenerateFigure       = true
        SavesData                = false
        IncludeInSummary         = false
        RunType                  = "PerAcquisition"
    end

    %% Overrides

    methods (Access = protected)
        function [data] = StepSpecificAcquisitionProcessing(obj, pipeline, data, tableRow)
            % Count steps to include
            nSteps = nnz([pipeline.Steps.IncludeInSummary]);

            % For each step...
            p = pipeline.copy;
            p.ClearSteps();
            initialized = false;
            for step = pipeline.Steps(:)'
                % Build pipeline
                p.AddStep(step);

                % Get suffix
                [~,suffix] = p.GetFinalSuffix();

                % Draw?
                if step.IncludeInSummary
                    % Load
                    filepath = getAcquisitionFilepath(obj, p, tableRow, suffix);
                    file = load(filepath);
                    
                    % If this is the first, initialize the figure
                    if ~initialized
                        % Set channels per column
						obj.SetNumberOfColumns(file.data);

                        % Set figure size
                        obj.SetFigureSize(5 + ((obj.FigureData.nColumn + 2)*25), (15 * nSteps))

                        % Setup tiles
                        tiledlayout(nSteps, obj.FigureData.nColumn + 2, TileSpacing="tight")

                        % Figure initialized
                        initialized = true;
                    end

                    % Select scaling factor
                    if isnumeric(file.data.probe.types)
                        % wavelengths
                        scale = 2;
                    else
                        % chromophores
                        scale = 3;
                    end

                    % Set scaling
                    values = file.data.data(:, ~file.data.probe.link.Excluded);
                    if obj.FigureNormalize
                        values = values ./ nanstd(values, 1);
                    end
                    obj.FigureData.scale = nanmean(nanstd(values, 1)) * scale;

                    % Input name
                    name = step.Suffix;

                    % Draw stacked plots in nColumn
                    obj.DrawStackedPlotColumns(file.data, name, obj.FigureNormalize);

                    % Fourier
                    nexttile
                    obj.DrawFourier(p, file.data, name);

                    % Correlation
                    nexttile
                    obj.DrawDataCorrMatrix(file.data, name);

                    % Main title
                    sgtitle(strrep(file.data.demographics.FullName, "_", "\_"), FontSize=obj.FONT_SIZE_TITLE, FontWeight="bold")
                end
            end
        end
    end
end