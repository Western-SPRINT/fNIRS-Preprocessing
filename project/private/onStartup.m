function onStartup
% Display
fprintf("Starting fNIRS-Preprocessing...\n");

% Initialize
global VersionInfo pathsToRemove
VersionInfo = struct;
pathsToRemove = [];

% If start fails, close the project
try
    % Prepare external version info
    getVersionInfo

    % Check if the main repository has updated
    checkGitUpdates

    % Check required MATLAB Toolboxes
    checkMATLABToolboxes

    % Check/Get NIRS Toolbox
    getNIRSToolbox

    % Add NIRS Toolbox to path
    addNIRSToolbox

    % Add overrides to the external (must be called after addNIRSToolbox) 
    applyPathOverrides

    % Display ready
    fprintf("fNIRS-Preprocessing is ready to use!\n");

% Start failed! Close project
catch err
    % warn
    warningTraceless("fNIRS-Preprocessing startup has failed (see error below). The project will now close.")
    
    % queue closing (cannot do this during startup)
    t = timer('StartDelay', 0.5, 'TimerFcn', @(~,~) close(currentProject), 'ExecutionMode', 'singleShot');
    start(t);

    % rethrow error
    rethrow(err);
end