% author: ChatGPT (with editing by NWB)
% date (created): 28 Oct. 2024
% purpose: to recursively transfer files and folders to the specified
% destinations, including creating non-existent folders in the destination
% if necessary.
% NOTE: this script assumes that the 'RunProtocol_C3.m' script has just
% been run for the experiment so that the 'participantID' and 'isSession1'
% variables are available in the workspace. retrieve or define them
% manually if this is not the case.
% TODO: update this to be a function since not ideal to reference workspace
% variables (pass as input parameters instead).

if isSession1           % if current session is first walking session, ...
    sess = 'Session1';
else                    % otherwise, ...
    sess = 'Session2';  % session two
end

dirPC1ExpGUI = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI';
dirPC1Profiles = fullfile(dirPC1ExpGUI,'profiles','Stroke_CCC', ...
    participantID);
dirPC1Data = fullfile(['C:\Users\Public\Documents\Vicon Training\' ...
    'Stroke_CCC'],participantID,sess);
dirSrvrC3 = 'W:\Nathan\C3';
dirSrvrData = fullfile(dirSrvrC3,'Data',participantID);
dirSrvrRaw = fullfile(dirSrvrC3,'RawBackupData',participantID,sess);

% Define source and destination paths in specified order
pathsTransfer = {
    dirPC1Data fullfile(dirSrvrData,sess,'PC1');
    dirPC1Profiles fullfile(dirSrvrData,'Profiles');
    dirPC1Data fullfile(dirSrvrRaw,'PC1');
    fullfile(dirPC1ExpGUI,'datlogs') fullfile(dirSrvrData,sess, ...
    'DataLogsUnsyncd')
    };

pathsCreate = {
    fullfile(dirSrvrData,sess,'Figures')
    fullfile(dirSrvrData,sess,'SyncFiles')
    };

for p = 1:size(pathsTransfer,1)     % for each source-destination pair, ...
    srcDir = pathsTransfer{p,1};    % source directory
    destDir = pathsTransfer{p,2};   % destination directory
    if strcmp(srcDir,fullfile(dirPC1ExpGUI,'datlogs'))  % if data logs, ...
        fprintf('Transferring recent files from %s to %s\n', ...
            srcDir,destDir);        % only transfer recent files
        utils.transferData(srcDir,destDir,threshTime);  % call transfer fxn
    else
        fprintf('Transferring from %s to %s\n',srcDir,destDir);
        utils.transferData(srcDir,destDir); % call recursive transfer fxn
    end
end

for p = 1:length(pathsCreate)       % for each path to create, ...
    if ~isfolder(pathsCreate{p})    % if does not already exist, ...
        mkdir(pathsCreate{p});      % create it
    end
end

