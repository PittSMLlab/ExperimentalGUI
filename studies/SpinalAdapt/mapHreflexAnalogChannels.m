function [tapR,tapL,hR,hL,trigR,trigL] = mapHreflexAnalogChannels( ...
    analogs,emgSensorMap,muscle)
%MAPHREFLEXANALOGCHANNELS Map raw BTK analog channels to the H-reflex
%TAP/H-muscle/trigger channels needed by the monitor.
%
%   Resolves EMG channels by SENSOR NUMBER (fields named 'EMG<n>' in
%   the analogs struct, matching GENERATEHREFLEXRECRUITMENTCURVES' own
%   field-name parse) via an experimenter-supplied sensor-to-muscle
%   mapping, and resolves the two stimulator trigger channels by their
%   descriptive field names. Factored out of HREFLEXSOURCEREPLAYC3D so
%   this mapping logic -- the exact code an earlier version of this
%   tool got wrong (treating muscle labels like 'RSOL' as literal
%   analog field names, which they never are) -- can be unit-tested
%   without BTK or a real C3D file (see TESTMAPHREFLEXANALOGCHANNELS).
%
% Inputs:
%   analogs      - struct as returned by btkGetAnalogs (or a hand-built
%                  struct with the same field-naming conventions, for
%                  testing)
%   emgSensorMap - char; space-separated muscle labels in EMG sensor
%                  order (position k = sensor 'EMG<k>')
%   muscle       - char; 'SOL', 'MG', or 'LG' -- which muscle to use as
%                  the H-reflex channel
%
% Outputs:
%   tapR, tapL   - numSamples x 1 proximal TA EMG channels, or [] if
%                  not found
%   hR, hL       - numSamples x 1 H-reflex muscle EMG channels, or []
%   trigR, trigL - numSamples x 1 stimulator trigger channels, or []
%
% Toolbox Dependencies:
%   None
%
% See also HREFLEXSOURCEREPLAYC3D, TESTMAPHREFLEXANALOGCHANNELS.

arguments
    analogs      (1,1) struct
    emgSensorMap (1,:) char
    muscle       (1,:) char {mustBeMember(muscle,{'SOL','MG','LG'})}
end

%% Map EMG Sensor Numbers to Analog Field Names
fieldNames = fields(analogs);
emgFieldBySensor = containers.Map('KeyType','double','ValueType','char');
for ii = 1:numel(fieldNames)
    idx = strfind(fieldNames{ii},'EMG');
    if isempty(idx)
        continue;
    end
    sensorNum = str2double(fieldNames{ii}(idx(1) + 3:end));
    if ~isnan(sensorNum)
        emgFieldBySensor(sensorNum) = fieldNames{ii};
    end
end
sensorLabels = strsplit(emgSensorMap,' ');

%% Locate the EMG and Trigger Channels by Muscle Label
tapR = lookupEmgChannel(analogs,emgFieldBySensor,sensorLabels,'RTAP');
tapL = lookupEmgChannel(analogs,emgFieldBySensor,sensorLabels,'LTAP');
hR   = lookupEmgChannel(analogs,emgFieldBySensor,sensorLabels, ...
    ['R' muscle]);
hL   = lookupEmgChannel(analogs,emgFieldBySensor,sensorLabels, ...
    ['L' muscle]);
trigR = getAnalogChannel(analogs,fieldNames, ...
    'Stimulator_Trigger_Sync_Right_Stimulator');
% NOTE: double underscore before "Stimulator" matches the C3D export's
% actual field name (same quirk GENERATEHREFLEXRECRUITMENTCURVES
% relies on for the left channel)
trigL = getAnalogChannel(analogs,fieldNames, ...
    'Stimulator_Trigger_Sync_Left__Stimulator');

end

%% Local Functions

function data = lookupEmgChannel(analogs,emgFieldBySensor, ...
    sensorLabels,label)
%LOOKUPEMGCHANNEL Retrieve one EMG analog channel by muscle label, via
%the sensor-number-to-muscle mapping.
%
% Inputs:
%   analogs          - struct as returned by btkGetAnalogs
%   emgFieldBySensor - containers.Map, sensor number -> analog field
%                      name (see the sensor-number parse above)
%   sensorLabels     - cell array; sensorLabels{k} is the muscle label
%                      for EMG sensor k (position = sensor number)
%   label            - muscle label to look up (e.g. 'RTAP', 'RSOL')
%
% Outputs:
%   data - numSamples x 1 array, or [] if the label or its sensor's
%          analog field is not present
%
% Toolbox Dependencies:
%   None

sensorNum = find(strcmpi(sensorLabels,label),1,'first');
if isempty(sensorNum) || ~isKey(emgFieldBySensor,sensorNum)
    data = [];
    return;
end
data = analogs.(emgFieldBySensor(sensorNum));

end

function data = getAnalogChannel(analogs,fieldNames,name)
%GETANALOGCHANNEL Retrieve one analog channel by exact field name.
%
% Inputs:
%   analogs    - struct as returned by btkGetAnalogs
%   fieldNames - fields(analogs), passed in to avoid recomputing
%   name       - exact analog field name to retrieve
%
% Outputs:
%   data - numSamples x 1 array, or [] if the field is not present
%
% Toolbox Dependencies:
%   None

if any(strcmp(fieldNames,name))
    data = analogs.(name);
else
    data = [];
end

end
