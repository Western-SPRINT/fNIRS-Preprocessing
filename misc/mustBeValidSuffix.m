function mustBeValidSuffix(value)

% must have length of 1+
if ~value.strlength
    error("Suffix may not be empty")
end

% % must be upper case
% if value ~= value.upper
%     error("Suffix must be upper case")
% end

% must not contain - or _
if value.contains(["-" "_"])
    error("Suffix may not contain ""-"" or ""_""")
end

% check if Java works
try
    java.io.File(pwd);
    javaWorks = true;
catch
    javaWorks = false;
end

% can only validate if java works, else skip the check
if javaWorks
    % must be valid in a filename
    try
        java.io.File(value).toPath;
    catch
        error("Suffix may not contain illegal filename characters")
    end
end