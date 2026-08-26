function mustBeRange(value)
arguments
    value (1,2) double
end
if value(1) >= value(2)
    error("Value must have range")
end