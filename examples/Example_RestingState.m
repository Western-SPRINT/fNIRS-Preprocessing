%% Start project (if not already open)
startfNIRSPreprocessing


%% Create Pipeline object
p = Pipeline;
p.FolderRaw     = "PATH/TO/RAW/FOLDER";
p.FolderOut     = "PATH/TO/OUTPUT/FOLDER";
p.FilepathTable = "PATH/TO/AQUISITION/SPREADSHEET.csv";
p.TaskName      = "rest";
p.Overwrite     = true;


%% Add steps: Import

s = PipelineSteps.ImportRaw(p);
s.SubfolderFigures      = "1-1_Import";
s.ScaleToHeadSize       = true;
% s.CustomFunction        = getFunctionHandleFromPath("PATH/TO/PROJECT-SPECIFIC/IMPORT/FUNCTION.m");

s = PipelineSteps.VerifyMontages(p);
s.SubfolderFigures      = "1-2_Verify";


%% Add steps: Quality Control

s = PipelineSteps.QCMotionCorrection(p);
s.SubfolderFigures      = "2-1_QC_Motion-Correction";
s.iqrDefault            = 1.2;

s = PipelineSteps.CardiacFigure(p);
s.SubfolderFigures      = "2-2_QC_Cardiac";
s.Normalize             = true;
s.AverageChannels       = true;

s = PipelineSteps.QCCalculate(p);
s.SubfolderFigures      = "2-3_QC_SCI-PSP";
s.WindowSeconds         = 3;
s.ParallelPools         = 0;

s = PipelineSteps.QCTrimSegment(p);
s.SubfolderFigures              = "2-4_QC_Cleanest-Segment";
s.SegmentSeconds                = 300;
s.SCIThreshold                  = 0.6;
s.PSPThreshold                  = 0.1;
s.IgnoreChannelsBelowRatioClean = 0.3;

s = PipelineSteps.QCExcludeChannels(p);
s.SubfolderFigures               = "2-5_QC_Channel-Exclusion";
s.SCIThreshold                   = 0.6;
s.PSPThreshold                   = 0.1;
s.ExcludeChannelsBelowRatioClean = 0.6;
s.tSNRThreshold                  = 1.5;


%% Add steps: Preprocess and Analyze

s = PipelineSteps.OpticalDensity(p);
s.SubfolderFigures = "3-1_Optical-Density";

s = PipelineSteps.TDDR(p);
s.SubfolderFigures = "3-2_TDDR";

s = PipelineSteps.WaveletFilter(p);
s.SubfolderFigures = "3-3_Wavelet-Filter";
s.iqrDefault       = 1.2;

s = PipelineSteps.MBLL(p);
s.SubfolderFigures = "3-4_MBLL";
s.AdjustForAge     = true;

s = PipelineSteps.Bandpass(p);
s.SubfolderFigures = "3-5_Bandpass";
s.Passband         = [0.009 0.080];

s = PipelineSteps.SDCRegress(p);
s.SubfolderFigures    = "3-6_SDC-Regression";
s.MaxComponents       = 6;
s.IndependentOxyDeoxy = false;
s.ParallelPools       = 0;

s = PipelineSteps.HbT(p);
s.SubfolderFigures = "3-7_HbT";

s = PipelineSteps.SummaryFigure(p);
s.SubfolderFigures = "3-8_Summary";

s = PipelineSteps.Connectivity(p);
s.SubfolderFigures = "3-9_Connectivity";
s.Robust           = false;
s.FigureZThresh    = 0.5;
s.FigurepThresh    = 1;
s.FigureqThresh    = 0.01;

s = PipelineSteps.ConnectivityGroup(p);
s.SubfolderFigures   = "3-10_Connectivity-Group";
s.MinShortChannels   = 0;
s.MinLongChannels    = 0;
s.MinDurationSeconds = 300;
s.FigureZThresh      = 0.5;
s.FigurepThresh      = 1;
s.FigureqThresh      = 1;

s = PipelineSteps.ConnectivityGroupSeed(p);
s.SubfolderFigures   = "3-11_Connectivity-Group-Seed";
s.DrawChannelLines   = true;
% s.SeedChannelIndices = 1:5;
% s.SensitivityPrecalcPath = "PATH/TO/PRECALCULATED/SENSITIVITY.mat";


%% Turn all optional figures on/off

enableOptionalFigures = true;
for s = p.Steps(:)'
    if ~s.MustGenerateFigure
        s.GenerateFigure = enableOptionalFigures;
    end
end


%% Adjust figure resolution

LOW_RES = 75;
HIGH_RES = 175;

for s = p.Steps(:)'
    s.FigureResolution = HIGH_RES;
end


%% Which step(s) to run

% Methods:
%   p.RunAll
%   p.RunToIndex(1)
%   p.RunFromIndex(1)
%   p.RunIndex(1)
%   p.RunStep("ImportRaw")
%   p.RunToStep("ImportRaw")
%   p.RunFromStep("ImportRaw")

