classdef Pipeline < internal.Base & matlab.mixin.Copyable
    %% Properties
    properties
        Name            (1,1)   string          = "DefaultPipeline"
        FolderRaw       (1,1)   string          = missing
        FolderOut       (1,1)   string          = missing
        FilepathTable   (1,1)   string          = missing
        TaskName        (1,1)   string          = "Default"
        Overwrite       (1,1)   logical         = true
    end
    
    % Hidden
    properties (Hidden)
        LogFcn          (1,1)   function_handle = @defaultLogFcn
        DeletePriorOutputs (1,1) logical        = false             % not yet implemented, temporarily hidden
    end
    
    % Read Only
    properties (SetAccess = private)
        Steps (:,1) internal.PipelineStep
        Table table
    end

    % Dependent
    properties (Dependent = true)
        countSteps
        countAcquisitions
    end
    
    
    %% Setters
    methods
        function obj = set.FolderRaw(obj, value)
            value = validateFolder(value);
            obj.FolderRaw = value;
        end

        function obj = set.FolderOut(obj, value)
            if ~exist(value, "dir")
                mkdir(value)
            end
            value = validateFolder(value);
            obj.FolderOut = value;
        end

        function obj = set.FilepathTable(obj, value)
            % must be a file
            mustBeFile(value);

            % must be csv, xls, or xlsx
            [~,~,ext] = fileparts(value);
            mustBeMember(ext, [".csv" , ".xls" , ".xlsx"])
            
            % valid
            obj.FilepathTable = value;

            % check table
            obj.ReadTable;
        end
    end

    %% Getters

    methods
        function [countSteps] = get.countSteps(obj)
            countSteps = numel(obj.Steps);
        end
        function [countAcquisitions] = get.countAcquisitions(obj)
            countAcquisitions = height(obj.Table);
        end
    end

    %% Public Functions

    methods
        function obj = ClearSteps(obj)
            obj.Steps = internal.PipelineStep.empty(0,1);
        end

        function obj = ClearStepsFromIndex(obj, index)
            arguments
                obj
                index (1,1) double {mustBePositive, mustBeInteger}
            end

            % no steps?
            if ~obj.countSteps
                error("No steps have been added to the pipeline yet")
            end

            % must not exceed number of steps added
            mustBeLessThanOrEqual(index, obj.countSteps)

            % clear
            obj.Steps(index:end) = [];
        end

        function obj = AddStep(obj, step)
            arguments
                obj
                step (1,1) internal.PipelineStep
            end

            % index
            indexAdd = obj.countSteps + 1;

            % overrite subfolder name if auto
            if step.SubfolderFigures == "auto"
                step.SubfolderFigures = sprintf("%02d. %s", indexAdd, step.Name);
            end

            % add step
            obj.Steps(indexAdd) = step;
        end

        function RunAll(obj)
            obj.RunFromIndex(1);
        end

        function RunIndex(obj, index)
            arguments
                obj
                index (1,1) double {mustBePositive, mustBeInteger}
            end

            % no steps?
            if ~obj.countSteps
                error("No steps have been added to the pipeline yet")
            end

            % must not exceed number of steps added
            mustBeLessThanOrEqual(index, obj.countSteps)

            % run this step...
            obj.PreRun;
            obj.RunPipelineStep(index);
        end

        function RunToIndex(obj, index)
            arguments
                obj
                index (1,1) double {mustBePositive, mustBeInteger}
            end

            % no steps?
            if ~obj.countSteps
                error("No steps have been added to the pipeline yet")
            end

            % must not exceed number of steps added
            mustBeLessThanOrEqual(index, obj.countSteps)

            % run each step
            obj.PreRun();
            for i = 1:index
                obj.RunPipelineStep(i);
            end
        end

        function RunFromIndex(obj, index)
            arguments
                obj
                index (1,1) double {mustBePositive, mustBeInteger}
            end

            % no steps?
            if ~obj.countSteps
                error("No steps have been added to the pipeline yet")
            end

            % must not exceed number of steps added
            mustBeLessThanOrEqual(index, obj.countSteps)

            % run each step
            obj.PreRun();
            for i = index:obj.countSteps
                obj.RunPipelineStep(i);
            end
        end

        function RunStep(obj, stepName)
            arguments
                obj
                stepName (1,1) string
            end

            % Get the step index
            idx = obj.GetStepIndexFromName(stepName);

            % Run the step
            obj.RunIndex(idx);
        end

        function RunToStep(obj, stepName)
            arguments
                obj
                stepName (1,1) string
            end

            % Get the step index
            idx = obj.GetStepIndexFromName(stepName);

            % Run the step
            obj.RunToIndex(idx);
        end

        function RunFromStep(obj, stepName)
            arguments
                obj
                stepName (1,1) string
            end

            % Get the step index
            idx = obj.GetStepIndexFromName(stepName);

            % Run the step
            obj.RunFromIndex(idx);
        end

        function [idx] = GetStepIndexFromName(obj, stepName)
            arguments
                obj
                stepName (1,1) string
            end

            % Add "PipelineSteps." if needed
            if ~stepName.startsWith("PipelineSteps.")
                stepName = "PipelineSteps." + stepName;
            end

            % Confirm that the stepName is valid
            if ~exist(stepName, "class")
                error("The specified step name does not exit: %s", stepName);
            end

            % Find step in list
            idx = find(arrayfun(@(x) isa(x, stepName), obj.Steps));

            % Not found?
            if isempty(idx)
                error("The specified step does not exist in the pipeline: %s", stepName);
            end

            % Too many found?
            if length(idx) > 1
                error("The pipeline contains multiple copies of the specified step (%s). Cannot determine which to run.", stepName)
            end

            % Returns idx
        end

        function Log(obj, message)
            obj.LogFcn(message, obj);
        end

        function [suffixIn, suffixOut] = GetFinalSuffix(obj)
            suffixIn = "";
            suffixOut = "";
            for i = 1:obj.countSteps
                if obj.Steps(i).SavesData || i==obj.countSteps
                    suffixOut = suffixOut + "_" + obj.Steps(i).Suffix;
                    if i < obj.countSteps
                        suffixIn = suffixIn + "_" + obj.Steps(i).Suffix;
                    end
                end
            end
        end

        function [result] = ContainsStep(obj, stepName)
            arguments
                obj         (1,1) Pipeline
                stepName    (1,1) string {mustBeNonempty}
            end
            result = any( arrayfun(@(x) isa(x, stepName), obj.Steps) );
        end

        function CreateAcquisitionCSV(obj, filepath, overwrite)
            arguments
                obj         (1,1) Pipeline
                filepath    (1,1) string
                overwrite   (1,1) logical = false
            end

            % Don't overwrite
            if ~overwrite && exist(filepath, "file")
                error("File already exists. Cannot create: %s", filepath)
            end

            % Raw folder must have been set
            if ismissing(obj.FolderRaw)
                error("You must set FolderRaw before calling CreateAcquisitionCSV")
            end

            % Find all *.wl1 files
            list = dir(fullfile(obj.FolderRaw, "**", "*.wl1"));
            folders = string({list.folder})';
            countFolders = numel(folders);

            % Replace root with "./"
            folders = folders.replace(obj.FolderRaw, "./");
            
            % Always use / because it works on all OS
            folders = folders.replace("\", "/");

            % Should be one *.wl1 per folder
            if numel(folders) ~= numel(unique(folders))
                error("Folder should not contain more than one *.wl1 file")
            end

            % Initialize table
            columns = ["Include" "Path_To_Raw" "Subject_Number" "Session_Number" "Run_Number" "Cardiac_Min_bpm" "Cardiac_Max_bpm" "Age_years" "Head_Circumference_cm" "iqr_override"];
            tbl = array2table(repmat("", [countFolders numel(columns)]), VariableNames=columns);
            tbl.Include(:) = true;
            tbl.Path_To_Raw(:) = folders;

            % Make folder if needed
            [folder,~,~] = fileparts(filepath);
            if folder.strlength > 0
                if ~exist(folder, "dir")
                    mkdir(folder)
                end
            end

            % Write
            writetable(tbl, filepath);
        end
    end

    %% Private Functions

    methods (Access = private)
        function PreRun(obj)
            % (re)read table and confirm that all standard fields exist
            obj.ReadTable();

            % (optional) delete all files in the output folder that are not an input to the steps that are about to run (ensures a clean folder state)
            if obj.DeletePriorOutputs
                obj.DeletePrior();
            end
        end

        function ReadTable(obj)
            % read the run info spreadsheet
            if obj.FilepathTable.lower.endsWith(".csv")
                % workaround for rare csv bug
                tbl = readtable(obj.FilepathTable, VariableNamingRule="preserve", Delimiter=",");
            else
                tbl = readtable(obj.FilepathTable, VariableNamingRule="preserve");
            end

            % warn if no acquisitions
            if ~height(tbl)
                error("The selected table contains no acquisitions: %s", obj.FilepathTable)
            end

            % table has required fields?
            d = setdiff(["Include" "Path_To_Raw" "Subject_Number" "Session_Number" "Run_Number" "Cardiac_Min_bpm" "Cardiac_Max_bpm" "Age_years" "Head_Circumference_cm" "iqr_override"], tbl.Properties.VariableNames);
            if ~isempty(d)
                error("The run info spreadsheet is missing the following fields or they are misnamed: %s", strip(sprintf("%s,", d(:)),"right", ","))
            end

            % convert paths to strings
            tbl = convertvars(tbl, @iscell, "string");

            % Handle different formats for "Include"...
            if islogical(tbl.Include)
                % Good to go
            elseif isnumeric(tbl.Include)
                % If numeric: verify only 0s and 1s, then convert to logical
                d = setdiff(tbl.Include, [0 1]);
                if ~isempty(d)
                    error("The ""Include"" column in the acquisition table must contain only TRUE/FALSE or 1/0. Other values detected: %s", sprintf("[%g] ", d))
                else
                    tbl.Include = (tbl.Include == 1);
                end
            elseif isstring(tbl.Include)
                % If string: verify only FALSE and TRUE, then convert to logical (not case sensitive)
                values = tbl.Include.upper;
                d = setdiff(values, ["TRUE" "FALSE"]);
                if ~isempty(d)
                    error("The ""Include"" column in the acquisition table must contain only TRUE/FALSE or 1/0. Other values detected: %s", "[" + strjoin(d, "] [") + "]")
                else
                    tbl.Include = (values == "TRUE");
                end
            else
                % Other formats are not supported
                error("The ""Include"" column in the acquisition table must contain only TRUE/FALSE or 1/0. An unsupported format was detected.")
            end

            % Remove rows with Include==false
            tbl = tbl(tbl.Include, :);

            % store
            obj.Table = tbl;
        end

        function DeletePrior(obj)
            %TODO Delete prior / unassociated files
            % warning("TODO: DeletePrior")
        end

        function RunPipelineStep(obj, index)
            % create copy of pipeline with steps up to and including index
            pipeline = obj.copy;
            if index < obj.countSteps
                pipeline.ClearStepsFromIndex(index+1);
            end

            % run step
            obj.Steps(index).Run(pipeline);
        end
    end
    
end