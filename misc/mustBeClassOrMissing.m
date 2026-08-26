function mustBeClassOrMissing(value, className)
    if ~ismissing(value) && ~isa(value, className)
        error('mustBeClassOrMissing:invalidType', ...
            'Value must be missing or an object of class %s.', className);
    end
end