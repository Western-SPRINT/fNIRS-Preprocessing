function getVersionDates
% Global variable
global VersionInfo

% fNIRS-Preprocessing
VersionInfo.Project = getProjectVersion;

% NIRSite Meshes
VersionInfo.NIRSiteModels = NIRSite_headmodels_version;

% NIRSite Meshes
VersionInfo.Homer3SNIRF = Homer3_SNIRF_version;

% MATLAB
VersionInfo.MATLAB = version;

% NIRS Toolbox
VersionInfo.NIRSToolbox = []; % set by getNIRSToolbox

% All Toolboxes
VersionInfo.AllToolboxes = ver;