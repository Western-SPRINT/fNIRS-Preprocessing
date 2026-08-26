function [folder] = validateFolder(folder)
arguments
    folder (1,1) string {mustBeFolder}
end

% always end with filesep
if ~folder.endsWith(filesep)
    folder = folder + filesep;
end