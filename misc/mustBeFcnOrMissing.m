function mustBeFcnOrMissing(value)
    if ~(ismissing(value) || isa(value, "function_handle"))
        error("mustBeFcnOrEmpty:invalidType", ...
            "Value must be a function handle or missing.");
    end
end