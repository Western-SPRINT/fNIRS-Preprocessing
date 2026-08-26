classdef OpticalDensity < internal.PipelineStep
    %% Parameters
    properties
        Suffix = "OD"
    end

    %% Core Properties
    properties (Constant)
        Name        = "Convert Raw Intensity to Optical Density"
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
        MustGenerateFigure       = false
        SavesData                = true
        IncludeInSummary         = true
        RunType                  = "PerAcquisition"
    end

    %% Overrides

    methods (Access = protected)
        function [data] = StepSpecificAcquisitionProcessing(obj, pipeline, data, tableRow)
            % Ensure that raw timeseries is in data.data (not QC timeseries)
            if data.demographics.iskey('RawTimecourse')
                error("Demographics still contains RawTimecourse, which means that QCCalculate was not run.", data.demographics.FullName)
            end

            % OD from NIRS Toolbox
            jobs = nirs.modules.OpticalDensity;

            % Run job
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
            name = "Raw Intensity";

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
            % Set scaling (separate from input)
            values = data.data(:, ~data.probe.link.Excluded);
            if obj.FigureNormalize
                values = values ./ nanstd(values, 1);
            end
            obj.FigureData.scale = nanmean(nanstd(values, 1)) * 2.0;

            % Output name
            name = "Optical Density";

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