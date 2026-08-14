function baselineMwaveMv = promptHreflexBaseline(leg)
%PROMPTHREFLEXBASELINE Prompt for a leg's baseline M-wave amplitude.
%
%   Asks the experimenter to type in the per-leg baseline M-wave
%   amplitude (mV) from that leg's walking calibration recruitment
%   curve (HREFLEX.FITCAL / GENERATEHREFLEXRECRUITMENTCURVES), since no
%   baseline is currently persisted by that pipeline for this tool to
%   load automatically (see the study README's flagged upstream
%   labTools item). RUNHREFLEXMWAVEMONITOR uses this value as the
%   center of the +-10% tolerance band (COMPUTEMWAVETOLERANCE).
%
% Inputs:
%   leg - char; 'R' or 'L' -- which leg the prompt is for (display only)
%
% Outputs:
%   baselineMwaveMv - scalar; experimenter-entered baseline M-wave
%                     amplitude (mV)
%
% Toolbox Dependencies:
%   None
%
% See also COMPUTEMWAVETOLERANCE, RUNHREFLEXMWAVEMONITOR.

arguments
    leg (1,1) char {mustBeMember(leg,{'R','L'})}
end

promptStr = sprintf(['Enter the %s leg''s baseline M-wave ' ...
    'amplitude (mV), from that leg''s walking calibration ' ...
    'recruitment curve:'],leg);
answer = inputdlg(promptStr,'H-Reflex Baseline M-Wave',[1 60]);
if isempty(answer)
    error('promptHreflexBaseline:noSelection', ...
        'A baseline M-wave amplitude is required.');
end
baselineMwaveMv = str2double(answer{1});
if isnan(baselineMwaveMv) || baselineMwaveMv <= 0
    error('promptHreflexBaseline:invalidValue', ...
        'Baseline M-wave amplitude must be a positive number.');
end

end
