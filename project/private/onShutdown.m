function onShutdown
% Display
fprintf("Closing fNIRS-Preprocessing...\n");

% Remove manual paths
global pathsToRemove
if ~isempty(pathsToRemove)
    rmpath(pathsToRemove);
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