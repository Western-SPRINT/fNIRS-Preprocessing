classdef Bandpass < internal.PipelineStep
    %% Parameters
    properties
        Suffix                                              = "Bandpass"
        Passband (1,2) double {mustBePositive, mustBeRange} = [0.009 0.080]
    end

    %% Core Properties
    properties (Constant)
        Name        = "Bandpass Filter"
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
        PropertiesThatAffectData = ["Passband"]
        CanGenerateFigure        = true
        MustGenerateFigure       = false
        SavesData                = true
        IncludeInSummary         = true
        RunType                  = "PerAcquisition"
    end

    %% Overrides

    methods (Access = protected)
        function [data] = StepSpecificAcquisitionProcessing(obj, pipeline, data, tableRow)
            % Custom Job
            %   After testing several methods, this seems to be the least
            %   likely to introduce edge and aliasing artifacts.
            jobs = bandpassFilterPadded;
            jobs.passbandFrequencies = obj.Passband;

            % Run job
            data = jobs.run(data);

            % Store passband used
            data.demographics.Passband = obj.Passband;
        end
    end

    %% Figure
    methods (Access = protected)
        function StepSpecificFigurePre(obj, pipeline, data, tableRow)
            % Count channels
            channels = getChannels(data);
            nChannels = height(channels);

            % How many columns will be needed?
            obj.FigureData.channelsPerColumn = obj.FigureChannelsPerColumn;
            obj.FigureData.nColumn = ceil(nChannels / obj.FigureData.channelsPerColumn);

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
            name = "Before Bandpass";

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
            name = "After Bandpass";

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