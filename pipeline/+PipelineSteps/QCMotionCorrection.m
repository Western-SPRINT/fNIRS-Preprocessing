classdef QCMotionCorrection < internal.PipelineStep
    %% Parameters
    properties
        Suffix                                                                         = "QCMC"
        MotherWavelet       (1,1) string {mustBeMember(MotherWavelet, ["sym8" "db2"])} = "sym8"
        RemoveSlowestScale  (1,1) logical                                              = true
        iqrDefault          (1,1) double {mustBePositive}                              = 1.2
    end
    
    %% Core Properties
    properties (Constant)
        Name        = "Motion Correction for Quality Control Calculations"
        Description = ""
    end
    properties (SetAccess = protected, Hidden)
        % LatestDataAffectingUpdate - Tracks changes to core logic and critical defaults
        %
        % 2026-08-12: first version
        LatestDataAffectingUpdate = datetime(2026, 08, 12)

        % TableFields - required fields and validation for acquisition table
        TableFields = { 
                        "iqr_override" , @(x) isnumeric(x) && (isnan(x) || x>0)
                      }
    end
    properties (Constant, Hidden)
        PropertiesThatAffectData = ["MotherWavelet" , "RemoveSlowestScale" , "iqrDefault"]
        CanGenerateFigure        = true
        MustGenerateFigure       = false
        SavesData                = true
        IncludeInSummary         = false
        RunType                  = "PerAcquisition"
    end

    %% Overrides

    methods (Access = protected)
        function [data] = StepSpecificAcquisitionProcessing(obj, pipeline, data, tableRow)
            % Create a backup copy of the raw timeseries to restore after QC
            data.demographics.RawTimecourse = data.data;
            
            % Define Jobs: TDDR + WaveletFilter
            jobs                = [];

            % TDDR from NIRS Toolbox
            jobs                = nirs.modules.TDDR(jobs);
            jobs.usePCA         = false;
            jobs.split_PosNeg   = false;

            % Custom Wavelet Filter based on NIRS Toolbox and Homer
            jobs                = WaveletFilter_iqrThresh(jobs);
            jobs.wbasis         = obj.MotherWavelet;
            jobs.removeScaling  = obj.RemoveSlowestScale;

            % iqr
            if ~isnan(tableRow.iqr_override)
                jobs.iqr = tableRow.iqr_override;
            else
                jobs.iqr = obj.iqrDefault;
            end
            data.demographics.QCMotionCorrection_iqr = jobs.iqr;

            % Run jobs
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
            % Output name
            name = "After Motion Correction";

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