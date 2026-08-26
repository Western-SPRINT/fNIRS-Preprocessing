function pullGitHubChanges
% Get project
proj = currentProject;

% Handle non-Git installs
try
    % Get repo
    repo = gitrepo(proj.RootFolder);
    
    % Display
    fprintf("Looking for changes on GitHub...\n")
    indCurrent = find(strcmp(repo.LastCommit.ID, repo.log.ID));
    if indCurrent == 1
        fprintf("You are already up-to-date.\n");
        return
    else
        fprintf("The following changes will be pulled:\n");
        for i = 1 : (indCurrent-1)
            fprintf("\t%s: %s\n", repo.log.CommitterDate(i), repo.log.Message(i));
        end
    end

    % Fetch and pull
    repo.fetch;
    repo.pull;

    % Complete
    fprintf("Complete! The project will now restart.\n")

    % Restart project in case it is needed
    closefNIRSPreprocessing
    startfNIRSPreprocessing
catch
    warningTraceless("Could not check GitHub for update. Either the install didn't use Git or you are not connected to the internet.")
end