%Requires MATLAB Signal Processing Toolbox
classdef bandpassFilterPadded < nirs.modules.AbstractModule
    properties
        passbandFrequencies = [0.01 0.1];
    end
    
    methods
        function obj = bandpassFilterPadded( prevJob )
           obj.name = 'Bandpass Filter with Padding';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            if length(obj.passbandFrequencies)~=2 || ~isnumeric(obj.passbandFrequencies) || any(isnan(obj.passbandFrequencies)) || any(obj.passbandFrequencies <= 0)
                error('Invalid passband')
            else
                % for each file
                for i = 1:numel(data)
                    % set any NaN values to 0
                    was_nan = isnan(data(i).data);
                    if any(was_nan(:))
                        warning("NaN values detected. These will be set to 0 during the filter and then returned to NaN afterwards.")
                    end

                    % pad
                    values = data(i).data;
                    [number_samples, number_signals] = size(values);
                    values = [zeros(number_samples, number_signals);
                              values;
                              zeros(number_samples, number_signals)];
                    
                    % filter
                    values = bandpass(values, obj.passbandFrequencies, data(i).Fs);

                    % unpad
                    values = values( (number_samples+1) : (2*number_samples) , : );

                    % put back NaNs
                    values(was_nan) = nan;

                    % store the result
                    data(i).data = values;
                end
            end
        end
        
    end
end