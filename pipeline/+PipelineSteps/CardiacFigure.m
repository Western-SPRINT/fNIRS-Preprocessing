classdef CardiacFigure < internal.PipelineStep
    %% Parameters
    properties
        Suffix                        = "BPM"
        Normalize       (1,1) logical = true
        AverageChannels (1,1) logical = true
    end

    %% Core Properties
    properties (Constant)
        Name        = "Cardiac Figure"
        Description = "Generate figures for cardiac range verification"
    end
    properties (SetAccess = protected, Hidden)
        % LatestDataAffectingUpdate - Tracks changes to core logic and critical defaults
        %
        % 2026-08-12: first version
        LatestDataAffectingUpdate = datetime(2026, 08, 12)

        % TableFields - required fields and validation for acquisition table
        TableFields = { 
                        "Cardiac_Min_bpm" , @(x) isnumeric(x);
                        "Cardiac_Max_bpm" , @(x) isnumeric(x);
                      }
    end
    properties (Constant, Hidden)
        PropertiesThatAffectData = []
        CanGenerateFigure        = true
        MustGenerateFigure       = true
        SavesData                = false
        IncludeInSummary         = false
        RunType                  = "PerAcquisition"
    end

    %% Figure
    methods (Access = protected)
        function StepSpecificFigureSetup(obj)
            obj.SetFigureSize(30, 15);
        end

        function StepSpecificFigurePre(obj, pipeline, data, tableRow)
            % Fourier, ignoring anything below 1/6 Hz
            [power,freq] = calcFourier(data, [10/60 inf]);
            
            % Convert frequencies to bpm
            freq = freq * 60;

            % Remove any excluded signals
            power(:,data.probe.link.Excluded) = [];

            % Normalize?
            yLabel = "Power";
            if obj.Normalize
                power = power ./ std(power);
                yLabel = yLabel + " (Normalized)";
            end

            % Average?
            if obj.AverageChannels
                power = mean(power, 2);
                alpha = 1.00;
            else
                alpha = 0.10;
            end

            % Get the range of values
            yl = [0 max(power(:))];

            % If available, draw the specified cardiac range
            if ~isnan(tableRow.Cardiac_Min_bpm) && ~isnan(tableRow.Cardiac_Max_bpm)
                rectangle(Position=[tableRow.Cardiac_Min_bpm , yl(1) , (tableRow.Cardiac_Max_bpm - tableRow.Cardiac_Min_bpm) , range(yl)], FaceColor=[1 1 0], FaceAlpha=0.50, EdgeColor=[1 1 0])
            end

            % Plot cardiac spike
            hold on
                plot(freq, power, Color=[0 0 1 alpha]);
            hold off

            % Vertical grid lines
            set(gca, XGrid="on");

            % Limits and title
            yl(1) = yl(1) - range(yl)*0.01;
            if range(yl)
                ylim(yl)
            end
            xlim(freq([1 end]))
            xlabel("Beats per Minute")
            ylabel(yLabel)
            title(strrep(data.demographics.FullName, "_", "\_"))
        end
    end
end