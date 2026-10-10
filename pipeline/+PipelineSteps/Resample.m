classdef Resample < internal.PipelineStep
    %% Parameters
    properties
        Suffix = "Resample"
        FrequencyHz           (1,1) double {mustBePositive} = 4
        ResampleAuxillaryData (1,1) logical                 = true
    end

    %% Core Properties
    properties (Constant)
        Name        = "Resample"
        Description = "Resamples each timeseries to the specified frequency"
    end
    properties (SetAccess = protected, Hidden)
        % LatestDataAffectingUpdate - Tracks changes to core logic and critical defaults
        %
        % 2026-10-09: first version
        LatestDataAffectingUpdate = datetime(2026, 10, 09)

        % TableFields - required fields and validation for acquisition table
        TableFields = []
    end
    properties (Constant, Hidden)
        PropertiesThatAffectData = ["FrequencyHz"]
        CanGenerateFigure        = true
        MustGenerateFigure       = false
        SavesData                = true
        IncludeInSummary         = true
        RunType                  = "PerAcquisition"
    end

    %% Overrides

    methods (Access = protected)
        function [data] = StepSpecificAcquisitionProcessing(obj, pipeline, data, tableRow)
            % Resample from NIRS Toolbox
            jobs = nirs.modules.Resample;
            jobs.Fs = obj.FrequencyHz;
            jobs.Resample_Auxillary_Data = obj.ResampleAuxillaryData;

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
            name = "Before Resample";

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
            name = "After Resample";

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