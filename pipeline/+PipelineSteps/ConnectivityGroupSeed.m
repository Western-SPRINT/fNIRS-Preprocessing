classdef ConnectivityGroupSeed < internal.PipelineStep
    %% Parameters
    properties
        Suffix                              = "Seed"
        SeedChannelIndices (1,:) double     = nan
        DrawChannelLines   (1,1) logical    = false
        AtlasViewerPath    (1,1) string {mustEndWith(AtlasViewerPath,".mat")} = "DemoAug2026.mat" % name of an included file OR path to your own file
    end

    %% Core Properties
    properties (Constant)
        Name        = "Generate Group Connectivity Seed Figures"
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
        RunType                  = "Group"
    end

    %% Setter

    methods
        function obj = set.AtlasViewerPath(obj, value)
            % try to get filepath
            obj.getAtlasViewerFilepath(value);

            % if it didn't error, set the value
            obj.AtlasViewerPath = value;
        end
    end

    %% Overrides
    methods (Access = protected)
        function StepSpecificFigureSetup(obj)
            obj.SetFigureSize(30,30);
        end

        function ProcessGroup(obj, pipeline, suffixIn, suffixOut)
            %% Requires PipelineSteps.ConnectivityGroup
            if ~pipeline.ContainsStep("PipelineSteps.ConnectivityGroup")
                error("PipelineSteps.ConnectivityGroup must be run before PipelineSteps.ConnectivityGroupSeed")
            end


            %% Load and prepare pre-calculated sensitivity

            % Load
            precalculated = load(obj.getAtlasViewerFilepath());

            % Calculate log-sensitivity
            logAdot = log10(precalculated.Adot + eps + 1);
            logAdot(logAdot < 0) = 0;
            logAdot(logAdot > 1) = 1;


            %% Prepare Group Data

            % Load group result
            filepathOut = pipeline.FolderOut + "derivatives" + filesep + "Group" + suffixIn + ".mat";
            load(filepathOut, "data")

            % Reduce to HbT
            select = selectLinkDatatype(data, "hbt");
            data.probe.link = data.probe.link(select, :);
            data.R = data.R(select, select);

            % channel order
            channels = getChannels(data);
            nChannel = height(channels);

            % Check montage
            if (size(precalculated.channel_SD,1) ~= nChannel) || any( (precalculated.channel_SD(:,1) ~= channels.source) | (precalculated.channel_SD(:,2) ~= channels.detector) )
                error("This montage is not supported")
            end

            % Default to all possible seeds
            if isempty(obj.SeedChannelIndices) || (isscalar(obj.SeedChannelIndices) && isnan(obj.SeedChannelIndices))
                obj.SeedChannelIndices = 1:nChannel;
            end

            % Check seed values
            if any(obj.SeedChannelIndices ~= round(obj.SeedChannelIndices))
                error("Seeds must be integers")
            elseif any(obj.SeedChannelIndices<1)
                error("Seeds must be positive")
            elseif any(obj.SeedChannelIndices>nChannel)
                error("Seeds must not exceed the number of channels")
            end
            

            %% Colour Map

            % Get colour map
            cmap = colourMap3;

            % Lookup for colour range
            colour_radius = 1;
            cmap_lookup = linspace(-colour_radius, +colour_radius, size(cmap,1));

            
            %% Draw and save each seed
            for ch = obj.SeedChannelIndices
                %% Calculations...

                % Clear figure
                clf(obj.FigureData.Handle);

                % Calculate vertex values
                values = (data.Z(:,ch) .* logAdot); 
                values = nansum(values, 1);  
                values = values ./ sum(logAdot, 1); 

                % Mask out low sensitivity
                values(sum(logAdot, 1) < 0.1) = 0;

                % Determine colours
                normVals = (values(:) + colour_radius) / (colour_radius * 2);
                normVals = min(max(normVals, 0), 1);
                cIdx = round(normVals * (size(cmap,1)-1)) + 1;
                rgbData = cmap(cIdx, :);

                % Set seed to black
                seedColour = [0 0 0];
                seedIdx = find(logAdot(ch,:) > 0.2);
                rgbData(seedIdx, :) = repmat(seedColour, numel(seedIdx), 1);

                %% Draw...

                tiledlayout(2, 2, TileSpacing="none")

                for v = 1:4
                    nexttile

                    % Draw mesh
                    p = patch('Vertices', precalculated.mesh.vertices, 'Faces', precalculated.mesh.faces, ...
                        'FaceVertexCData', rgbData, 'FaceColor', 'interp', 'EdgeColor', 'none');
                    axis image off

                    % Improve lighting
                    view(0, 0)
                    camlight
                    lighting gouraud

                    % (Optional) Draw channel lines
                    if obj.DrawChannelLines
                        hold on
                        for i = 1:nChannel
                            if (i == ch)
                                colour = seedColour;
                            else
                                [~,idx] = min(abs(cmap_lookup - data.Z(ch,i)));
                                colour = [cmap(idx, :) 0.75];
                            end

                            x = [precalculated.src_pos(channels.source(i), 1) precalculated.det_pos(channels.detector(i), 1)];
                            y = [precalculated.src_pos(channels.source(i), 2) precalculated.det_pos(channels.detector(i), 2)];
                            z = [precalculated.src_pos(channels.source(i), 3) precalculated.det_pos(channels.detector(i), 3)];

                            plot3(x, y, z, Color=colour, LineWidth=3);
                        end
                        hold off
                    end

                    % Set view
                    addLight = true;
                    switch v
                        case 1
                            view(180, 10)
                        case 2
                            view(0, 10)
                            addLight = false; % back is already well lit
                        case 3
                            view(-90, 20)
                        case 4
                            view(90, 20)
                    end
                    if addLight
                        camlight("headlight")
                    end
                end

                % Label
                channelName = sprintf("S%d-D%d", channels.source(ch), channels.detector(ch));
                t = sprintf("Group Connectivity (Z-Values): Channel %d (%s)", ch, channelName);
                if channels.Excluded(ch)
                    t = t + " [excluded in every acquisition]";
                end
                sgtitle(t, FontSize=obj.FONT_SIZE_TITLE, FontWeight="bold")
                
                % Save
                filepath = obj.getFolderFigure(pipeline) + "Group_" + suffixOut.extractAfter(1) + sprintf("_Channel-%03d_%s.png", ch, channelName);
                drawnow('nocallbacks')
				print(obj.FigureData.Handle, filepath, "-dpng", "-image", "-r" + obj.FigureResolution)
				% exportgraphics(obj.FigureData.Handle, filepath, Resolution=obj.FigureResolution);
            end

            %% Cleanup
            close(obj.FigureData.Handle) % prevents generic save
        end
    end

    %% Private

    methods (Access = private)
        function [filepath] = getAtlasViewerFilepath(obj, value)
            if nargin<2
                value = obj.AtlasViewerPath;
            end

            % Assume included file...
            proj = currentProject;
            filepath = proj.RootFolder + filesep + "external" + filesep + "AtlasViewer_Sensitivity" + filesep + value;

            % If not included file, check if valid path
            if ~exist(filepath, "file")
                filepath = value;
                if ~exist(filepath, "file")
                    % If not valid path, error
                    error("AtlasViewerPath must be either the name of a provided AtlasViewer file or the path to your own AtlasViewer file")
                end
            end
        end
    end
end