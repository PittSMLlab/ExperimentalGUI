function transferData(src,dest,threshTime)
%TRANSFERFILES Recursively transfer all files and subfolders
%   This function accepts as input (via GUI if no arguments are provided)
% the raw NMWT (with optional 10MWT embedded) measurements (number of laps,
% final distance measurement, whether that measurement should be added) and
% parameters (walkway distance, walk test duration) and optional 10MWT
% times if embedded in the trial and computes as output the OG walking
% speed and optional fast (10MWT) speed.
%
% input(s):
%   src: string or character array of the full path to the source directory
%       to be transferred
%   dest: string or character array of the full path to the destination
%       directory where the data is to be transferred
% output(s):

narginchk(2,3);                 % verify correct number of input arguments
% TODO: add other input argument handling, such as ensure the folder path
% delimiters are correct and that the source directory exists

if ~isfolder(dest)              % if destination folder does not exist, ...
    mkdir(dest);                % create it
end

srcContents = dir(src);         % list of all files and folders in source

for k = 1:length(srcContents)   % for each item in source directory, ...
    itemName = srcContents(k).name;

    % if current (i.e., working) or parent directory, ...
    if strcmp(itemName,'.') || strcmp(itemName,'..')
        continue;               % continue to next item (loop iteration)
    end

    srcItem = fullfile(src,itemName);   % Full path of the source item
    destItem = fullfile(dest,itemName); % Full path of the destination item

    if srcContents(k).isdir             % if item is a directory, ...
        if nargin == 3                  % if three input arguments, ...
            utils.transferData(srcItem,destItem,threshTime);
        else                            % otherwise, only two input args
            utils.transferData(srcItem,destItem);
        end
    else                                % otherwise, ...
        if nargin == 3                  % if threshold time provided, ...
            % only copy recent files generated after the threshold time
            timeFile = datetime(srcContents(k).date, ...
                'InputFormat','dd-MMM-yyyy HH:mm:ss');
            if timeFile > threshTime    % if time exceeds threshold, ...
                if ~exist(destItem,'file')  % if item does not exist, ...
                    copyfile(srcItem,destItem);
                end
            end
        else                            % otherwise, ...
            if ~exist(destItem,'file')      % if item does not exist, ...
                % TODO: add check for same file size and modified date if
                % necessary / beneficial
                copyfile(srcItem,destItem); % copy file to the destination
            end
            % TODO: add optional input if user desires verbose output
            % fprintf('Copied file: %s\n',destItem); % Optional: log each file
        end
    end
end

end

