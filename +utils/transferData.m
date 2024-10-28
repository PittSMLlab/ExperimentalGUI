function transferData(src,dest)
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

narginchk(2,2);                 % verify correct number of input arguments
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
        utils.transferData(srcItem,destItem);	% recursive function call
    else                                % otherwise, ...
        if ~exist(destItem,'file')      % if item already exists, ...
            % TODO: add check for same file size and modified date if
            % necessary / beneficial
            copyfile(srcItem,destItem); % copy file to the destination
        end
        % fprintf('Copied file: %s\n',destItem); % Optional: log each file
    end
end

end

