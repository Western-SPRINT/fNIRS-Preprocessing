classdef MBLL < internal.PipelineStep
    %% Parameters
    properties
        Suffix                     = "Hb"
        AdjustForAge (1,1) logical = true
    end

    %% Core Properties
    properties (Constant)
        Name        = "Modified Beer-Lambert Law"
        Description = "";
    end
    properties (SetAccess = protected, Hidden)
        % LatestDataAffectingUpdate - Tracks changes to core logic and critical defaults
        %
        % 2026-08-12: first version
        LatestDataAffectingUpdate = datetime(2026, 08, 12)

        % TableFields - required fields and validation for acquisition table
        TableFields = { 
                        "Age_years" , @(x) isnumeric(x) && ~isnan(x) && x>=0;
                      }
    end
    properties (Constant, Hidden)
        PropertiesThatAffectData = ["AdjustForAge"]
        CanGenerateFigure        = true
        MustGenerateFigure       = false
        SavesData                = true
        IncludeInSummary         = true
        RunType                  = "PerAcquisition"
    end

    %% Getter
    
    methods
        function TableFields = get.TableFields(obj)
            % only require "Age_years" if AdjustForAge==true
            if ~obj.AdjustForAge
                TableFields = {};
            else
                TableFields = obj.TableFields;
            end
        end
    end

    %% Overrides
    methods (Access = protected)
        function [data] = StepSpecificAcquisitionProcessing(obj, pipeline, data, tableRow)
            % MBLL from NIRS Toolbox (default PPF is 0.1)
            jobs = nirs.modules.BeerLambertLaw;

            % (Optional) ADjust PPF for age
            if obj.AdjustForAge
                jobs.PPF = PipelineSteps.MBLL.CalculatePPF(data.probe.types, tableRow.Age_years);
            end

            % MBLL will remove probe.link.Excluded, need to make a backup of exclusions
            link = data.probe.link;

            % Run job
            data = jobs.run(data);

            % Reapply exclusions
            data.probe.link.Excluded(:) = false;
            for row = 1:height(data.probe.link)
                inds = (link.source == data.probe.link.source(row)) & (link.detector == data.probe.link.detector(row));
                data.probe.link.Excluded(row) = any(link.Excluded(inds));
            end

            % Store PPF
            data.demographics.MBLL_PPF = jobs.PPF;
        end
    end

    %% Private Static

    methods (Access = protected, Static)
        function PPF = CalculatePPF(wavelengths, age_years)
            % General equation for the differential pathlength factor of the frontal human head depending on wavelength and age
            % Scholkmann and Wolf, 2013
            % DPF(λ,A)= α + β(A^γ) + δ(λ^3) + ε(λ^2) + ζλ

            % Constants
            a = 223.3;
            b = 0.05624;
            c = 0.8493;
            d = -5.723E-7;
            e = 0.001245;
            g = -0.9025;

            % Equation
            DPF = @(wl, age) a + b*(age^c) + d*(wl^3) + e*(wl^2) + g*wl;

            % Partial volume factor
            PVF = 50;

            % PPF
            PPF = arrayfun(@(wl) DPF(wl, age_years), wavelengths(:)') / PVF;
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
            obj.FigureData.scale = nanmean(nanstd(values, 1)) * 2.0;

            % Setup tiles
            tiledlayout(2, obj.FigureData.nColumn + 2, TileSpacing="tight")

            % Input name
            name = "Before MBLL";

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
            % Set scaling (separate from input)
            values = data.data(:, ~data.probe.link.Excluded);
            if obj.FigureNormalize
                values = values ./ nanstd(values, 1);
            end
            obj.FigureData.scale = nanmean(nanstd(values, 1)) * 3.0;

            % Output name
            name = "After MBLL";

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