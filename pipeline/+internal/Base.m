% Class to enforce setting ClassLastUpdated and storing VersionInfo
classdef Base < handle
    properties (SetAccess = immutable, Hidden)
        VersionInfo (1,1) struct
    end

    methods
        function obj = Base
            % Get VersionInfo from project startup
            global VersionInfo

            % If "clear all" has been used, then VersionInfo will not be
            % available. Close and reopen the project to restore this.
            if isempty(VersionInfo)
                closefNIRSPreprocessing
                startfNIRSPreprocessing
            end

            % Store version info
            obj.VersionInfo = VersionInfo;
        end
    end
end