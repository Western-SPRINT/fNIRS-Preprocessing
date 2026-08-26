function warningTraceless(varargin)

% combine arguments
message = sprintf(varargin{:});

% prior global setting state
priorState = warning('query', 'backtrace');

% try...
try
    % turn of trace
    warning('off', 'backtrace');

    % do warning
    warning(message)
end

% set global setting back
warning(priorState.state, 'backtrace');