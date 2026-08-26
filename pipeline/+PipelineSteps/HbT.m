classdef HbT < internal.PipelineStep
    %% Parameters
    properties
        Suffix                             = "HbT"
        ReorderByChromophore (1,1) logical = true
    end

    %% Core Properties
    properties (Constant)
        Name        = "Calculate HbT"
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
            % Get all SD pairs
            channels = getChannels(data);

            % For each channel...
            for c = 1:height(channels)
                % row in link table
                row = height(data.probe.link) + 1;

                % excluded?
                excluded = any( data.probe.link.Excluded(channels.TypeIndicesInLinks{c}) );

                % add to link table
                data.probe.link(row, :) = {channels.source(c) , channels.detector(c) , {'hbt'} , channels.ShortSeperation(c) , excluded };

                % add to data.data (HbT = HbR + HbO)
                data.data(:, row) = sum(data.data(:,channels.TypeIndicesInLinks{c}), 2);
            end

            % (Optional) Re-order to HbO, HbR, HbT
            if obj.ReorderByChromophore
                order = [find(strcmp(data.probe.link.type, "hbo"));
                         find(strcmp(data.probe.link.type, "hbr"));
                         find(strcmp(data.probe.link.type, "hbt"))];
                data.data = data.data(:, order);
                data.probe.link = data.probe.link(order, :);
            end
        end
    end

    %% Figure
    methods (Access = protected)
        function StepSpecificFigurePost(obj, pipeline, data, tableRow)
            % Count channels
            channels = getChannels(data);
            nChannels = height(channels);

            % How many columns will be needed?
            obj.FigureData.channelsPerColumn = obj.FigureChannelsPerColumn;
            obj.FigureData.nColumn = ceil(nChannels / obj.FigureData.channelsPerColumn);

            % Set figure size
            obj.SetFigureSize(5 + ((obj.FigureData.nColumn + 2)*25), 15)

            % Set scaling
            values = data.data(:, ~data.probe.link.Excluded);
            if obj.FigureNormalize
                values = values ./ nanstd(values, 1);
            end
            obj.FigureData.scale = nanmean(nanstd(values, 1)) * 3.0;

            % Setup tiles
            tiledlayout(1, obj.FigureData.nColumn + 2, TileSpacing="tight")

            % Input name
            name = "With HbT";

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