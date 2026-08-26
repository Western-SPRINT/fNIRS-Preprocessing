function [datatypeNames, datatypeColours] = GetDatatypeNamesColours(types)
    if isnumeric(types)
        % wavelengths
        datatypeNames = arrayfun(@(wl) sprintf("%dnm", wl), types);
        datatypeColours = lines(length(types));
        datatypeColours = datatypeColours(end:-1:1,:);

    elseif iscell(types)
        % chromophores
        for i = 1:length(types)
            switch lower(types{i})
                case "hbo"
                    datatypeNames(i)        = "HbO";
                    datatypeColours(i,:)    = [0.8 0 0];

                case "hbr"
                    datatypeNames(i)        = "HbR";
                    datatypeColours(i,:)    = [0 0 0.8];

                case "hbt"
                    datatypeNames(i)        = "HbT";
                    datatypeColours(i,:)    = [0 0.8 0];
            end
        end

    else
        error("Unexpected types format")
    end
end