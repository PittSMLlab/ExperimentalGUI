function trial = generateSyntheticHreflexTrial(options)
%GENERATESYNTHETICHREFLEXTRIAL Build a synthetic H-reflex trial fixture
%for hardware-free unit/parity testing.
%
%   Produces a TRIAL struct in the same shape HREFLEXSOURCEREPLAYC3D
%   returns (period, times, trigR/L, tapR/L, hR/L, muscle), plus
%   ground-truth onset times, WITHOUT requiring BTK or a real C3D file.
%   Used by TESTDETECTSTIMARTIFACTONLINE and
%   TESTHREFLEXMWAVEMONITORREPLAY so the online-vs-offline parity
%   checks always run in CI, independent of lab hardware or server file
%   access.
%
%   One stimulus (the 3rd, on each leg) is given a wider M-wave bump
%   than the others purely for realistic across-stimulus waveform
%   variability. NOTE: this bump-shape difference does NOT reliably
%   engage HREFLEX.COMPUTEAMPLITUDES' population-level outlier-duration
%   correction (verified empirically -- window truncation and
%   background noise dominate the in-window peak/trough placement more
%   than the intended width difference). TESTGROWINGSETOUTLIERCORRECTION
%   MATTERSRIGHTLEG in TESTHREFLEXMWAVEMONITORREPLAY separately builds a
%   hand-crafted signal with an unambiguous, verified-to-trigger outlier
%   duration, specifically to demonstrate that STEPHREFLEXMONITOR's
%   growing-set recompute (vs. a per-stimulus, N=1 computation) is
%   load-bearing.
%
% Inputs:
%   None
%
% Optional Name-Value Inputs:
%   numStim  - stimuli per leg (default: 5)
%   duration - trial duration, s (default: 3.0)
%
% Outputs:
%   trial - struct; see HREFLEXSOURCEREPLAYC3D for field definitions,
%           plus onsetTimesR/onsetTimesL (ground-truth onset times, s)
%
% Toolbox Dependencies:
%   None
%
% See also HREFLEXSOURCEREPLAYC3D, TESTDETECTSTIMARTIFACTONLINE,
%   TESTHREFLEXMWAVEMONITORREPLAY.

arguments
    options.numStim  (1,1) double {mustBePositive,mustBeInteger} = 5
    options.duration (1,1) double {mustBePositive} = 3.0
end

period = 0.0005;   % 2 kHz, matches labTools' +Hreflex assumption
times  = (0:period:options.duration)';

rng(42);   % reproducible synthetic noise across test runs
[trigR,tapR,hR,onsetTimesR] = buildLegSignal( ...
    times,options.numStim,0.5);
[trigL,tapL,hL,onsetTimesL] = buildLegSignal( ...
    times,options.numStim,0.6);

trial.period      = period;
trial.times       = times;
trial.trigR       = trigR;
trial.trigL       = trigL;
trial.tapR        = tapR;
trial.tapL        = tapL;
trial.hR          = hR;
trial.hL          = hL;
trial.muscle      = 'SOL';
trial.onsetTimesR = onsetTimesR;
trial.onsetTimesL = onsetTimesL;

end

%% Local Functions

function [trig,tap,hMuscle,onsetTimes] = buildLegSignal( ...
    times,numStim,firstOnset)
%BUILDLEGSIGNAL Synthesize one leg's trigger, TAP, and H-muscle signal.
%
% Inputs:
%   times      - numSamples x 1 array of sample times (s)
%   numStim    - number of stimuli to synthesize
%   firstOnset - onset time of the first stimulus (s)
%
% Outputs:
%   trig       - numSamples x 1 stimulator trigger signal (V)
%   tap        - numSamples x 1 proximal TA EMG signal (V)
%   hMuscle    - numSamples x 1 H-reflex muscle EMG signal (V)
%   onsetTimes - numStim x 1 ground-truth stim onset times (s)
%
% Toolbox Dependencies:
%   None

stimSpacing = 0.5;   % s between stimuli
onsetTimes  = firstOnset + (0:numStim - 1)' * stimSpacing;

pulseDur      = 0.02;      % s; trigger pulse duration
artifactDelay = 0.003;     % s; onset -> TAP artifact peak
artifactWidth = 0.002;     % s; TAP artifact bump half-width
mWaveDelay    = 0.010;     % s; onset -> M-wave bump center (within
% HREFLEX.COMPUTEAMPLITUDES' 4.5-20 ms M-wave window)
mWaveWidthNormal = 0.0015; % s; typical M-wave bump half-width
mWaveWidthWide   = 0.004;  % s; deliberately wider (3rd stim; see header)
hWaveDelay = 0.035;        % s; onset -> H-wave bump center (within the
% 25-45 ms H-wave window)
hWaveWidth = 0.002;        % s; H-wave bump half-width

trig    = zeros(size(times));
tap     = 1e-4 * randn(size(times));
hMuscle = 1e-4 * randn(size(times));

for st = 1:numStim
    onset = onsetTimes(st);
    trig(times >= onset & times < onset + pulseDur) = 5;
    tap = tap + dGaussBump(times,onset + artifactDelay, ...
        artifactWidth,0.01);

    if st == 3   % deliberately wide M-wave; see header note
        mWaveWidth = mWaveWidthWide;
    else
        mWaveWidth = mWaveWidthNormal;
    end
    hMuscle = hMuscle + dGaussBump(times,onset + mWaveDelay, ...
        mWaveWidth,5e-4);
    hMuscle = hMuscle + dGaussBump(times,onset + hWaveDelay, ...
        hWaveWidth,3e-4);
end

end

function bump = dGaussBump(times,center,halfWidth,amp)
%DGAUSSBUMP Biphasic (derivative-of-Gaussian) synthetic EMG bump.
%
%   A smooth, deterministic peak-then-trough (or vice versa) shape
%   centered at CENTER, used to synthesize artifact/M-wave/H-wave-like
%   deflections with a clean peak-to-peak amplitude.
%
% Inputs:
%   times     - numSamples x 1 array of sample times (s)
%   center    - bump center time (s)
%   halfWidth - bump half-width (s)
%   amp       - bump amplitude scale (V)
%
% Outputs:
%   bump - numSamples x 1 array
%
% Toolbox Dependencies:
%   None

bump = amp * ((times - center) / halfWidth) .* ...
    exp(-((times - center).^2) / (2 * halfWidth^2));

end
