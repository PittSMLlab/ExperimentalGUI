function datlog = nirsEvent(eventAudioKey, eventIdNirs, eventDisplayString, instructions, datlog, Oxysoft, nirsPresent)
%NIRSEVENT Log an fNIRS event marker and play its audio cue.
%
%   Plays the audio cue keyed by eventAudioKey (if one is mapped in
%   instructions), logs the event's display string and timing to
%   datlog.audioCues, and, if fNIRS is present, sends the event to
%   Oxysoft via WriteEvent.
%
% Inputs:
%   eventAudioKey - internal string used to look up the audio cue in
%       instructions, or empty if no audio should play for this event
%       (e.g., trial end)
%   eventIdNirs - single-letter event ID used to log the event in Oxysoft
%   eventDisplayString - display string printed and logged to NIRS
%       (starts with the same letter as eventIdNirs)
%   instructions - containers.Map of audioplayer objects, keyed by audio
%       key string
%   datlog - the data log struct; used to track event start time
%   Oxysoft - the Oxysoft object, used to remote-connect and log events
%   nirsPresent - true if testing with the Oxysoft instrument present
%       and connected
%
% Outputs:
%   datlog - the data log struct, updated with this event's audio cue
%       timing and display string
%
% Toolbox Dependencies:
%   None
%
% See also NIRSHREFLEXARDUINOOPENLOOPWITHAUDIO, PARSEEVENTSFROMSPEEDS.

%     disp(eventDisplayString)
%     clock
    
    %         fopen(ss);fclose(ss);
    %if the event doesn't need audio instruction, will skip playing and
    %simply send the event to NIRS.
    if (isKey(instructions, eventAudioKey))
        play(instructions(eventAudioKey));
    end
    %some event might happen without audio cue but log the timing and
    %display anyway.
    datlog.audioCues.start(end+1)=now;
    datlog.audioCues.audio_instruction_message{end+1} = eventDisplayString;

    if nirsPresent
        Oxysoft.WriteEvent(eventIdNirs,eventDisplayString) %FIXME: uncomment        
    end
end