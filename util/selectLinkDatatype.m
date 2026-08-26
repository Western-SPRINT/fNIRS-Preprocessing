function [isType] = selectLinkDatatype(data, type)
if isnumeric(type)
    isType = (data.probe.link.type == type);
elseif iscell(type)
    isType = strcmp(data.probe.link.type, type{1});
elseif isstring(type)
    isType = strcmp(data.probe.link.type, type);
end
