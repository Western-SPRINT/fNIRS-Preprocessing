classdef QCTrimSegment < internal.PipelineStep
    %% Parameters
    properties
        Suffix                                                                                              = "Segment"
        SegmentSeconds                  (1,1) double {mustBePositive}                                       = 300
        SCIThreshold                    (1,1) double {mustBeBetween(SCIThreshold, 0, 1)}                    = 0.6
        PSPThreshold                    (1,1) double {mustBeBetween(PSPThreshold, 0, 1)}                    = 0.1
        IgnoreChannelsBelowRatioClean   (1,1) double {mustBeBetween(IgnoreChannelsBelowRatioClean, 0, 1)}   = 0.3
    end

    %% Core Properties
    properties (Constant)
        Name        = "Trim Timeseries to Cleanest Segment"
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
        PropertiesThatAffectData = ["SegmentSeconds" , "SCIThreshold" , "PSPThreshold" , "IgnoreChannelsBelowRatioClean"]
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

            % Calculate ratio of clean samples in each channel
            measures.channels.ratioClean = mean(cleanChannel, 2);

            % Ignore sub-threshold channels (and anything pre-excluded)
            channelsIgnored = measures.channels.ratioClean < obj.IgnoreChannelsBelowRatioClean;
            channels = getChannels(data);
            for i = find(channels.Excluded)'
                toRemove = (measures.channels.source == channels.source(i)) & (measures.channels.detector == channels.detector(i));
                channelsIgnored(toRemove) = true;
            end
            data.demographics.('TrimSegment_IgnoredChannels') = measures.channels(channelsIgnored,:);
            if any(channelsIgnored)
                measures.channels(channelsIgnored,:)    = [];
                measures.SCI(channelsIgnored,:)         = [];
                measures.PSP(channelsIgnored,:)         = [];
            end

            % Average across remaining channels
            cleanOverall = mean(cleanChannel, 1);

            % Sample counts
            samplesSegment = round(obj.SegmentSeconds * data.Fs);
            samplesTotal = length(data.time);

            % Acquisition is too short?
            too_short = samplesTotal < samplesSegment;
            if too_short
                warningTraceless("Acquisition is shorter than trimmed segment: %s", data.demographics.FullName)
                indKeep = 1 : samplesTotal;
                bestValue = nan;
            else
                % Find best segment start time...
                bestValue = 0;
                bestStart = nan;
                for i = 1 : (samplesTotal - samplesSegment - 1)
                    value = mean(cleanOverall(i:(i+samplesSegment-1)));
                    if value > bestValue % new best segment
                        bestValue = value;
                        bestStart = i;
                    end
                end

                % Time points of best segment
                indKeep = bestStart : (bestStart + samplesSegment - 1);
            end

            % Store results
            data.demographics.('TrimSegment_TooShort') = too_short;
            data.demographics.('TrimSegment_Start') = data.time(indKeep(1));        % convert sample index to time
            data.demographics.('TrimSegment_End') = data.time(indKeep(end));        % convert sample index to time

            % Reduce to segment
            data.demographics.SCIPSP.time = data.demographics.SCIPSP.time(indKeep);
            data.demographics.SCIPSP.SCI = data.demographics.SCIPSP.SCI(:,indKeep);
            data.demographics.SCIPSP.PSP = data.demographics.SCIPSP.PSP(:,indKeep);
            data.time = data.time(indKeep);
            data.data = data.data(indKeep, :);
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

            % sample times to label
            samples = round(linspace(1, length(obj.FigureData.Prior.time), 10));
            times = round(obj.FigureData.Prior.time(samples));
            
            % SCI/PSP
            metrics = obj.FigureData.Prior.demographics.SCIPSP;
            
            % % % remove ignored channels from obj.FigureData.Prior.data and metrics
            % % for i = 1:height(data.demographics.TrimSegment_IgnoredChannels)
            % %     s = data.demographics.TrimSegment_IgnoredChannels.source(i);
            % %     d = data.demographics.TrimSegment_IgnoredChannels.detector(i);
            % % 
            % %     select = (metrics.channels.source==s) & (metrics.channels.detector==d);
            % %     metrics.channels(select,:) = [];
            % %     metrics.SCI(select,:) = [];
            % %     metrics.PSP(select,:) = [];
            % % 
            % %     select = (obj.FigureData.Prior.probe.link.source==s) & (obj.FigureData.Prior.probe.link.detector==d);
            % %     obj.FigureData.Prior.probe.link(select, :) = [];
            % %     obj.FigureData.Prior.data(:, select) = [];
            % % end

            % remove pre-excluded channels...
            channels = getChannels(data);

            select = data.probe.link.Excluded;
            data.data(:, select) = [];
            data.probe.link(select, :) = [];

            select = obj.FigureData.Prior.probe.link.Excluded;
            obj.FigureData.Prior.data(:, select) = [];
            obj.FigureData.Prior.probe.link(select, :) = [];

            for i = find(channels.Excluded)'
                toRemove = (metrics.channels.source == channels.source(i)) & (metrics.channels.detector == channels.detector(i));
                metrics.channels(toRemove,:) = [];
                metrics.SCI(toRemove,:) = [];
                metrics.PSP(toRemove,:) = [];
            end
            
            %%
            
            subplot(2,4,[1 2])
            
            nDatatypes = length(data.probe.types);
            [datatypeNames, datatypeColours] = getDatatypeNamesColours(data.probe.types);
            datatypeColours(:,4) = 0.5;
            
            p = nan(1, nDatatypes);
            hold on
                % draw raw intensity
                for i = 1:nDatatypes
                    select = selectLinkDatatype(obj.FigureData.Prior, obj.FigureData.Prior.probe.types(i));
                    plot(obj.FigureData.Prior.data(:, select), Color=datatypeColours(i,:));
                    p(i) = plot(nan, nan, Color=datatypeColours(i,:), LineWidth=5);
                end
            
                % draw selection
                yl = [0 nanmax(obj.FigureData.Prior.data(:))];
                sampleStart = find(obj.FigureData.Prior.time == data.time(1));
                sampleEnd = find(obj.FigureData.Prior.time == data.time(end));
                rectangle(Position=[sampleStart yl(1) (sampleEnd-sampleStart) range(yl)], FaceColor=[1 1 0], FaceAlpha=0.25, EdgeColor=[0 0 0 0])
            hold off
            
            legend(p, datatypeNames, Location="NorthEast")
            
            title("Selected Segment")
            xlim([1 length(obj.FigureData.Prior.time)])
            ylim(yl)
            xlabel("Time (sec)")
            ylabel("Raw Intensity")
            set(gca, XTick=samples, XTickLabel=times)
            
            
            %% QC Metrics
            
            subplot(2,4,[5 6])
            
            % combined gradient to display
            quality = (metrics.SCI + metrics.PSP) / 2;
            
            % set sub-threshold to 0 quality
            clean = single((metrics.SCI > obj.SCIThreshold) & (metrics.PSP > obj.PSPThreshold));
            clean(isnan(metrics.SCI) | isnan(metrics.PSP)) = nan;
            quality(isnan(clean)) = nan;
            quality(clean==0) = 0;
            
            imagesc(quality)
            colormap([linspace(0.9,0.9,100)' linspace(0,0.9,100)' linspace(0,0.9,100)'])
            % colorbar
            ylabel("Channels")
            xlabel("Time (sec)")
            set(gca, XTick=samples, XTickLabel=times)
            title("Sample Viability")
            
            yl = ylim;
            hold on
                rectangle(Position=[sampleStart yl(1) (sampleEnd-sampleStart) range(yl)], FaceColor=[1 1 0], FaceAlpha=0.25, EdgeColor=[0 0 0 0])
            hold off
            ylim(yl)

            
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