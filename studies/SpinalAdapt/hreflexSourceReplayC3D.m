function trial = hreflexSourceReplayC3D(c3dPath,options)
%HREFLEXSOURCEREPLAYC3D Load a prior H-reflex trial C3D for monitor
%replay.
%
%   Loads the stimulator trigger, proximal TA, and H-reflex muscle EMG
%   analog channels from a previously collected C3D file the same way
%   GENERATEHREFLEXRECRUITMENTCURVES does (via BTK), and returns them
%   as plain arrays for both legs. This is a batch loader only -- it
%   does not simulate streaming cadence; RUNHREFLEXMWAVEMONITOR (or a
%   test) slices the returned arrays into chunks to replay the trial
%   through the same online pipeline used live.
%
%   The BTK-independent channel-mapping logic (EMG sensor number ->
%   muscle label, matching GENERATEHREFLEXRECRUITMENTCURVES' own
%   field-name parse) lives in MAPHREFLEXANALOGCHANNELS, so it can be
%   unit-tested without BTK or a real C3D file.
%
% Inputs:
%   c3dPath - char; full path to a previously collected H-reflex C3D
%             file (e.g. a SpinalAdapt walking calibration trial)
%
% Optional Name-Value Inputs:
%   muscle - char; H-reflex muscle label suffix: 'SOL', 'MG', or 'LG'.
%            Default '' prompts the experimenter (PROMPTHREFLEXMUSCLE,
%            defaulting to 'SOL' there); pass an explicit value to skip
%            the prompt (e.g. for automated tests).
%   emgSensorMap - char; space-separated muscle labels in EMG sensor
%            order (position k = sensor 'EMG<k>'), matching
%            GENERATEHREFLEXRECRUITMENTCURVES' own experimenter-entered
%            format. Default matches that script's own default 16-
%            sensor layout.
%
% Outputs:
%   trial - struct with fields:
%             period - EMG sampling period (s)
%             times  - numSamples x 1 array of time (s) from trial
%                      start
%             trigR, trigL - numSamples x 1 stimulator trigger channels
%             tapR, tapL   - numSamples x 1 proximal TA EMG channels
%             hR, hL       - numSamples x 1 H-reflex muscle EMG
%                            channels (the muscle selected above)
%             muscle       - the muscle label used (echoed back)
%
% Toolbox Dependencies:
%   None (external: BTK -- btkReadAcquisition, btkGetAnalogs)
%
% See also RUNHREFLEXMWAVEMONITOR, STEPHREFLEXMONITOR,
%   PROMPTHREFLEXMUSCLE, MAPHREFLEXANALOGCHANNELS,
%   GENERATEHREFLEXRECRUITMENTCURVES.

arguments
    c3dPath (1,:) char {mustBeFile}
    options.muscle (1,:) char = ''
    options.emgSensorMap (1,:) char = ['RTAP RTAD NA RPER RMG RLG ' ...
        'RSOL LTAP LTAD LPER LMG LLG LSOL NA NA sync1']
end

if isempty(options.muscle)
    muscle = promptHreflexMuscle();
elseif ismember(options.muscle,{'SOL','MG','LG'})
    muscle = options.muscle;
else
    error('hreflexSourceReplayC3D:invalidMuscle', ...
        'muscle must be ''SOL'', ''MG'', or ''LG'' (got ''%s'').', ...
        options.muscle);
end

H = btkReadAcquisition(c3dPath);
[analogs,analogsInfo] = btkGetAnalogs(H);
period = 1 / analogsInfo.frequency;

[tapR,tapL,hR,hL,trigR,trigL] = mapHreflexAnalogChannels( ...
    analogs,options.emgSensorMap,muscle);

if any(cellfun(@isempty,{tapR,tapL,hR,hL,trigR,trigL}))
    error('hreflexSourceReplayC3D:missingChannel', ...
        'Missing one or more required analog channels in %s.',c3dPath);
end

numSamps = numel(tapR);
trial.period = period;
trial.times  = (0:numSamps - 1)' * period;
trial.trigR  = trigR;
trial.trigL  = trigL;
trial.tapR   = tapR;
trial.tapL   = tapL;
trial.hR     = hR;
trial.hL     = hL;
trial.muscle = muscle;

end
