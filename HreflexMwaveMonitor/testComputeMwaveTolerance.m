function tests = testComputeMwaveTolerance()
%TESTCOMPUTEMWAVETOLERANCE Unit tests for the +-10% M-wave tolerance
%band computation.
%
%   Run with: runtests('testComputeMwaveTolerance').
%
% Inputs:
%   None
%
% Outputs:
%   tests - test array produced by FUNCTIONTESTS
%
% Toolbox Dependencies:
%   None
%
% See also COMPUTEMWAVETOLERANCE.

tests = functiontests(localfunctions);

end

function testDefaultTenPercentBounds(testCase)
%TESTDEFAULTTENPERCENTBOUNDS Default tolerance is +-10% of baseline.
bounds = hreflexMonitor.computeMwaveTolerance(2.0);
verifyEqual(testCase,bounds,[1.8 2.2],'AbsTol',1e-10);

end

function testCustomToleranceFraction(testCase)
%TESTCUSTOMTOLERANCEFRACTION A non-default toleranceFraction scales
%the bounds accordingly.
bounds = hreflexMonitor.computeMwaveTolerance(2.0,[], ...
    'toleranceFraction',0.20);
verifyEqual(testCase,bounds,[1.6 2.4],'AbsTol',1e-10);

end

function testIsWithinTolFlagsEachAmplitude(testCase)
%TESTISWITHINTOLFLAGSEACHAMPLITUDE In/out-of-tolerance amplitudes are
%flagged correctly, including the inclusive boundary.
[~,isWithinTol] = hreflexMonitor.computeMwaveTolerance( ...
    2.0,[1.79 1.8 2.0 2.2 2.21]');
verifyEqual(testCase,isWithinTol,[false true true true false]');

end

function testEmptyMwaveReturnsEmptyFlags(testCase)
%TESTEMPTYMWAVERETURNSEMPTYFLAGS Bounds-only call (mwaveMv omitted)
%returns an empty flag array rather than erroring.
[bounds,isWithinTol] = hreflexMonitor.computeMwaveTolerance(2.0);
verifyEqual(testCase,bounds,[1.8 2.2],'AbsTol',1e-10);
verifyEqual(testCase,isWithinTol,zeros(0,0,'logical'));

end
