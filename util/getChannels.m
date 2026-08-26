% [channels,has_sdc_info] = GetChannels(data)
%
% Returns "channels" table with:
%   Source
%   Detector
%   TypeIndicesInLinks
%   ShortSeperation (if provided)
%
function [channels,has_sdc_info] = getChannels(data)

%unique s-d pairs
channels = unique(data.probe.link(:,1:2), 'rows');
number_channels = height(channels);

%find channel-type pairs
types = data.probe.types;
number_types = length(types);
inds = cell(number_channels,1);
for c = 1:number_channels
    for t = 1:number_types
        %match source/detector
        ind = data.probe.link.source==channels.source(c) & ...
                    data.probe.link.detector==channels.detector(c);
        
        %match type
        if isnumeric(types)
            ind = ind & (data.probe.link.type == types(t));
        else
            ind = ind & strcmp(data.probe.link.type, types{t});
        end
        
        %should find one match
        ind = find(ind);
        if length(ind) ~= 1
            error
        else
            inds{c}(t) = ind;
        end
    end
end
channels.TypeIndicesInLinks = inds;

% ShortSeperation
has_sdc_info = any(strcmp(data.probe.link.Properties.VariableNames, 'ShortSeperation'));
if has_sdc_info
    channels.ShortSeperation = cellfun(@(i) data.probe.link.ShortSeperation(i(1)), channels.TypeIndicesInLinks);
end

% Excluded
channels.Excluded = cellfun(@(i) data.probe.link.Excluded(i(1)), channels.TypeIndicesInLinks);