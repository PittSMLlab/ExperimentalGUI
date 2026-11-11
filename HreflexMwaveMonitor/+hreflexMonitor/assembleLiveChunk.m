function [sourceState, chunk] = assembleLiveChunk(sourceState, ...
    frameNum, tapNew, hNew, trigNew, period)
%ASSEMBLELIVECHUNK Turn one live Vicon frame into a contiguous data chunk.
%
%   STEPHREFLEXMONITOR needs contiguous samples, so each frame number
% skipped since the previous frame is filled with NaN: a stimulus touching
% a lost frame is then marked invalid instead of being computed from
% shifted samples. The 1 kHz trigger is also repeated to the 2 kHz EMG
% length, as the C3D export does. It only anchors the artifact search
% window, so its coarser timing does not affect the amplitudes.
%
%   Pure logic, with no SDK calls, so TESTASSEMBLELIVECHUNK can exercise
% gap handling without Vicon.
%
% Inputs:
%   sourceState - running state; pass [] on the first frame. Fields:
%                 lastFrame, numSamples (samples emitted so far),
%                 numLostFrames, numRepeatedFrames, numRestarts
%   frameNum    - Vicon frame number of this frame
%   tapNew      - numEmg x 1 proximal TA EMG subsamples (V)
%   hNew        - numEmg x 1 H-reflex muscle EMG subsamples (V)
%   trigNew     - numTrig x 1 stimulator trigger subsamples (V)
%   period      - EMG sampling period (s)
%
% Outputs:
%   sourceState - updated running state
%   chunk       - struct with times, trig, tap, h column arrays of equal
%                 length, for STEPHREFLEXMONITOR; empty arrays if the
%                 frame was a repeat
%
% Toolbox Dependencies:
%   None
%
% See also HREFLEXSOURCEDATASTREAM, RUNHREFLEXMWAVEMONITORLIVE,
%   STEPHREFLEXMONITOR.

arguments
    sourceState
    frameNum (1,1) double
    tapNew   (:,1) double
    hNew     (:,1) double
    trigNew  (:,1) double
    period   (1,1) double {mustBePositive}
end

maxPadFrames = 1000;   % frames; 10 s at 100 Hz. Bounds the memory used by
                       % a long stall, which no stimulus can survive anyway

if isempty(sourceState)
    sourceState = struct('lastFrame', frameNum - 1, 'numSamples', 0, ...
        'numLostFrames', 0, 'numRepeatedFrames', 0, 'numRestarts', 0);
end

chunk = struct('times', zeros(0, 1), 'trig', zeros(0, 1), ...
    'tap', zeros(0, 1), 'h', zeros(0, 1));

%% Classify This Frame Against the Previous One
numMissing = frameNum - sourceState.lastFrame - 1;
if numMissing == -1             % same frame delivered twice
    sourceState.numRepeatedFrames = sourceState.numRepeatedFrames + 1;
    return;
elseif numMissing < -1          % frame numbers went backward: new capture
    sourceState.numRestarts = sourceState.numRestarts + 1;
    numMissing = 0;
end
sourceState.numLostFrames = sourceState.numLostFrames + numMissing;
sourceState.lastFrame = frameNum;

%% Build the Chunk, Padding Lost Frames With NaN
numEmg = numel(tapNew);
indsTrig = ceil((1:numEmg)' * numel(trigNew) / numEmg);
numPad = min(numMissing, maxPadFrames) * numEmg;
pad = nan(numPad, 1);

chunk.tap  = [pad; tapNew];
chunk.h    = [pad; hNew];
chunk.trig = [pad; trigNew(indsTrig)];
numNew = numel(chunk.tap);
chunk.times = (sourceState.numSamples + (0:numNew - 1)') * period;
sourceState.numSamples = sourceState.numSamples + numNew;

end
