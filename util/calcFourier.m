% [power,freq] = CalcFourier(data, freq_range, time_start_end)
%
% Returns the power at each frequency for each signal.
%
% Optional Inputs:
%   freq_range (1x2 numeric)
%       lower/upper frequency limits to return
%       defaults to full range
%
%   time_start_end (1x2 numeric)
%       start/end time to select in signals
%       defaults to full duration
%
function [power,freq] = calcFourier(data, freq_range, time_start_end)

%% Defaults

freq_upper_limit = data.Fs/2;
if ~exist('freq_range', 'var')
    freq_range = [0 freq_upper_limit];
elseif freq_range(2) >= freq_upper_limit
    freq_range(2) = freq_upper_limit;
end

if ~exist('time_start_end', 'var')
    time_start_end = [-inf +inf];
end

%% Calculate

%select samples
samples_select = (data.time >= time_start_end(1)) & (data.time <= time_start_end(2));
samples_select_count = sum(samples_select);

%calc fourier
y = fft(data.data(samples_select,:));  
power = abs(y);

%select frequencies
freq = (0:samples_select_count-1)*data.Fs/samples_select_count;
freq_select = (freq>=freq_range(1)) & (freq<=freq_range(2));

%restrict frequencies
power = power(freq_select, :);
freq = freq(freq_select);