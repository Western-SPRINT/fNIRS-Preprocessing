classdef PipelineStep < internal.Base & matlab.mixin.Heterogeneous
    
    %% Properties
    properties
        SubfolderFigures (1,1) string     = "auto"
        GenerateFigure   (1,1) logical
    end

    properties (Hidden)
        FigureResolution           (1,1) double     = 175
        FigureMaxChannelsPerColumn (1,1) double     = 35
        FigureNormalize            (1,1) logical    = false
    end

    properties (SetAccess = protected, Hidden)
        DateCreated (1,1) datetime {mustBeNonempty} = datetime("now", Format="uuuu-MM-dd HH:mm:ss")
        DateLastRun (1,1) datetime {mustBeNonempty} = missing;
    end

    properties (Access = protected, Transient = true)
        FigureData (1,1) struct
    end

    properties (Access = protected, Constant)
        FONT_SIZE_AXES      = 12;
        FONT_SIZE_TEXT      = 12;
        FONT_SIZE_TITLE     = 16;
    end
    
    
    %% Abstract Properties

    % Full access
    properties (Abstract)
        Suffix  (:,1) string {mustBeValidSuffix}
    end

    % Constant
    properties (Abstract, Constant)
        Name        (1,1) string {mustBeNonempty}
        Description (1,1) string {mustBeNonempty}
    end

    % Protected, Hidden
    properties (Abstract, SetAccess = protected, Hidden)
        LatestDataAffectingUpdate (1,1) datetime {mustBeNonmissing}
        TableFields               (:,2) cell
    end

    % Constant, Hidden
    properties (Abstract, Constant, Hidden)
        PropertiesThatAffectData (1,:)       string      
        CanGenerateFigure        (1,1)       logical
        MustGenerateFigure       (1,1)       logical
        SavesData                (1,1)       logical
        IncludeInSummary         (1,1)       logical
        RunType                  (1,1)       string {mustBeMember(RunType, ["PerAcquisition" "Group" "PerAcquisitionThenGroup"])}
    end


    %% Constructor
    methods
        function obj = PipelineStep(pipeline)
            arguments
                pipeline (1,1) {mustBeClassOrMissing(pipeline, "Pipeline")} = missing
            end

            obj.GenerateFigure = obj.CanGenerateFigure;

            if ~obj.SavesData && obj.IncludeInSummary
                error("Cannot IncludeInSummary without SavesData")
            end

            % Display date as year-month-day
            obj.LatestDataAffectingUpdate.Format = "uuuu-MM-dd";

            if ~ismissing(pipeline)
                pipeline.AddStep(obj);
            end
        end
    end


    %% Setters

    methods 
        function obj = set.GenerateFigure(obj, value)
            if ~obj.CanGenerateFigure && value==true
                warningTraceless(sprintf("Figure output is not yet implemented for: %s", obj.Name));
                obj.GenerateFigure = false;
            elseif obj.MustGenerateFigure && value==false
                error("Figure output is mandatory for: %s", obj.Name);
            else
                obj.GenerateFigure = value;
            end
        end
    end

    
    %% Main Functions

    methods
        function Run(obj, pipeline)
            % Update timestamp
            obj.DateLastRun = datetime("now", Format="uuuu-MM-dd HH:mm:ss");

            % suffix in/out
            [suffixIn, suffixOut] = pipeline.GetFinalSuffix;
            
            % check that required fields are populated
            for i = 1:size(obj.TableFields, 1)
                name = obj.TableFields{i,1};
                validationFcn = obj.TableFields{i,2};
                values = pipeline.Table.(name);
                valid = ~any(~arrayfun(validationFcn, values));
                if ~valid
                    error("Missing or invalid values in required field: %s", name)
                end
            end

            % step-specific setup
            obj.StepSpecificSetup;
            
            % where is figure folder
            folder = obj.getFolderFigure(pipeline);

            % create figure folder?
            if ~exist(folder, "dir")
                mkdir(folder)
            end

            % figure setup
            if obj.GenerateFigure
                % clear prior data
                obj.FigureData = struct;

                % create and setup
                obj.PrepareFigure();
            end
            
            % process acquisitions individually
            if contains(obj.RunType, ["PerAcquisition" "PerAcquisitionThenGroup"])
                for row = 1:pipeline.countAcquisitions
                    obj.ProcessAcquisition(pipeline, pipeline.Table(row,:), suffixIn, suffixOut);
                end
            end

            % process as a group
            if contains(obj.RunType, ["Group" "PerAcquisitionThenGroup"])
                obj.ProcessGroup(pipeline, suffixIn, suffixOut)

                % Save figure?
                if obj.GenerateFigure
                    filepath = obj.getFolderFigure(pipeline) + "Group_" + suffixOut.extractAfter(1) + ".png";
                    if ishandle(obj.FigureData.Handle)
                        drawnow('nocallbacks')
                        print(obj.FigureData.Handle, filepath, "-dpng", "-image", "-r" + obj.FigureResolution)
                        % exportgraphics(obj.FigureData.Handle, filepath, Resolution=obj.FigureResolution, Units="centimeters", Width=obj.FigureData.Size.Width, Height=obj.FigureData.Size.Height)
                    end
                end
            end

            % figure cleanup
            if obj.GenerateFigure
                if ishandle(obj.FigureData.Handle)
                    close(obj.FigureData.Handle);
                    obj.FigureData = struct;
                end
            end
        end
    end

    methods (Access = protected)
        function ProcessAcquisition(obj, pipeline, tableRow, suffixIn, suffixOut)
            % skip this acquisition if output file already exists
            filepathOut = obj.getAcquisitionFilepath(pipeline, tableRow, suffixOut);
            if ~pipeline.Overwrite && exist(filepathOut, "file")
                %TODO log
                return
            end

            % load acquisition input
            [data, pipelinePrior] = obj.LoadAcquisition(pipeline, tableRow, suffixIn);

            % Figure before processing...
            if obj.GenerateFigure
                % clear FigureData except for handle and figure size
                obj.FigureData = struct(Handle=obj.FigureData.Handle, Size=obj.FigureData.Size);

                % reset figure
                obj.PrepareFigure();

                % do any step-specific before processing
                obj.StepSpecificFigurePre(pipelinePrior, data, tableRow);
            end

            % merge this and prior pipeline steps
            if ~isempty(pipelinePrior)
                pipeline.ClearSteps;
                for s = pipelinePrior.Steps(:)'
                    pipeline.AddStep(s);
                end
                pipeline.AddStep(obj);
            end

            % step-specific processing
            data = obj.StepSpecificAcquisitionProcessing(pipeline, data, tableRow);

            % Processing after processing...
            if obj.GenerateFigure
                % do any step-specific after processing
                obj.StepSpecificFigurePost(pipeline, data, tableRow);

                % save
                filepath = obj.getFolderFigure(pipeline) + data.demographics.FullName + suffixOut + ".png";
                if ishandle(obj.FigureData.Handle)
                    drawnow('nocallbacks')
                    print(obj.FigureData.Handle, filepath, "-dpng", "-image", "-r" + obj.FigureResolution)
                    % exportgraphics(obj.FigureData.Handle, filepath, Resolution=obj.FigureResolution, Units="centimeters", Width=obj.FigureData.Size.Width, Height=obj.FigureData.Size.Height)
                end
            end

            % stop early if data does not need to be saved
            if ~obj.SavesData
                return
            end

            % output folder
            [folder,~,~] = fileparts(filepathOut);
            if ~exist(folder, "dir")
                mkdir(folder)
            end

            % save acquisition output
            save(filepathOut, "data", "pipeline")
        end

        function [filepath] = getAcquisitionFilepath(obj, pipeline, tableRow, suffix)
            label = parseBIDSLabelsFromRow(pipeline, tableRow);

            filepath = pipeline.FolderOut + "derivatives" + filesep + ...
                        label.Subject + filesep + label.Session + ...
                        filesep + "nirs" + filesep + label.FullName + ...
                        suffix + ".mat";
        end

        function [folder] = getFolderFigure(obj, pipeline)
            folder = pipeline.FolderOut + "derivatives" + filesep + "Figures" + filesep + obj.SubfolderFigures + filesep;
        end

        function [data, pipelinePrior] = LoadAcquisition(obj, pipeline, tableRow, suffixIn)
            filepath = obj.getAcquisitionFilepath(pipeline, tableRow, suffixIn);
            file = load(filepath);
            data = file.data;
            pipelinePrior = file.pipeline;
        end

        function [data] = StepSpecificAcquisitionProcessing(obj, pipeline, data, tableRow)
            % override when needed
        end
        
        function ProcessGroup(obj, pipeline, suffixIn, suffixout)
            % override when needed
            %   include check of pipeline.Overwrite and pipeline.SavesData
        end
    end

    %% Figure functions
    methods (Access = protected)
        function PrepareFigure(obj)
            % close prior?
            if isfield(obj.FigureData, "Handle") && ishandle(obj.FigureData.Handle)
                close(obj.FigureData.Handle)
            end

            % open (new) figure
            obj.FigureData.Handle = figure(Visible="off");

            % figure defaults
            obj.FigureData.Handle.Theme = "Light";
            obj.FigureData.Handle.Renderer = "opengl";
            set(obj.FigureData.Handle,  'DefaultAxesFontSize', obj.FONT_SIZE_AXES, ...
                'DefaultAxesFontUnits', 'points', ...
                'DefaultTextFontSize', obj.FONT_SIZE_TEXT, ...
                'DefaultTextFontUnits', 'points');
            
            % restore/initialize size
            if isfield(obj.FigureData, "Size")
                obj.SetFigureSize(obj.FigureData.Size.Width,obj.FigureData.Size.Height);
            else
                obj.SetFigureSize(1,1);
            end

            % run any step-specific setup
            obj.StepSpecificFigureSetup();
        end

        function SetFigureSize(obj, width, height)
            % set displayed size
            obj.FigureData.Handle.Units =    "centimeters";
            obj.FigureData.Handle.Position = [0 0 width height];

            % set saved size
            obj.FigureData.Handle.PaperUnits =    "centimeters";
            obj.FigureData.Handle.PaperPosition = [0 0 width height];
            obj.FigureData.Handle.PaperSize =     [width height];

            % store values in case they are needed
            obj.FigureData.Size.Width = width;
            obj.FigureData.Size.Height = height;
        end

        function StepSpecificFigureSetup(obj)
            % override if needed
        end

        function StepSpecificFigurePre(obj, pipeline, data, tableRow)
            % override if needed
        end

        function StepSpecificFigurePost(obj, pipeline, data, tableRow)
            % override if needed
        end

        function StepSpecificSetup(obj)
            % override if needed
        end

        function SetNumberOfColumns(obj, data)
            % Count channels
            channels = getChannels(data);
            nChannels = height(channels);

            % How many columns?
            obj.FigureData.nColumn = ceil(nChannels / obj.FigureMaxChannelsPerColumn);

            % How many channels in each column?
            obj.FigureData.channelsPerColumn = ceil(nChannels / obj.FigureData.nColumn);
        end

        function DrawStackedPlotColumns(obj, data, name, normalize)
            arguments
                obj         (1,1) internal.PipelineStep
                data        (1,1) nirs.core.Data
                name        (1,1) string
                normalize   (1,1) logical = false
            end

            %% Requires that the following have been set
            %   obj.FigureData.channelsPerColumn
            %   obj.FigureData.nColumn
            %   obj.FigureData.scale

            %% Prepare Channels

            channels = getChannels(data);
            nChannels = height(channels);
            data.probe.link.ChannelIndex(:) = nan;
            for i = 1:nChannels
                data.probe.link.ChannelIndex(channels.TypeIndicesInLinks{i}) = i;
            end

            nDatatypes = length(data.probe.types);
            [datatypeNames, datatypeColours] = getDatatypeNamesColours(data.probe.types);
            datatypeColours(:,4) = 0.5;

            %% Prepare Data

            % Timeseries
            values = data.data;

            % Center
            values = values - nanmean(values,1);

            % Normalize
            if normalize
                values = values ./ nanstd(values, 1);
            end

            % Stack (channel 1 at top)
            channelY = (nChannels-(1:nChannels))*obj.FigureData.scale;
            values = values + ((nChannels - data.probe.link.ChannelIndex) * obj.FigureData.scale)';


            %% Draw columns
            for col = 1:obj.FigureData.nColumn
                nexttile

                channelRange = [1 obj.FigureData.channelsPerColumn] + ((col-1)*obj.FigureData.channelsPerColumn);
                channelRange(2) = min(nChannels, channelRange(2));

                hold on
                p = nan(1, nDatatypes);
                for i = 1:nDatatypes
                    select = (data.probe.link.ChannelIndex >= channelRange(1)) & ...
                             (data.probe.link.ChannelIndex <= channelRange(2)) & ...
                             selectLinkDatatype(data, data.probe.types(i)) & ...
                             (~data.probe.link.Excluded);
                    if any(select)
                        plot(data.time, values(:, select), Color=datatypeColours(i,:));
                    end
                    p(i) = plot(nan, nan, Color=datatypeColours(i,:), LineWidth=5);
                end
                hold off

                legend(p, datatypeNames, Location="EastOutside")

                labels = arrayfun(@(s,d) sprintf("S%02d-D%02d", s, d), channels.source(channelRange(1):channelRange(2)), channels.detector(channelRange(1):channelRange(2)));

                ticks = channelY( channelRange(1):channelRange(2) );
                set(gca, YTick=ticks(end:-1:1), YTickLabel=labels(end:-1:1), FontSize=5)

                xlim(data.time([1 end]))
                ylim([-(obj.FigureData.channelsPerColumn*obj.FigureData.scale) obj.FigureData.scale] + ticks(1))

                xlabel("Time (sec)")

                title(sprintf("%s: Channels %d to %d", name, channelRange(1), channelRange(2)))
            end
        end

        function DrawFourier(obj, pipeline, data, name)
            arguments
                obj         (1,1) internal.PipelineStep
                pipeline    (1,1) Pipeline
                data        (1,1) nirs.core.Data
                name        (1,1) string
            end

            % Fourier
            [power,freq] = calcFourier(data);

            % Data types
            nDatatypes = length(data.probe.types);
            [datatypeNames, datatypeColours] = getDatatypeNamesColours(data.probe.types);
            datatypeColours(:,4) = 0.1;

            % Plot
            p = nan(1, nDatatypes);
            hold on
                for i = 1:nDatatypes
                    select = ~data.probe.link.Excluded & selectLinkDatatype(data, data.probe.types(i));
                    plot(freq, power(:, select), Color=datatypeColours(i,:));
                    p(i) = plot(nan, nan, Color=datatypeColours(i,:), LineWidth=5);
                end
            hold off

            legend(p, datatypeNames, Location="EastOutside")
            
            xlabel("Frequency (Hz)")
            ylabel("Power")
            title("Frequency Domain: " + name)

            % adjust if Bandpass has been run
            if pipeline.ContainsStep("PipelineSteps.Bandpass")
                ind = find(arrayfun(@(s) isa(s, "PipelineSteps.Bandpass"), pipeline.Steps), 1, "last");
                passband = pipeline.Steps(ind).Passband;
                xlim([freq(1) (passband(2)*1.5)])
            else
                % Cut off low frequencies
                ylim([0 nanmax(nanmax(power(freq > 0.05, ~data.probe.link.Excluded)))])
                xlim(freq([1 end]))
            end
        end

        function DrawDataCorrMatrix(obj, data, name, types)
            arguments
                obj     (1,1) internal.PipelineStep
                data    (1,1) {mustBeA(data, ["nirs.core.Data" "nirs.core.sFCStats"])}
                name    (1,1) string = missing
                types   (1,:) string = []
            end

            % sort by datatypes
            [~,order] = sortrows(data.probe.link.type);
            data.probe.link = data.probe.link(order, :);
            switch class(data)
                case "nirs.core.Data"
                    data.data = data.data(:, order);
                case "nirs.core.sFCStats"
                    data.R = data.R(order, order);
                otherwise
                    error("Unsupproted data type")
            end

            % (Optional) Reduce datatypes
            if ~isempty(types)
                select = any(cell2mat(arrayfun(@(t) selectLinkDatatype(data, t), types, UniformOutput=false)), 2);
                data.probe.link = data.probe.link(select, :);
                switch class(data)
                    case "nirs.core.Data"
                        data.data = data.data(:, select);
                    case "nirs.core.sFCStats"
                        data.R = data.R(select, select);
                    otherwise
                        error("Unsupproted data type")
                end
            end

            % remove Excluded
            select = data.probe.link.Excluded;
            data.probe.link(select, :) = [];
            switch class(data)
                case "nirs.core.Data"
                    data.data(:, select) = [];
                case "nirs.core.sFCStats"
                    data.R = data.R(~select, ~select);
                otherwise
                    error("Unsupproted data type")
            end

            % Data types
            nDatatypes = length(data.probe.types);
            [datatypeNames, datatypeColours] = getDatatypeNamesColours(data.probe.types);

            % draw
            switch class(data)
                case "nirs.core.Data"
                    imagesc(corr(data.data))
                case "nirs.core.sFCStats"
                    imagesc(data.Z)
                otherwise
                    error("Unsupproted data type")
            end
            colormap(gca, colourMap3)
            clim([-1 +1])
            colorbar
            axis square
            
            % Label datatypes
            ticks = [];
            xl = xlim;
            yl = ylim;
            hold on
            for i = 1:nDatatypes
                select = selectLinkDatatype(data, data.probe.types(i));
                inds = find(select);
                if i > 1
                    plot(xl, repmat(inds(1) - 0.5, [1 2]), 'k-')
                    plot(repmat(inds(1) - 0.5, [1 2]), yl, 'k-')
                end
                ticks(i) = mean(inds);
            end
            hold off

            if ~ismissing(name)
                title("Correlations: " + name)
            end

            set(gca, XTick=ticks, YTick=ticks, XTickLabel=datatypeNames, YTickLabel=datatypeNames, XAxisLocation="top", XTickLabelRotation=0)
            xlim(xl)
            ylim(yl)
        end

        function DrawData2DConnectivity(obj, data, name, type, Zthresh, pthresh, qthresh)
            arguments
                obj     (1,1) internal.PipelineStep
                data    (1,1) nirs.core.sFCStats
                name    (1,1) string                                = []
                type    (1,1) string {mustBeNonempty}               = "hbo"
                Zthresh  (1,1) double {mustBeGreaterThanOrEqual(Zthresh,0)} = 0
                pthresh (1,1) double {mustBeBetween(pthresh,0,1)}   = 1;
                qthresh (1,1) double {mustBeBetween(qthresh,0,1)}   = 1;
            end

            % Colormap
            cmap = colourMap3;
            cmap(:,4) = 0.2;
            lookup = linspace(-1, +1, size(cmap,1));

            % Reduce to selected type
            select = selectLinkDatatype(data, type);
            data.probe.link = data.probe.link(select, :);
            data.R = data.R(select, select);

            % Remove Excluded
            select = data.probe.link.Excluded;
            data.probe.link(select, :) = [];
            data.R = data.R(~select, ~select);

            % Get channels
            channels = getChannels(data);
            channels.X(:) = nan;
            channels.Y(:) = nan;
            nChannel = height(channels);

            % Workaround for df=1
            if pthresh==1
                pthresh = inf;
            end
            if qthresh==1
                qthresh = inf;
            end

            % Thresholds
            toDraw = (data.p < pthresh) & (data.q < qthresh) & (abs(data.Z) > Zthresh);
            
            hold on

                % Draw channels and store their center coordinates
                xs = [];
                ys = [];
                srcUsed = false(1, size(data.probe.srcPos, 1));
                detUsed = false(1, size(data.probe.detPos, 1));
                for i = 1:nChannel
                    s = channels.source(i);
                    d = channels.detector(i);

                    srcUsed(s) = true;
                    detUsed(d) = true;

                    x = [data.probe.srcPos(s,1) data.probe.detPos(d,1)];
                    y = [data.probe.srcPos(s,2) data.probe.detPos(d,2)];

                    channels.X(i) = mean(x);
                    channels.Y(i) = mean(y);

                    xs = [xs nan x];
                    ys = [ys nan y];

                end
                plot(xs, ys, "k", LineWidth=1);

                % Draw connectivity
                for i = 1:nChannel
                    for j = (i+1 : nChannel)
                        if toDraw(i,j)
                            % find colour
                            [~,ind] = min(abs(lookup - data.Z(i,j)));

                            % plot
                            plot([channels.X(i) channels.X(j)], [channels.Y(i) channels.Y(j)], Color=cmap(ind,:), LineWidth=2);
                        end
                    end
                end

                % Draw optodes
                markerSize = 3;
                plot(data.probe.srcPos(srcUsed,1), data.probe.srcPos(srcUsed,2), "ro", MarkerFaceColor="r", MarkerSize=markerSize);
                plot(data.probe.detPos(detUsed,1), data.probe.detPos(detUsed,2), "bo", MarkerFaceColor="b", MarkerSize=markerSize);
                
            hold off

            axis equal off

            colorbar
            clim([-1 +1])
            colormap(gca, cmap(:,1:3))

            % Title
            if ~isempty(name)
                if Zthresh > 0
                    name = sprintf("%s (|Z| > %g)", name, Zthresh);
                end
                if pthresh < 1
                    name = sprintf("%s (p < %g)", name, pthresh);
                end
                if qthresh < 1
                    name = sprintf("%s (q < %g)", name, qthresh);
                end

                title(name)
            end
        end
    end

end