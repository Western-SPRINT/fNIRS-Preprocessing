% [autocorrs,lags] = CalcAutocorr(data, duration_sec)
%
% Returns the autocorr at each lag for each signal.
%
% Optional Inputs:
%   duration_sec (1x1 numeric)
%       Duration to model
%       defaults to 20 seconds
%
function [autocorrs,lags] = CalcAutocorr(data, duration_sec)

%%

if ~exist("duration_sec", "var")
    duration_sec = 20;
end

%%

numLags = round(duration_sec * data.Fs);
numSignals = size(data.data, 2);

autocorrs = nan(1+numLags, numSignals);

for i = 1:numSignals
    [ac, l] = xcorr(data.data(:,i) - nanmean(data.data(:,i)), numLags, "coeff");
    autocorrs(:,i) = ac(l >= 0);
end

lags = 0 : (1 / data.Fs) : (numLags / data.Fs);