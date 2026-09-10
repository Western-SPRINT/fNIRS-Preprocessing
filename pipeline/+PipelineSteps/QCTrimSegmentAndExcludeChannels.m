classdef QCTrimSegmentAndExcludeChannels < internal.PipelineStep
    %% Parameters
    properties
        Suffix                                                                                              = "SegmentAndPrune"
        SegmentSeconds                  (1,1) double {mustBePositive}                                       = 300
        SCIThreshold                    (1,1) double {mustBeBetween(SCIThreshold, 0, 1)}                    = 0.6
        PSPThreshold                    (1,1) double {mustBeBetween(PSPThreshold, 0, 1)}                    = 0.1
        tSNRThreshold                   (1,1) double {mustBeGreaterThanOrEqual(tSNRThreshold, 0)}           = 0     % if >0: Exclude any channels with sub-threshold tSNR (averaged across wavelengths)
        ExcludeChannelsBelowRatioClean  (1,1) double {mustBeBetween(ExcludeChannelsBelowRatioClean, 0, 1)}  = 0.6
        PrioratizeSegmentsWithAtLeastOneSDC (1,1) logical                                                   = true  % whether or not a segment with 1+ viable SDC should automatically beat a segment with no viable SDCs
    end

    %% Core Properties
    properties (Constant)
        Name        = "Trim Timeseries to Cleanest Segment and Exclude Low-Quality Channels"
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
        PropertiesThatAffectData = ["SegmentSeconds" , "SCIThreshold" , "PSPThreshold" , "tSNRThreshold" , "ExcludeChannelsBelowRatioClean"]
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
            clean = single((measures.SCI > obj.SCIThreshold) & (measures.PSP > obj.PSPThreshold));

            % Sample counts
            samplesSegment = round(obj.SegmentSeconds * data.Fs);
            samplesTotal = length(data.time);

            % Organize channel info
            channels = data.demographics.SCIPSP.channels;
            for i = 1:height(data.demographics.SCIPSP.channels)
                % find in data.probe.link
                select = (data.probe.link.source == channels.source(i)) & ...
                         (data.probe.link.detector == channels.detector(i));
                
                channels.Indices{i} = find(select);
                channels.ShortSeperation(i) = any(data.probe.link.ShortSeperation(select));
                channels.Excluded(i) = any(data.probe.link.Excluded(select));
            end

            % Initialize best segment values...
            bestSegmentIndices  = [];       % where the current best segment is
            bestNumberChannels  = -inf;     % number of viable channels in current best
            bestHasSDC          = false;    % current best segment has at least one viable SDC
            bestOverallValue    = -inf;     % average SCI+PSP across viable channels (for breaking ties)
            bestExclusions      = [];       % track channel exclusions in best segment
            
            % Which onsets to test
            onsetsToTest = 1 : (samplesTotal - samplesSegment - 1);
            if isempty(onsetsToTest)
                onsetsToTest = 1; % if too short, use the full timecourse
            end

            % Find best segment...
            for i = onsetsToTest
                % select sample indices
                samples = i : min(i + samplesSegment, samplesTotal);
    
                % calculate channel tSNR, average across wavelengths
                tSNR = nanmean(data.data(samples, :)) ./ nanstd(data.data(samples, :), [], 1);
                tSNRChannel = cellfun(@(inds) nanmean(tSNR(inds)), channels.Indices);

                % calculate percent clean samples per channel
                cleanChannel = nanmean(clean(:, samples), 2);

                % which channels would be INcluded
                included = ~channels.Excluded & (tSNRChannel >= obj.tSNRThreshold) & (cleanChannel >= obj.ExcludeChannelsBelowRatioClean);

                % values
                numberChannels = nnz(included);
                hasSDC = any(channels.ShortSeperation(included));
                overallValue = nanmean(cleanChannel(included));

                % is this the new best segment?
                best = false;                                   % default to no
                if numberChannels > bestNumberChannels
                    best = true;                                % more included channels --> yes
                elseif numberChannels == bestNumberChannels
                    if overallValue > bestOverallValue
                        best = true;                            % same number of included channels, but higher quality --> Yes
                    end
                end

                % prioratize having at least one viable SDC? (overrides "best")
                if obj.PrioratizeSegmentsWithAtLeastOneSDC
                    if ~hasSDC && bestHasSDC
                        best = false;               % never select if best has SDC but this does not
                    elseif hasSDC && ~bestHasSDC
                        best = true;                % always select if best does not have SDC and this does
                    end
                end

                % new best?
                if best
                    bestSegmentIndices = samples;
                    bestNumberChannels = numberChannels;
                    bestHasSDC         = hasSDC;
                    bestOverallValue   = overallValue;
                    bestExclusions     = ~included;
                end
            end

            % Acquisition shorter than specified segment?
            tooShort = length(bestSegmentIndices) < samplesSegment;
            if tooShort
                warningTraceless("Acquisition is shorter than segment duration")
            end

            % Store segment result
            data.demographics.('TrimSegment_TooShort') = double(tooShort);
            data.demographics.('TrimSegment_Start') = data.time(bestSegmentIndices(1));
            data.demographics.('TrimSegment_End') = data.time(bestSegmentIndices(end));

            % Reduce to best segment
            data.demographics.SCIPSP.time = data.demographics.SCIPSP.time(bestSegmentIndices);
            data.demographics.SCIPSP.SCI = data.demographics.SCIPSP.SCI(:,bestSegmentIndices);
            data.demographics.SCIPSP.PSP = data.demographics.SCIPSP.PSP(:,bestSegmentIndices);
            data.time = data.time(bestSegmentIndices);
            data.data = data.data(bestSegmentIndices, :);
            
            % Apply exclusions (timecourses are not altered, just flagged)
            data.demographics.('ExcludedChannels') = channels(bestExclusions, ["source" "detector" "ShortSeperation"]);
            for i = find(bestExclusions(:)')
                data.probe.link.Excluded(channels.Indices{i}) = true;
            end
        end
    end

    methods (Access = protected)
        function StepSpecificFigureSetup(obj)
            obj.SetFigureSize(75,20);
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

            % datatypes
            nDatatypes = length(data.probe.types);
            [datatypeNames, datatypeColours] = getDatatypeNamesColours(data.probe.types);
            datatypeColours(:,4) = 0.5;


            %% Included/Excluded Channels

            for excluded = [false true]
                switch excluded
                    case false
                        % Included
                        sp = [7 8];
                        name = "Viable Channels";

                    case true
                        % Excluded
                        sp = [1 2];
                        name = "Excluded Channels";
                end

                subplot(2,6,sp)

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

            %% Selection over raw timecourses

            subplot(2,6,[3 4])

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


            %% Selection over SCI/PSP

            subplot(2,6,[9 10])

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
            subplot(2,6,5)
            obj.DrawFourier(pipeline, obj.FigureData.Prior, "Before");

            subplot(2,6,11)
            obj.DrawFourier(pipeline, data, "After");


            %% Correlation matrix before/after
            subplot(2,6,6)
            obj.DrawDataCorrMatrix(obj.FigureData.Prior, "Before");

            subplot(2,6,12)
            obj.DrawDataCorrMatrix(data, "After");


            %% Label

            % Main title
            sgtitle(strrep(data.demographics.FullName, "_", "\_"), FontSize=obj.FONT_SIZE_TITLE, FontWeight="bold")

        end
    end

end