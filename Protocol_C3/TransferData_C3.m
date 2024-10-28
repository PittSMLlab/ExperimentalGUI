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

dataPC1 = fullfile(['C:\Users\Public\Documents\Vicon Training\' ...
    'Stroke_CCC'],participantID,sess);
dataSrvr = fullfile('W:\Nathan\C3\Data',participantID);

% Define source and destination paths in specified order
pathsTransfer = {
    dataPC1 fullfile(dataSrvr,sess,'PC1');
    fullfile(['C:\Users\Public\Documents\MATLAB\ExperimentalGUI\' ...
    'profiles\Stroke_CCC'],participantID) fullfile(dataSrvr,'Profiles');
    dataPC1 fullfile('W:\Nathan\C3\RawBackupData',participantID,sess,'PC1')
    };

pathsCreate = {
    fullfile(dataSrvr,sess,'DataLogsUnsyncd')
    fullfile(dataSrvr,sess,'Figures')
    fullfile(dataSrvr,sess,'PC2')
    fullfile(dataSrvr,sess,'SyncFiles')
    fullfile('W:\Nathan\C3\RawBackupData',participantID,sess,'PC2')
    };

% TODO: add datalog automatic transfer by checking date modified / filename
% 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\datlogs'
% 'W:\Nathan\C3\Data\PilotSL\Session1\DataLogsUnsyncd'

for p = 1:size(pathsTransfer,1)     % for each source-destination pair, ...
    srcDir = pathsTransfer{p,1};    % source directory
    destDir = pathsTransfer{p,2};   % destination directory
    fprintf('Transferring from %s to %s\n',srcDir,destDir);
    utils.transferData(srcDir,destDir); % call recursive data transfer fxn
end

for p = 1:length(pathsCreate)       % for each path to create, ...
    if ~isfolder(pathsCreate{p})    % if does not already exist, ...
        mkdir(pathsCreate{p});      % create it
    end
end

