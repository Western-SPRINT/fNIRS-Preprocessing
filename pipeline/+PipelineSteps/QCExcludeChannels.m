classdef QCExcludeChannels < internal.PipelineStep
    %% Parameters
    properties
        Suffix                                                                                              = "ExcludeChannels"
        SCIThreshold                    (1,1) double {mustBeBetween(SCIThreshold, 0, 1)}                    = 0.6
        PSPThreshold                    (1,1) double {mustBeBetween(PSPThreshold, 0, 1)}                    = 0.1
        ExcludeChannelsBelowRatioClean  (1,1) double {mustBeBetween(ExcludeChannelsBelowRatioClean, 0, 1)}  = 0.6
        tSNRThreshold                   (1,1) double {mustBeGreaterThanOrEqual(tSNRThreshold, 0)}           = 0     % if >0: Exclude any channels with sub-threshold tSNR (averaged across wavelengths)
    end

    %% Core Properties
    properties (Constant)
        Name        = "Exclude Low-Quality Channels"
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
        PropertiesThatAffectData = ["SCIThreshold" , "PSPThreshold" , "ExcludeChannelsBelowRatioClean" , "tSNRThreshold"]
        CanGenerateFigure        = true
        MustGenerateFigure       = false
        SavesData                = true
        IncludeInSummary         = true
        RunType                  = "PerAcquisition"
    end

    %% Overrides
    methods (Access = protected)
        function [data] = StepSpecificAcquisitionProcessing(obj, pipeline, data, tableRow)
            % Get calculated SCI/PSP
            measures = data.demographics.SCIPSP;

            % Flag channel-samples as clean
            cleanChannel = single((measures.SCI > obj.SCIThreshold) & (measures.PSP > obj.PSPThreshold));

            % Calculate (and store) ratio of clean samples in each channel
            data.demographics.SCIPSP.channels.ratioClean = mean(cleanChannel, 2);

            % Flag sub-threshold channels for later exclusion (data is not modified at this time)
            channels_exclude = data.demographics.SCIPSP.channels.ratioClean < obj.ExcludeChannelsBelowRatioClean;

            % (Optional) Exclude any channels with sub-threshold tSNR (averaged across wavelengths)
            if obj.tSNRThreshold > 0
                % calculate tSNR for each signal
                tSNR = nanmean(data.data) ./ nanstd(data.data,[],1);

                % check each channel
                for i = 1:height(data.demographics.SCIPSP.channels)
                    s = data.demographics.SCIPSP.channels.source(i);
                    d = data.demographics.SCIPSP.channels.detector(i);

                    select = (data.probe.link.source==s) & (data.probe.link.detector==d);
                    tSNRMean = nanmean(tSNR(select));
                    if tSNRMean < obj.tSNRThreshold
                        channels_exclude(i) = true;
                    end
                end
            end

            % Store exclusions
            data.demographics.('ExcludedChannels') = data.demographics.SCIPSP.channels(channels_exclude,:);
            if any(channels_exclude)
                for i = find(channels_exclude(:)')
                    inds = (data.probe.link.source == measures.channels.source(i)) & ...
                        (data.probe.link.detector == measures.channels.detector(i));
                    data.probe.link.Excluded(inds) = true;
                end
            end
        end
    end

    methods (Access = protected)
        function StepSpecificFigureSetup(obj)
            obj.SetFigureSize(50,20);
        end

        function StepSpecificFigurePre(obj, pipeline, data, tableRow)
            obj.FigureData.Prior = data;
        end

        function StepSpecificFigurePost(obj, pipeline, data, tableRow)
            %% Setup

            nDatatypes = length(data.probe.types);
            [datatypeNames, datatypeColours] = getDatatypeNamesColours(data.probe.types);
            datatypeColours(:,4) = 0.5;

            %% Included/Excluded Channels

            for excluded = [false true]
                switch excluded
                    case false
                        % Included
                        sp = [5 6];
                        name = "Viable Channels";

                    case true
                        % Excluded
                        sp = [1 2];
                        name = "Excluded Channels";
                end

                subplot(2,4,sp)

                p = nan(1, nDatatypes);
                hold on
                % draw raw intensity
                for i = 1:nDatatypes
                    select = selectLinkDatatype(data, data.probe.types(i)) & (data.probe.link.Excluded == excluded);
                    if any(select)
                        plot(data.time, data.data(:, select), Color=datatypeColours(i,:));
                    end
                    p(i) = plot(nan, nan, Color=datatypeColours(i,:), LineWidth=5);
                end
                hold off

                legend(p, datatypeNames, Location="EastOutside")

                xlim(data.time([1 end]))
                xlabel("Time (sec)")
                ylabel("Raw Intensity")
                title(name)
            end


            %% Fourier before/after
            subplot(2,4,3)
            obj.DrawFourier(pipeline, obj.FigureData.Prior, "Before");

            subplot(2,4,7)
            obj.DrawFourier(pipeline, data, "After");


            %% Correlation matrix before/after
            subplot(2,4,4)
            obj.DrawDataCorrMatrix(obj.FigureData.Prior, "Before");

            subplot(2,4,8)
            obj.DrawDataCorrMatrix(data, "After");


            %% Label

            % Main title
            sgtitle(strrep(data.demographics.FullName, "_", "\_"), FontSize=obj.FONT_SIZE_TITLE, FontWeight="bold")
        end
    end
end