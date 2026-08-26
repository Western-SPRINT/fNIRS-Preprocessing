function defaultLogFcn(message, pipeline)
arguments
    message     (1,1)   string {mustBeNonempty}
    pipeline    (1,1)   Pipeline
end

warning("TODO: DefaultLogFcn: %s", message)