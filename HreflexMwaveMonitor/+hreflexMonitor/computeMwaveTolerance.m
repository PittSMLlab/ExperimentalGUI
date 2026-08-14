function [bounds,isWithinTol] = computeMwaveTolerance( ...
    baselineMwaveMv,mwaveMv,options)
%COMPUTEMWAVETOLERANCE M-wave tolerance bounds around a baseline value.
%
%   Computes the +-10% (default) tolerance bounds around a per-leg
%   baseline M-wave amplitude, and whether given M-wave amplitude(s)
%   fall within those bounds. Pure arithmetic -- no plotting, no
%   prompting -- so RUNHREFLEXMWAVEMONITOR and its tests can share the
%   same tolerance definition.
%
% Inputs:
%   baselineMwaveMv - scalar; per-leg baseline M-wave amplitude (mV),
%                     from PROMPTHREFLEXBASELINE or a test fixture
%   mwaveMv         - array of M-wave amplitudes (mV) to check against
%                     the bounds; [] to compute bounds only
%
% Optional Name-Value Inputs:
%   toleranceFraction - scalar in (0,1); half-width of the tolerance
%                        band as a fraction of baseline (default: 0.10,
%                        i.e. +-10%)
%
% Outputs:
%   bounds      - 1x2 array [lowerBound upperBound], mV
%   isWithinTol - logical array, same size as mwaveMv; true where
%                 within [lowerBound, upperBound] inclusive
%
% Toolbox Dependencies:
%   None
%
% See also PROMPTHREFLEXBASELINE, RUNHREFLEXMWAVEMONITOR.

arguments
    baselineMwaveMv (1,1) double {mustBePositive}
    mwaveMv double = []
    options.toleranceFraction (1,1) double ...
        {mustBePositive,mustBeLessThan(options.toleranceFraction,1)} = 0.10
end

bounds = baselineMwaveMv * [1 - options.toleranceFraction, ...
    1 + options.toleranceFraction];
isWithinTol = mwaveMv >= bounds(1) & mwaveMv <= bounds(2);

end
