function transferDataAndSaveC3D_AutoStudy(participantID,visitNum, PCNum, studyName, indsTrials)
%TRANSFERDATAANDSAVEC3D_PC2_C3 Transfer PC2 data and save C3D files for C3
%   This function accepts the participant ID and a boolean indicating the
% session as input arguments and recursively transfers all data to the
% server (including creating non-existant folders if necessary) and exports
% the transferred files to the C3D format using the Vicon Nexus SDK.
%
% input(s):
%   participantID: string or character array of the ID (e.g., 'C3S15')
%   visitNum: integer representing visit number, allowed values 1-4
%   StudyName: string of study name (e.g., YANirsAutomatiictyStudy), this is
%        typically where the vicon data are collected under and the server
%        folder name where all data will be saved.
%   indsTrials: (optional) indices of the trials to export to C3D; if
%       omitted, all trials are processed

if nargin == 0 %no input, ask user
    answer = inputdlg({'SubjectID (e.g., BW01)','VisitNum (1,2,3,or 4)','PCNum (1 or 2)','StudyName (e.g.,BrainWalk)','Trials to copy (default empty, integer vector, e.g., [1,3,5]))'},...
        'Copy PC2 Data to Server',[1 45; 1 45; 1 45; 1 45; 1 45],...
        {'BW01','1','1','BrainWalk','[ ]'});
    participantID = answer{1};
    if ~isa(eval(answer{2}),'double') %input format check, something that's not a number was inputed, throw an error
        error('Invalid input given, visit number should be a single digit number')
    end
    visitNum = sprintf('V0%d',eval(answer{2}));
    
    if ~isa(eval(answer{3}),'double') %input format check, something that's not a number was inputed, throw an error
        error('Invalid input given, PC number should a single digit number, 1 or 2')
    end
    PCNum = eval(answer{3});

    studyName = answer{4};
    indsTrials = eval(answer{5});
else
    narginchk(4,5); %min3, max 4 inputs needed.
    visitNum = sprintf('V0%d',visitNum);

    % set default for indsTrials if not provided
    if nargin < 5
        indsTrials = [];    % empty to indicate all trials
    end
end

if PCNum == 1
    if strcmp(visitNum,'V01') %longest, about 4-4.5 hours
        threshTime = datetime('now','InputFormat','dd-MMM-yyyy HH:mm:ss') - hours(5); %get everything from 5 hours ago
    elseif strcmp(visitNum,'V02') %longest, about 4-4.5 hours
        threshTime = datetime('now','InputFormat','dd-MMM-yyyy HH:mm:ss') - hours(3.5); %get everything from 5 hours ago
    elseif strcmp(visitNum,'V03') %longest, about 4-4.5 hours
        threshTime = datetime('now','InputFormat','dd-MMM-yyyy HH:mm:ss') - hours(3); %get everything from 5 hours ago
    end
    answer = inputdlg({'Will copy datalog generated after the time below: (if you disagree, change it)'},...
            'Datalog time',[1 45;],...
            {char(threshTime)});
    threshTime = datetime(answer{1});
end

if PCNum == 1
    button=questdlg('Do you want to batch process and fill gaps right away after copying the data (Select yes if you have ~2 hours time on this computer)?');
    %takes 5mins per trial for gap filling
else
    button=questdlg('Do you want to batch process export c3d away after copying the data (Select yes if you have 1 hours time on this computer)?');
end
if strcmp(button,'Yes') %automatically advance to next condition.
    batchProcess = true;
else
    batchProcess = false;
end

dirSrvrData = fullfile(['W:\' studyName '\Data'],participantID, visitNum);
dirSrvrRaw = fullfile(['W:\' studyName '\DataBackup\'],participantID,visitNum);   
    
if PCNum == 2
    % define data paths based on input parameters
    dirLocalData = fullfile(['C:\Users\Public\Documents\Vicon Training\' ...
        studyName],participantID,visitNum);

    % define source and destination paths in specified order
    srcs = {dirLocalData dirLocalData};
    dests = {fullfile(dirSrvrData,['PC' num2str(PCNum)]) fullfile(dirSrvrRaw,['PC' num2str(PCNum)])};
    threshTime = []; %copy all data with no threshTime
else
    % define data paths based on input parameters
    dirLocalData = fullfile('C:\Users\Public\Documents\Vicon Training\',...
        studyName,participantID,visitNum);
    srcs = {dirLocalData dirLocalData};
    dests = {fullfile(dirSrvrData,'Vicon') fullfile(dirSrvrRaw,'Vicon')};
    
    % define source and destination paths in specified order
    dirPC1ExpGUI = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI';
    srcs(end+1:end+2) = {fullfile(dirPC1ExpGUI,'datlogs'), fullfile(dirPC1ExpGUI,'datlogs')};
    dests(end+1:end+2) = {fullfile(dirSrvrData,'Datalog'),fullfile(dirSrvrRaw,'Datalog')};
    
    % copy NIRS if it's viist1
    if strcmp(visitNum,'V01')
       dirOxy = fullfile('C:\Users\cntctsml\Documents\Oxysoft Data\',studyName,participantID);
       srcs(end+1:end+2) = {dirOxy, dirOxy};
       dests(end+1:end+2) = {fullfile(dirSrvrData,'NIRS'),fullfile(dirSrvrRaw,'NIRS')};
    end
end

% check if local data directory exists, else raise a warning
for i = 1:2:numel(srcs)%check srcs, skip every other one bc there is a repeat
    if ~isfolder(srcs{i})
        error('Local data directory does not exist: %s\n',srcs{i});
    end
end

% transfer data using utility function with error handling
try
    fprintf('...Copying data to the server...\n')
    utils.transferDataSess(srcs,dests, threshTime);         % transfer data
catch ME
    warning(ME.identifier,'Data transfer failed: %s\n',ME.message);
    return;
end

% check if destination directory was created and populated
for i = 1:numel(dests)
    if ~isfolder(dests{i})
        error('Data transfer unsuccessful; destination folder should have been created with data copoied inside, but not found: %s\n',dests{i});
    end
end
fprintf('...Data copying successful...\n')

if batchProcess
    if PCNum == 1
        % reconstruct and label and fill gaps, this is very time consuming.
        % Do not do this on the testing computer unless you are sure you
        % have enough time.
        try
            tic %TODO: we may want to log the output for debugging/checking later.
            fprintf('...Reconstruct and label and gap filling...\n')
            dataMotion.processAndFillMarkerGapsSession(fullfile(dirSrvrData,'Vicon'));
            toc
        catch ME
            warning(ME.identifier,'Error exporting to C3D: %s\n',ME.message);
        end
    else
        % export session trials to C3D using dataMotion functions
        try
            fprintf('...Exporting file to c3d...\n')
            dataMotion.exportSessionToC3D(fullfile(dirSrvrData,'PC2'),indsTrials);
        catch ME
            warning(ME.identifier,'Error exporting to C3D: %s\n',ME.message);
        end
    end
    fprintf('...Batch processing and gap filling complete...\n')
end
end

