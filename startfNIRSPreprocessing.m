function startfNIRSPreprocessing
%% Add project folder to the permanent path if it isn't already there

% Get folder (might not be pwd)
[fol,~,~] = fileparts(which(mfilename + ".m"));

% Need to add to path?
if ~contains(path, fol)
    % Display
    fprintf("Adding main folder to path: %s\n", fol);

    % Add to path
    path(path, fol);

    % Try to save this folder to the path permanently
    try
        savepath
    catch
        warning("MATLAB Path could not be saved. Directories have been added to the path for this session only.\nThe most common solution is to run MATLAB as admin and try agian.")
    end
end


%% Clean up MATLAB path

% If the project is not open... (no project or different project)
if isempty(matlab.project.currentProject) || (matlab.project.currentProject().Name ~= "fNIRS-Preprocessing")
    % get Project's location (add filesep to omit root folder)
    folder = string(fileparts(which(mfilename))) + filesep;

    % get current MATLAB path
    currentPath = string(path);

    % split into folders
    pathFolders = currentPath.split(";");

    % find any project subfolders
    foldersToRemove = pathFolders(pathFolders.contains(folder));

    % any folders to remove
    if ~isempty(foldersToRemove)
        fprintf("Removing project folders that should be on the MATLAB path yet...\n");
        arrayfun(@rmpath, foldersToRemove)

        % Try to save this folder to the path permanently
        try
            savepath
        catch
            warning("MATLAB Path could not be saved. Directories have been added to the path for this session only.\nThe most common solution is to run MATLAB as admin and try agian.")
        end
    end
end


%% Open the project

openProject(which("fNIRS-Preprocessing.prj"));