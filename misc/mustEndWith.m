function mustEndWith(value,suffix)
arguments
    value  (1,1) string {mustBeNonmissing}
    suffix (1,1) string {mustBeNonmissing}
end
if ~value.endsWith(suffix)
    error("Value must end with: %s", suffix)
end