function exportTrialToC3D(pathTrial,vicon,pathC3D)
%EXPORTTRIALTOC3D Saves a trial as a C3D file with no additional processing
%   This function checks if the specified trial is already open, only
% opening it if necessary, and saves it as a C3D file with no processing
% applied.
%
% input(s):
%   pathTrial: full path to the trial file (e.g., .x2d or folder path).
%   vicon: (optional) Vicon Nexus SDK object. If not supplied, a new Vicon
%       object will be created and connected.
%   pathC3D: (optional) Full path where the C3D file should be saved. If
%       not provided, the function will use the same path as pathTrial with
%       a .c3d extension.

% initialize the Vicon Nexus object if not provided
if nargin < 2 || isempty(vicon)
    fprintf(['No Vicon SDK object provided. Connecting to Vicon ' ...
        'Nexus...\n']);
    vicon = ViconNexus();
end

% default C3D file path if not provided
if nargin < 3 || isempty(pathC3D)
    [trialFolder,trialName] = fileparts(pathTrial);
    pathC3D = fullfile(trialFolder,[trialName '.c3d']);
    fprintf('No C3D path provided. Using default path: %s\n',pathC3D);
end

% check if a trial is already open
isTrialOpen = false;
try
    currentTrialPath = vicon.GetTrialName();
    if ~isempty(currentTrialPath)
        if strcmpi(currentTrialPath,pathTrial)
            fprintf('Trial is already open: %s\n',pathTrial);
            isTrialOpen = true;
        else
            fprintf('Another trial is open. Closing current trial...\n');
            vicon.CloseTrial();
        end
    end
catch ME
    fprintf('Error checking open trial status: %s\n',ME.message);
end

% open the trial if it is not already open
if ~isTrialOpen
    fprintf('Opening trial from %s...\n',pathTrial);
    try
        vicon.OpenTrial(pathTrial,10);
        fprintf('Trial opened successfully.\n');
    catch ME
        fprintf('Error opening trial: %s\n',ME.message);
        return;
    end
end

% export to C3D file
fprintf('Exporting trial to C3D file: %s\n',pathC3D);
try
    vicon.ExportC3D(pathC3D);
    fprintf('C3D file exported successfully at %s\n',pathC3D);
catch ME
    fprintf('Error exporting to C3D: %s\n',ME.message);
end

% close the Vicon connection if it was created within this function
if nargin < 2 || isempty(vicon)
    vicon.Disconnect();
    fprintf('Disconnected from Vicon Nexus.\n');
end

end

