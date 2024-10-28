% author: ChatGPT (with editing by NWB)
% date (created): 28 Oct. 2024
% purpose: to recursively transfer files and folders to the specified
% destinations, including creating non-existent folders in the destination
% if necessary.
% NOTE: this script assumes that the 'RunProtocol_C3.m' script has just
% been run for the experiment so that the 'participantID' and 'isSession1'
% variables are available in the workspace. retrieve or define them
% manually if this is not the case.

if isSession1           % if current session is first walking session, ...
    sess = 'Session1';
else                    % otherwise, ...
    sess = 'Session2';  % session two
end

% Define source and destination paths in specified order
paths = {
    fullfile('C:\Users\Public\Documents\Vicon Training\Stroke_CCC', ...
    participantID,sess) fullfile('W:\Nathan\C3\Data',participantID, ...
    sess,'PC1');
    fullfile(['C:\Users\Public\Documents\MATLAB\ExperimentalGUI\' ...
    'profiles\Stroke_CCC'],participantID) fullfile('W:\Nathan\C3\Data', ...
    participantID,'Profiles');
    fullfile('C:\Users\Public\Documents\Vicon Training\Stroke_CCC', ...
    participantID,sess) fullfile('W:\Nathan\C3\RawBackupData', ...
    participantID,sess,'PC1')
    };

% TODO: add datalog automatic transfer by checking date modified / filename
% 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\datlogs'
% 'W:\Nathan\C3\Data\PilotSL\Session1\DataLogsUnsyncd'
% TODO: automatically create the folders for PC2 if they do not already
% exist even though those will need to be manually transferred using other
% computer

% Loop through each source-destination pair and initiate recursive copy
for p = 1:size(paths,1)     % for each source-destination pair, ...
    srcDir = paths{p,1};    % source directory
    destDir = paths{p,2};   % destination directory
    fprintf('Transferring from %s to %s\n',srcDir,destDir);
    utils.transferData(srcDir,destDir); % call recursive data transfer fxn
end

