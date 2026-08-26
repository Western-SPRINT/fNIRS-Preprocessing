function checkGitUpdates
% Display
fprintf("Checking GitHub repository for updates...\n");

% Get project
proj = currentProject;

% Handle non-Git installs
try
    % Get repo
    repo = gitrepo(proj.RootFolder);
    
    % Fetch any changes
    repo.fetch;
    
    % Compare current to latest, display new commits
    indCurrent = find(strcmp(repo.LastCommit.ID, repo.log.ID));
    if indCurrent > 1
        fprintf("\tThe following changes could be pulled:\n");
        for i = 1 : (indCurrent-1)
            fprintf("\t\t%s: %s\n", repo.log.CommitterDate(i), repo.log.Message(i));
        end
        warningTraceless("There are changes available from GitHub. When you are ready to update, either pull these changes manually or call ""pullGitHubChanges"".")
    end
catch
    warningTraceless("Could not check GitHub for update. Either the install didn't use Git or you are not connected to the internet.")
end