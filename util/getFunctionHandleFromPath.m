function [handle] = getFunctionHandleFromPath(filepath)
arguments
    filepath (1,1) string {mustBeFile}
end

% Parse filepath
[fol, name, ext] = fileparts(filepath);

% If no folder path, then it is in the current folder
if fol == ""
    fol = string(pwd);
end

% Must be .m
if ext ~= ".m"
    error("File must be .m")
end

% Remember current folder
priorFol = pwd;

% Try to get function handle
try
    cd(fol)
    handle = str2func(name);
catch err
    cd(priorFol)
    rethrow(err)
end

% Return
cd(priorFol)
