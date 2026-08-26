classdef Connectivity < internal.PipelineStep
    %% Parameters
    properties
        Suffix                                                                       = "Connectivity"
        Robust              (1,1) logical                                            = true % if true, robust correlation will be used
        PrewhitenModelOrder (1,1) double                                             = nan  % if non-NaN, prewhitening will be performed with this maximum model order (otherwise, not performed)
        FigureZThresh       (1,1) double {mustBeGreaterThanOrEqual(FigureZThresh,0)} = 0
        FigurepThresh       (1,1) double {mustBeBetween(FigurepThresh,0,1)}          = 1;
        FigureqThresh       (1,1) double {mustBeBetween(FigureqThresh,0,1)}          = 1;
    end

    %% Core Properties
    properties (Constant)
        Name        = "Calculate Connectivity"
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
        PropertiesThatAffectData = ["Robust" "PrewhitenModelOrder"]
        CanGenerateFigure        = true
        MustGenerateFigure       = false
        SavesData                = true
        IncludeInSummary         = false
        RunType                  = "PerAcquisition"
    end

    %% Overrides

    methods (Access = protected)
        function [data] = StepSpecificAcquisitionProcessing(obj, pipeline, data, tableRow)
            % If SDC are still present (weren't regressed out), then delete them
            %   Also need to count how many were viable
            channels = getChannels(data);
            if any(channels.ShortSeperation)
                % count viable
                data.demographics.Connectivity_DeletedViableSDCs = nnz(channels.ShortSeperation & ~channels.Excluded);

                % delete
                jobs = nirs.modules.RemoveShortSeperations;
                data = jobs.run(data);
            end

            % Connectivity from NIRS Toolbox...
            jobs = nirs.modules.Connectivity;
            jobs.verbose = false;

            % Select method...
            if isnan(obj.PrewhitenModelOrder)
                % No prewhitening
                jobs.corrfcn=@(data)nirs.sFC.corr(data, obj.Robust);
            else
                % Perform prewhitening with max model order of PrewhitenModelOrder
                jobs.corrfcn=@(data)nirs.sFC.ar_corr(data, obj.PrewhitenModelOrder, obj.Robust);
            end

            % Run job
            data = jobs.run(data);
        end
    end

    %% Figure
    methods (Access = protected)
        function StepSpecificFigureSetup(obj)
            obj.SetFigureSize(40,20);
        end

        function StepSpecificFigurePost(obj, pipeline, data, tableRow)
            % HbO/HbR Matrix
            subplot(1,5,1:2)
            obj.DrawDataCorrMatrix(data);
            title("All Z-Values")

            % HbT 2D Montage
            subplot(1,5,3:5)
            obj.DrawData2DConnectivity(data, "HbT Z-Values", "hbt", obj.FigureZThresh, obj.FigurepThresh, obj.FigureqThresh);

            % Label
            sgtitle(strrep(data.demographics.FullName, "_", "\_"), FontSize=obj.FONT_SIZE_TITLE, FontWeight="bold")
        end
    end

end