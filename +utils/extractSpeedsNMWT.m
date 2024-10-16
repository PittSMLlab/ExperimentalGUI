function [speedNMWT,speed10MWT] = extractSpeedsNMWT(numLaps,distInches, ...
    shouldAdd,distWalkway,duration,times_10MWT)
%EXTRACTSPEEDSNMWT Extracts the speed(s) from an NMWT (with 10MWT embedded)
%   This function accepts as input (via GUI if no arguments are provided)
% the raw NMWT (with optional 10MWT embedded) measurements (number of laps,
% final distance measurement, whether that measurement should be added) and
% parameters (walkway distance, walk test duration) and optional 10MWT
% times if embedded in the trial and computes as output the OG walking
% speed and optional fast (10MWT) speed.
%
% input(s):
%   numLaps: the number of laps to be computed for the participant
%   distInches: the final distance measurement (in inches) taken by the
%       yellow tape measure (TODO: if SML has a long tape measure in the
%       future that is metric can change this to distance in m or cm)
%   shouldAdd: logical 'true' or 'false' indicating whether the above
%       distance should be added or subtracted from the computed laps
%   duration: length of time of the NMWT (default: six minutes)
%   times_10MWT: 1 x N array of 10MWT times to be averaged to compute a
%       fast OG walking speed (default: NaN, speed not computed)
% output(s):
%   speedNMWT: the (comfortable) OG walking speed (in meters / second)
%   speed10MWT: (optional) the fast OG walking speed (in meters / second)

narginchk(0,6);                 % verify correct number of input arguments

% TODO: if want to get really fancy, handle other numbers of input
% arguments or passing arguments in different order using 'varargin'
% TODO: is there a way to make this work for Marcela's experiment also
% (where they only collect 10MWT trials)?
if nargin == 0                  % if no input arguments, ...
    % retrieve N-Minute/10-Meter Walk Test data from experimenter via GUI
    prompt = { ...
        'How many N-Minute Walk Test laps should be computed?', ...
        'What is the tape measure distance (in inches)?', ...
        ['Should the additional distance be added to the laps above? ' ...
        '(rather than subtracted, ''1'' = true, ''0'' = false)'], ...
        ['What is the walkway distance (in meters, default: 12.2 for ' ...
        'Schenley Place gym)'], ...
        'How many minutes was the walk test (default: ''6'' minutes)?', ...
        ['Enter the list of 10-Meter walk times (in seconds) you ' ...
        'would like to average to compute the fast overground walking' ...
        ' speed (or ''NA'' if not applicable):']};
    dlgtitle = 'NMWT/10MWT Experimental Inputs';
    fieldsize = [1 125; 1 125; 1 125; 1 125; 1 125; 1 125];
    definput = { ...
        '30', ...                           number of NMWT laps
        '0', ...                            tape measure distance (inches)
        '1', ...                            should add above distance?
        '12.2', ...                         walkway distance (in meters)
        '6', ...                            number of minutes (walk test)
        ...                                 10MWT times (in seconds) list
        '7.00 7.00 7.00 7.00 7.00 7.00 7.00 7.00 7.00 7.00'};
    answer = inputdlg(prompt,dlgtitle,fieldsize,definput);

    % extract NMWT/10MWT experimental parameters
    numLaps = str2double(answer{1});            % number of NMWT laps
    distInches = str2double(answer{2});         % measure distance (inches)
    shouldAdd = logical(str2double(answer{3})); % should + or - distance?
    distWalkway = str2double(answer{4});        % walkway distance (meters)
    duration = str2double(answer{5});           % walk test duration (min.)
    times_10MWT = strsplit(answer{6},' ');      % list 10MWT times (secs)
    if strcmp(times_10MWT{1},'NA')              % if no lap times, ...
        times_10MWT = nan;                      % set to NaN
    else                                        % otherwise, extract times
        times_10MWT = cellfun(@(x) str2double(x),times_10MWT);
    end
elseif nargin == 3              % if three input arguments, ...
    distWalkway = 12.2;         % default to 12.2 meters (Schenley gym)
    duration = 6;               % default to 6MWT
    times_10MWT = nan;          % assume user does not care about 10MWT
elseif nargin == 4              % if four input arguments, ...
    duration = 6;               % default to 6MWT
    times_10MWT = nan;          % assume user does not care about 10MWT
elseif nargin == 5
    times_10MWT = nan;          % assume user does not care about 10MWT
else                            % otherwise, ...
    % do nothing for now
    % error(['An incorrect number of input arguments has been supplied. ' ...
    %     'Pass either no input arguments to open GUI, three, four, or ' ...
    %     'five input arguments']);
end

% compute NMWT speed
if shouldAdd                            % if should add distance, ...
    % compute NMWT distance as sum of # of laps times walkway distance
    % (~12.2 meters) + remainder distance in inches converted to meters
    % TODO: assuming NMWT completed in Schenley Place gym, update to handle
    % NMWT collected in lab or other location with different walkway dist.
    dist_NMWT = (numLaps * distWalkway) + (distInches * 0.0254);
else                                    % otherwise, subtract distance
    dist_NMWT = (numLaps * distWalkway) - (distInches * 0.0254);
end
% convert walk test duration to seconds for speed in meters per second
speedNMWT = dist_NMWT / (duration * 60);% NMWT (OG) speed (comfortable)

if (nargout == 2)                       % if user requests both speeds, ...
    speed10MWT = nan;                   % default to 'NaN'
    if all(~isnan(times_10MWT))         % 10MWT times array is not 'NaN'
        speed10MWT = 10 / mean(times_10MWT);    % compute fast OG speed
    end
end

end

