function addNIRSToolbox
% Display
fprintf("Adding NIRS Toolbox to path...\n");

% Get project
proj = currentProject;

% Folder
fol = proj.RootFolder + "/external/nirs-toolbox/";

% Paths to add
pathsToAdd = [fol.char ';' genpath(fol + "/external")];

% Disable isstring warning
priorState = warning('query', 'MATLAB:dispatcher:nameConflict');

% Add NIRS Toolbox's "external" folder (including subfolders)
try
    warning('off', 'MATLAB:dispatcher:nameConflict')
    addpath(pathsToAdd)
end

% Restore warning
warning(priorState.state, 'MATLAB:dispatcher:nameConflict');

% Remember added paths for shutdown
global pathsToRemove
pathsToRemove = pathsToAdd;