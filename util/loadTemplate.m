function [scalp,brain,fiducials] = loadTemplate(templateName)
proj = currentProject;

folder = proj.RootFolder + filesep + "external" + filesep + "NIRSite_headmodels" + filesep + templateName + filesep;

scalp = load(folder + "scalp.mat");
brain = load(folder + "brain.mat");

fiducials = readtable(folder + "landmarks.csv");
fiducials.Properties.VariableNames = ["Name" , "X" , "Y" , "Z" , "other"];
fiducials.other = [];
fiducials.Type(:) = {'10-20'};
fiducials.Units(:) = {'mm'};
fiducials.Draw(:) = true;