classdef calcSlidingSCI_v3 < nirs.modules.AbstractModule
    properties
        window_length_seconds = 5
        expected_cardiac_bpm_min = 50
        expected_cardiac_bpm_max = 110
        calc_PSP = true % approx x10 slower, disable if not needed
        samples_to_run = [] % defaults to all if sample indices are not provided
    end
    
    methods
        function obj = calcSlidingSCI_v3( prevJob )
            obj.name = 'Calculates the SCI (and optionally PSP) per channel in a sliding window centered on each timepoint';
            if nargin > 0
                obj.prevJob = prevJob;
            end
        end
        
        function data_out = runThis( obj, data )
            propNames = properties(obj);
            job = cell2struct(cellfun(@(f) obj.(f), propNames, 'UniformOutput', false), propNames);

            data_out = repmat(struct(time=[], channels=[], SCI=[], PSP=[], job=job), size(data));
            for i = 1:numel(data)
                % confirm that this is wavelength data
                if ~isnumeric(data(1).probe.types)
                    error("Signals must be wavelengths")
                end

                % get time and channels
                data_out(i).time = data(i).time;
                data_out(i).channels = getChannels(data(i));

                % prepare frequency band
                Fs = data(i).Fs;
                fcut_min = obj.expected_cardiac_bpm_min / 60;
                fcut_max = obj.expected_cardiac_bpm_max / 60;
                if (fcut_min < 0)
                    fcut_min = 0;
                    warning("expected_cardiac_bpm_min was less than zero! Set to 0 Hz.")
                end
                fmax = Fs * (0.5 - 1E-10); % 0.5 causes rounding issues
                if (fcut_max > fmax)
                    fcut_max = fmax;
                    warning("expected_cardiac_bpm_max was set higher than the sampling rate allows for. Set to %f Hz (%f bpm).", fcut_max, 60*fcut_max)
                end
                if (fcut_min >= fcut_max)
                    error("Invalid cardiac range")
                end

                % apply cardiac filter and normalization
                all_signals = obj.filter_and_normalize(data(i).data, Fs, fcut_min, fcut_max);

                % counts
                number_timepoints = length(data_out(i).time);
                number_channels = height(data_out(i).channels);

                % initialize SCI
                SCI = nan(number_channels, number_timepoints);
                PSP = nan(size(SCI));

                % which windows to run?
                if isempty(obj.samples_to_run)
                    windows_to_run = true(1, number_timepoints); % run all windows
                else
                    windows_to_run = false(1, number_timepoints); % run only the specified windows
                    windows_to_run(obj.samples_to_run) = true;
                end

                % for each channel...
                for channel = 1:number_channels
                    % get channel signals (time x wavelengths)
                    channel_signals = all_signals(:, data_out(i).channels.TypeIndicesInLinks{channel});                    

                    % for each timepoint...
                    parfor t = 1:number_timepoints % must be consecutive integers to do parfor
                        % run this window?
                        if ~windows_to_run(t)
                            continue
                        end

                        % time to center window
                        center = data_out(i).time(t);

                        % select window timepoints
                        select = abs(data_out(i).time - center) <= (obj.window_length_seconds / 2);
                        
                        % get window signals
                        window_signals = channel_signals(select, :);

                        % calculate SCI
                        [SCI(channel, t), PSP(channel, t)] = obj.calc_SCI(window_signals, obj.calc_PSP, Fs, fcut_max);
                    end

                end

                % initialize SCI
                data_out(i).SCI = SCI;
                data_out(i).PSP = PSP;


                % reduce channels to just S/D
                data_out(i).channels = data_out(i).channels(:, ["source" "detector"]);
            end
        end
        
    end

    methods ( Access=private, Static=true )
        function normalized = filter_and_normalize(signals, Fs, fcut_min, fcut_max)
            [B1,A1] = butter(1, [fcut_min*(2/Fs) fcut_max*(2/Fs)]);

            filtered = filtfilt(B1, A1, signals);

            normalized = filtered ./ std(filtered);
        end

        function [SCI, PSP] = calc_SCI(signals, calc_PSP, Fs, fcut_max)
            % size
            [number_timepoints, number_wavelengths] = size(signals);

            % init
            SCIs = nan(((number_wavelengths^2)-number_wavelengths)/2, 1);
            PSPs = nan(size(SCIs));

            % calculate SCI for each pair of wavelengths
            c = 0;
            for i = 1:number_wavelengths
                for j = (i+1):number_wavelengths
                    % method from QT-NIRS...
                    similarity = xcorr(signals(:,i), signals(:,j), 'unbiased');
                    if any(abs(similarity)>eps)
                        % % this makes the SCI=1 at lag zero when x1=x2 AND makes the power estimate independent of signal length, amplitude and Fs
                        similarity = number_timepoints * similarity ./ sqrt(sum(abs(signals(:,i)).^2)*sum(abs(signals(:,j)).^2));
                    else
                        % warning('Similarity results close to zero');
                    end
                    similarity(isnan(similarity)) = 0;

                    %store SCI
                    c=c+1;
                    SCIs(c) = similarity(number_timepoints);

                    %psp
                    if calc_PSP
                        [pxx,f] = periodogram(similarity,hamming(length(similarity)),length(similarity),Fs,'power');
                        [PSPs(c),~] = max(pxx(f<fcut_max)); % FIX Make it age-dependent
                    end
                end
            end

            % return average of all wavelength pairs
            SCI = mean(SCIs);
            PSP = mean(PSPs);
        end
    end
end