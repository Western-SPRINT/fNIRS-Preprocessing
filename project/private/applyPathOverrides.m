function applyPathOverrides
% Display
fprintf("Applying overrides to external...\n")

% Get project
proj = currentProject;

% Folder
fol = proj.RootFolder + "/override/nirs-toolbox/";

% Add to pathsToRemove
global pathsToRemove
pathsToRemove = [pathsToRemove ';' fol.char];

% NIRS Toolbox non-external files
addpath(fol)