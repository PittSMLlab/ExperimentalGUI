function tests = testComputeMwaveAlert()
%TESTCOMPUTEMWAVEALERT Unit tests for the consecutive out-of-window rule.
%
%   Run with: runtests('testComputeMwaveAlert').
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
% See also COMPUTEMWAVEALERT.

tests = functiontests(localfunctions);

end

function testTwoOutDoesNotAlert(testCase)
%TESTTWOOUTDOESNOTALERT Two in a row counts but does not alert.
alert = hreflexMonitor.computeMwaveAlert([2.0; 1.0; 1.0], [1.8 2.2]);
verifyEqual(testCase, alert.numConsecutive, 2);
verifyFalse(testCase, alert.isAlert);
verifyEqual(testCase, alert.direction, 'LOW');

end

function testThreeOutAlerts(testCase)
%TESTTHREEOUTALERTS The third out-of-window stimulus raises the alert.
alert = hreflexMonitor.computeMwaveAlert([2.0; 3; 3; 3], [1.8 2.2]);
verifyEqual(testCase, alert.numConsecutive, 3);
verifyTrue(testCase, alert.isAlert);
verifyEqual(testCase, alert.direction, 'HIGH');

end

function testInWindowStimulusResetsTheCount(testCase)
%TESTINWINDOWSTIMULUSRESETSTHECOUNT An in-window stimulus clears the run,
%and non-consecutive out-of-window stimuli never alert.
alert = hreflexMonitor.computeMwaveAlert([3; 3; 2.0; 3; 2.0], [1.8 2.2]);
verifyEqual(testCase, alert.numConsecutive, 0);
verifyFalse(testCase, alert.isAlert);
verifyEmpty(testCase, alert.direction);

end

function testBoundsAreInsideTheWindow(testCase)
%TESTBOUNDSAREINSIDETHEWINDOW Matches COMPUTEMWAVETOLERANCE: values on
%the bounds are within the window.
alert = hreflexMonitor.computeMwaveAlert([1.8; 2.2], [1.8 2.2]);
verifyEqual(testCase, alert.numConsecutive, 0);

end

function testMixedDirectionStillAlerts(testCase)
%TESTMIXEDDIRECTIONSTILLALERTS Both sides of the window count toward the
%rule, reported as MIXED because no single current change would fix it.
alert = hreflexMonitor.computeMwaveAlert([3; 1; 3], [1.8 2.2]);
verifyTrue(testCase, alert.isAlert);
verifyEqual(testCase, alert.direction, 'MIXED');

end

function testAllOutCountsFromTheFirstStimulus(testCase)
%TESTALLOUTCOUNTSFROMTHEFIRSTSTIMULUS With no in-window stimulus yet, the
%run starts at the first stimulus.
alert = hreflexMonitor.computeMwaveAlert([1; 1; 1; 1], [1.8 2.2]);
verifyEqual(testCase, alert.numConsecutive, 4);

end

function testCustomRequirement(testCase)
%TESTCUSTOMREQUIREMENT NUMREQUIRED changes the alert threshold.
alert = hreflexMonitor.computeMwaveAlert([1; 1], [1.8 2.2], ...
    'numRequired', 2);
verifyTrue(testCase, alert.isAlert);

end

function testEmptyInput(testCase)
%TESTEMPTYINPUT No stimuli yet means no alert.
alert = hreflexMonitor.computeMwaveAlert(zeros(0, 1), [1.8 2.2]);
verifyEqual(testCase, alert.numConsecutive, 0);
verifyFalse(testCase, alert.isAlert);

end
