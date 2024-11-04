function reconstructAndLabelSession(pathSess,indsTrials)
%RECONSTRUCTANDLABELSESSION Summary of this function goes here
%   Detailed explanation goes here

% TODO: accept server path as input, verify there is data present in the
% folder, and retrieve the files for which to run reconstruct and label
% TODO: add a GUI input option if helpful
narginchk(1,2);                 % verify correct number of input arguments

if nargin == 2                  % if both input arguments provided, ...
    numTrials = length(indsTrials);         % number of trials to process
    indsTrialsStr = strings(1,numTrials);   % instantiate trial strings
    for tr = 1:numTrials        % for each trial, ...
        if indsTrials(tr) < 10  % if trial 1 - 9, add leading zero
            indsTrialsStr(tr) = ['0' num2str(indsTrials(tr))];
        else                    % otherwise, no leading zero
            indsTrialsStr(tr) = num2str(indsTrials(tr));
        end
    end
    pathsTrials = cellfun(@(s) fullfile(pathSess,['Trial' s]), ...
        indsTrialsStr,'UniformOutput',false);   % trial paths to process
else                            % otherwise, ...
    allContents = dir(pathSess);            % retrieve all folder contents
    allNames = {allContents.name};          % extract names for searching
    isTrial = startsWith(allNames,'Trial'); % must start with 'Trial'
    isX2D = endsWith(allNames,'x2d');       % and end with 'x2d'
    trials = allContents(isTrial & isX2D);
    pathsTrials = cellfun(@(s) fullfile(pathSess,s(1:end-4)), ...
        {trials.name},'UniformOutput',false);   % trial paths to process
end

% This script uses Vicon Nexus SDK to load a trial, run reconstruct, and
% label the data. Make sure the Vicon Nexus SDK is installed and added to
% the MATLAB path.
vicon = ViconNexus();           % initialize the Vicon Nexus SDK object

for tr = 1:numTrials            % for each session trial to process, ...
    nexus.reconstructAndLabelTrial(pathsTrials{tr});    % run processing
end

vicon.Disconnect();             % clean up and close Vicon Nexus session
fprintf('Vicon Nexus session closed.\n');

end

