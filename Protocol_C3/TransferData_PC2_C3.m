% author: ChatGPT (with editing by NWB)
% date (created): 03 Nov. 2024
% purpose: to recursively transfer files and folders to the specified
% destinations, including creating non-existent folders in the destination
% if necessary.
% NOTE: this script assumes that the 'RunProtocol_C3.m' script has just
% been run for the experiment so that the 'participantID' and 'isSession1'
% variables are available in the workspace. retrieve or define them
% manually if this is not the case.
% TODO: update this to be a function since not ideal to reference workspace
% variables (pass as input parameters instead).

%% Specify the participantID and isSession1 variables
%%%%%%%%%%%%%%%%%%%%%%% UPDATE THE BELOW MANUALLY %%%%%%%%%%%%%%%%%%%%%%%%%
participantID = 'C3S14';
isSession1 = false;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%
if isSession1           % if current session is first walking session, ...
    sess = 'Session1';
else                    % otherwise, ...
    sess = 'Session2';  % session two
end

dirPC2Data = fullfile(['C:\Users\Public\Documents\Vicon Training\' ...
    'Stroke_CCC'],participantID,sess);
dirSrvrC3 = 'W:\Nathan\C3';
dirSrvrData = fullfile(dirSrvrC3,'Data',participantID);
dirSrvrRaw = fullfile(dirSrvrC3,'RawBackupData',participantID,sess);

% define source and destination paths in specified order
srcs = {dirPC2Data dirPC2Data};
dests = {fullfile(dirSrvrData,sess,'PC2') fullfile(dirSrvrRaw,'PC2')};

utils.transferDataSess(srcs,dests);

