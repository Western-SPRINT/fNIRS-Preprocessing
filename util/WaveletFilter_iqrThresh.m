classdef WaveletFilter_iqrThresh < nirs.modules.AbstractModule
%% WaveletFilter - Filter to remove outliers (motion) and low freq characteristics.
%
% Options:
%     iqr             - filters out wavelet coeffients exceeding iqr times the interquartile range
%     wbasis          - wavelet basis function (sym8 seems to work well with this implementaiton)
%     removeScaling   - flag to remove low freq scaling coefficients (generally useful, but can cause problems if sampling rate is very low)
        
    properties
        iqr             = 1.2;      % filters out wavelet coeffients exceeding iqr times the interquartile range
        wbasis          = 'sym8';   % wavelet basis function (sym8 seems to work well with this implementaiton)
        removeScaling   = true;     % flag to remove low freq scaling coefficients (generally useful, but can cause problems if sampling rate is very low)
    end
    
    methods

        function obj = WaveletFilter_iqrThresh( prevJob )
           obj.name = 'Remove Trend & Motion w/ Wavelets, uses Homer''s iqr thresholding method';
           
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )

            if obj.iqr < 1
                warning("iqr has been set to ""%g"". Values less than 1 are not recommended.", obj.iqr)
            end
            
            for i = 1:numel(data)
                for j = 1:size(data(i).data, 2)
                    y = data(i).data(:,j);

                    % max level
                    n = wmaxlev(size(y), obj.wbasis);

                    % decomposition
                    [w, l] = wavedec(y, n, obj.wbasis);

                    % cumulative indices
                    L = cumsum([0; l(1:n+1)]);
                    
                    % remove lowest freq components
                    if obj.removeScaling
                        w(1:L(2)) = 0;
                    end

                    % thresholding
                    for k = 2:n+1
                       idx = L(k)+1:L(k+1);

                       % get wavelet coefficients
                       wc = w(idx);
                       
                       % % % NIRS Toolbox sthresh method (from nirs.modules.WaveletFilter)
                       % % sthresh = obj.iqr * 1.35;                % approximate conversion
                       % % abs_SDs = abs(wc) ./ (mad(wc,0)/0.6745); % should this be median instead?
                       % % to_remove = abs_SDs > sthresh;

                       % Homer iqr method (from Homer3 WaveletAnalysis.m)
                       quants = quantile(wc,[.25 .50 .75]);  % compute quantiles
                       IQR = quants(3)-quants(1);  % compute interquartile range
                       prob1 = quants(3)+IQR*obj.iqr;
                       prob2 = quants(1)-IQR*obj.iqr; 
                       to_remove = (wc>prob1) | (wc<prob2);

                       % Apply thresholding
                       w(idx(to_remove)) = 0;
                    end

                    % estimated signal
                    y = waverec(w, l, 'sym8');

                    data(i).data(:,j) = y;
                end
            end
            
        end
    end
end