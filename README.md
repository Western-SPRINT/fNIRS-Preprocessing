# fNIRS-Preprocessing

## Requirements
These tools are currently developed and tested on MATLAB 2026a.

These official MATLAB toolboxes are required:
1. Signal Processing Toolbox
1. Statistics and Machine Learning Toolbox
1. Wavelet Toolbox

Optionally, you can install MATLAB's "Parallel Computing Toolbox" to speed up a few of the slower steps. This can be very beneficial on CPUs with many cores.

## Setup
_Do not manually add this to your MATLAB path. Furthermore, adding with subfolders may result in unintended behaviour._
1. Call `startfNIRSPreprocessing` to open the MATLAB "project". This will configure your path with everything that is needed for the remainder of the session.
    1. This function will also attempt to permanently add the containing folder to the MATLAB path for future sessions. You may need to have run MATLAB with administrator privileges for this to persist across sessions.
    1. The first time that you start the project, it will take several minutes to download the [NIRS Toolbox](https://github.com/huppertt/nirs-toolbox) to `external/nirs-toolbox`. This is a controlled copy of the NIRS Toolbox that will automatically be kept at the latest supported version.
1. Create a `Pipeline` object, set its paths, add any number of `PipelineSteps.*` objects, and then run any number of those steps through `Pipeline.Run*`
1. To close the project and restore your path, either close MATLAB or call `closefNIRSPreprocessing`

## Instructions
Documentation is currently in-progress. More resources will be available through Fall/Winter 2026.

## Contact
Please contact kstubbs5[at]uwo.ca for all inquiries.

## Acknowledgements
This work is funded by [Brain Canada](https://braincanada.ca/funded-grants/sprint-fnirs-platform-for-brain-monitoring-analytics-and-data-repository) (and formerly [BrainsCAN](https://brainscan.uwo.ca/index.html)) in collaboration with [Synapse NeuroAnalytics](https://www.synapseneuroanalytics.com/). Click [here](https://www.uwo.ca/bmi/research/onrgroup/index.html) to learn more about Western University's Optical Neuroimaging Research Group (ONRG, pronounced like "energy").
