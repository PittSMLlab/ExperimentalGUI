function reconstructAndLabelTrial(pathTrial,vicon)
%RECONSTRUCTANDLABEL Run reconstruct and label pipeline on Vicon trial data
%   This function accepts as input the full path to the trial to process by
% running the reconstruct and label pipelines and saving the processed
% trial. Make sure the Vicon Nexus SDK is installed and added to the MATLAB
% path.
%
% input(s):
%   pathTrial: string or character array of the full path of the trial on
%       which to run the reconstruct and label processing pipeline
%   vicon: (optional Vicon Nexus SDK object. Connects if not supplied.

% TODO: add a GUI input option if helpful
narginchk(1,2);         % verify correct number of input arguments

% initialize the Vicon Nexus object if not provided
if nargin < 2 || isempty(vicon)
    fprintf(['No Vicon SDK object provided. Connecting to Vicon ' ...
        'Nexus...\n']);
    vicon = ViconNexus();
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

% The reconstruct step will process the raw camera data and reconstruct 3D
% marker positions. This must be done before labeling.
fprintf('Running reconstruction pipeline...\n');
try                     % try running reconstruct pipeline
    vicon.Reconstruct();
    fprintf('Reconstruction complete.\n');
catch ME
    fprintf('Error during reconstruction: %s\n',ME.message);
end

% The labeling step assigns names to the reconstructed markers based on
% the Vicon Nexus labeling scheme.
fprintf('Running labeling pipeline...\n');
try                     % try running the label pipeline
    vicon.Label();
    fprintf('Labeling complete.\n');
catch ME
    fprintf('Error during labeling: %s\n',ME.message);
end

% Saves the changes made (reconstruction and labeling) back to trial file
fprintf('Saving the trial...\n');
try                     % try saving the processed trial
    vicon.SaveTrial();
    fprintf('Trial saved successfully.\n');
catch ME
    fprintf('Error saving trial: %s\n',ME.message);
end

% close the Vicon connection if it was created within this function
if nargin < 2 || isempty(vicon)
    vicon.Disconnect();
    fprintf('Disconnected from Vicon Nexus.\n');
end

end

