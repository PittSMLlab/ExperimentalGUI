function exportSessionToC3D(pathSess,indsTrials,vicon)
%EXPORTSESSIONTOC3D Saves specified trials in a session folder to C3D files
%   This function finds all trials in the session folder with filenames
% starting with 'Trial', filters them based on the specified indices, and
% exports each trial as a C3D file.
%
% input(s):
%   pathSess: path to the session folder where all trial data is stored.
%   indsTrials: (optional) array of indices indicating which trials to
%       process. By default, all files starting with 'Trial' are processed.
%   vicon: (optional) Vicon Nexus SDK object. If not supplied, a new Vicon
%       object will be created and connected.

narginchk(1,3);                 % verify correct number of input arguments

% ensure session folder path exists
if ~isfolder(pathSess)
    error('The session folder path specified does not exist: %s',pathSess);
end

% get all trial files that start with 'Trial'
trialFiles = dir(fullfile(pathSess,'Trial*.x1d'));
numTrials = length(trialFiles);

% check if any trial files were found
if numTrials == 0
    fprintf('No trials found in session folder: %s\n',pathSess);
    return;
end

% if 'indsTrials' not provided, process all trials
if nargin < 2 || isempty(indsTrials)
    indsTrials = 1:numTrials;
end

% initialize the Vicon Nexus object if not provided
if nargin < 3 || isempty(vicon)
    fprintf(['No Vicon SDK object provided. Connecting to Vicon ' ...
        'Nexus...\n']);
    vicon = ViconNexus();
end

% process each specified trial
for tr = indsTrials
    if tr > numTrials
        warning('Trial index %d is out of range. Skipping...',tr);
        continue;
    end

    [~,nameTrialNoExt] = fileparts(trialFiles(tr).name);
    pathTrial = fullfile(trialFiles(tr).folder,nameTrialNoExt);
    fprintf('Processing trial %d: %s\n',tr,pathTrial);

    % export trial to C3D using the function from previous implementation
    dataMotion.exportTrialToC3D(pathTrial,vicon);
end

% close the Vicon connection if it was created within this function
% if nargin < 3 || isempty(vicon)
%     vicon.Disconnect();
%     fprintf('Disconnected from Vicon Nexus.\n');
% end

end

