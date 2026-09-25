function onShutdown
% Display
fprintf("Closing fNIRS-Preprocessing...\n");

% Remove manual paths
global pathsToRemove
if ~isempty(pathsToRemove)
    rmpath(pathsToRemove);
end

% Try to save the path in case any folders found their way onto the
% permanent path (can happen when running multiple instances of MATLAB)
try
    savepath
catch
    warning("MATLAB Path could not be saved. Directories have been added/removed to the path for this session only.\nThe most common solution is to run MATLAB as admin and try agian.")
end

% Cleanup global variables
clear global VersionInfo pathsToRemove

% % % Close editor tabs to prevent them from reopening later with the project
% % editorObj = matlab.desktop.editor.getAll();
% % for i = 1:numel(editorObj)
% %     editorObj(i).close();
% % end

% Display ready
fprintf("fNIRS-Preprocessing is now closed\n");