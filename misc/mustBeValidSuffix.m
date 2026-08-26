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

% must be valid in a filename
try
    java.io.File(value).toPath;
catch
    error("Suffix may not contain illegal filename characters")
end