function checkMATLABToolboxes
% display
fprintf("Checking MATLAB Toolboxes...\n");

% get name of all version entries
names = arrayfun(@(x) string(x.Name), ver);

% check required MATLAB toolboxes
for name = ["Parallel Computing Toolbox"
            "Signal Processing Toolbox"
            "Statistics and Machine Learning Toolbox"
            "Wavelet Toolbox"
            ]'
    if ~any(names == name)
        error("Missing required official MATLAB toolbox: %s\nIn the ribbon at the top of MATLAB, click the ""Home"" tab and then the ""Add-Ons"" button.\nSearch for this toolbox and install it. You might need to ""run MATLAB as administrator"".", name)
    end
end