function checkNIRSToolbox
%% Select version snapshot

NIRS_TOOLBOX_URL = "https://github.com/huppertt/nirs-toolbox.git";
NIRS_TOOLBOX_TARGET_VERSION = "c6605e69535adbcef432aba1838c84fcc7efe555";


%% Check/Get NIRS Toolbox

% Display
fprintf("Checking NIRS Toolbox...\n");

% Get project
proj = currentProject;

% Folder
fol = proj.RootFolder + "/external/nirs-toolbox/";

% Clone if it doesn't already exist
if ~exist(fol + "+nirs", "dir")
    fprintf("\tNIRS Toolbox was not found! Cloning to external/nirs-toolbox. This may take a few minutes...\n");

    % stray files in the folder can cause problems, delete folder to be safe
    if exist(fol, "dir")
        rmdir(fol, "s")
    end

    % clone (cannot select version here)
    gitclone(NIRS_TOOLBOX_URL, fol);
end

% Check repo version
repo = gitrepo(fol);
if repo.Remotes.URL ~= NIRS_TOOLBOX_URL
    % NIRS Toolbox was found, but it is not setup for Git
    warningTraceless("external/nirs-toolbox was found, but it is not setup for Git version control. It is likely that you downloaded a copy of fNIRS-Preprocessing that contains a snapshot of nirs-toolbox (e.g., to streamline setup for workshops). If you would like to enable automatic nirs-toolbox updates, then delete external/nirs-toolbox and restart the project. The first sync will take several minutes and 1-2 GB bandwidth.")
    return

elseif repo.LastCommit.ID ~= NIRS_TOOLBOX_TARGET_VERSION
    fprintf("\tNIRS Toolbox is not on the required version. Migrating...\n");
    
    % move to main brain first
    repo.switchBranch("master");

    % remove prior snapshot
    try
        repo.deleteBranch("snapshot");
    end

    % create and move to new snapshot
    repo.switchBranch("snapshot", Create=true, StartPoint=NIRS_TOOLBOX_TARGET_VERSION);
end

% Display
date = repo.LastCommit.AuthorDate;
date.Format = "uuuu-MM-dd";
fprintf("NIRS Toolbox version: %s\n", date);

% Add to VersionInfo
global VersionInfo
VersionInfo.NIRSToolbox = date;

