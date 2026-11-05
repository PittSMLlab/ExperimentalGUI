function tests = testAssembleLiveChunk()
%TESTASSEMBLELIVECHUNK Unit tests for live frame-to-chunk assembly.
%
%   Run with: runtests('testAssembleLiveChunk'). Needs no Vicon or BTK.
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
% See also ASSEMBLELIVECHUNK.

tests = functiontests(localfunctions);

end

function testConsecutiveFramesAreContiguous(testCase)
%TESTCONSECUTIVEFRAMESARECONTIGUOUS Times continue across frames, with no
%padding and no lost frames counted.
[st, chunk1] = hreflexMonitor.assembleLiveChunk([], 100, ones(20, 1), ...
    2 * ones(20, 1), 3 * ones(10, 1), 0.0005);
[st, chunk2] = hreflexMonitor.assembleLiveChunk(st, 101, ones(20, 1), ...
    2 * ones(20, 1), 3 * ones(10, 1), 0.0005);

verifyEqual(testCase, numel(chunk1.times), 20);
verifyEqual(testCase, chunk1.times(1), 0, 'AbsTol', 1e-12);
verifyEqual(testCase, chunk2.times(1), 20 * 0.0005, 'AbsTol', 1e-12);
verifyEqual(testCase, st.numLostFrames, 0);
verifyFalse(testCase, any(isnan(chunk2.tap)));

end

function testLostFramesArePaddedWithNaN(testCase)
%TESTLOSTFRAMESAREPADDEDWITHNAN Skipped frame numbers become NaN samples,
%so later samples keep their true positions.
[st, ~] = hreflexMonitor.assembleLiveChunk([], 100, ones(20, 1), ...
    ones(20, 1), ones(10, 1), 0.0005);
[st, chunk] = hreflexMonitor.assembleLiveChunk(st, 103, 5 * ones(20, 1), ...
    6 * ones(20, 1), 7 * ones(10, 1), 0.0005);

verifyEqual(testCase, st.numLostFrames, 2);
verifyEqual(testCase, numel(chunk.tap), 60);
verifyTrue(testCase, all(isnan(chunk.tap(1:40))));
verifyTrue(testCase, all(isnan(chunk.h(1:40))));
verifyTrue(testCase, all(isnan(chunk.trig(1:40))));
verifyEqual(testCase, chunk.tap(41:60), 5 * ones(20, 1));
verifyEqual(testCase, chunk.h(41:60), 6 * ones(20, 1));
verifyEqual(testCase, chunk.times(41), 60 * 0.0005, 'AbsTol', 1e-12);

end

function testTriggerIsRepeatedToEmgLength(testCase)
%TESTTRIGGERISREPEATEDTOEMGLENGTH A single trigger value per frame, as
%read live, and a 10-subsample trigger both fill the EMG length in order.
[~, chunkOne] = hreflexMonitor.assembleLiveChunk([], 1, ones(20, 1), ...
    ones(20, 1), 4.3, 0.0005);
verifyEqual(testCase, chunkOne.trig, 4.3 * ones(20, 1));

[~, chunkTen] = hreflexMonitor.assembleLiveChunk([], 1, ones(20, 1), ...
    ones(20, 1), (1:10)', 0.0005);
verifyEqual(testCase, chunkTen.trig, repelem((1:10)', 2));

end

function testRepeatedFrameAddsNothing(testCase)
%TESTREPEATEDFRAMEADDSNOTHING A frame delivered twice yields an empty
%chunk and is counted, not treated as new data.
[st, ~] = hreflexMonitor.assembleLiveChunk([], 7, ones(20, 1), ...
    ones(20, 1), 1, 0.0005);
[st, chunk] = hreflexMonitor.assembleLiveChunk(st, 7, ones(20, 1), ...
    ones(20, 1), 1, 0.0005);

verifyEmpty(testCase, chunk.times);
verifyEqual(testCase, st.numRepeatedFrames, 1);
verifyEqual(testCase, st.numSamples, 20);

end

function testBackwardFrameNumberIsARestart(testCase)
%TESTBACKWARDFRAMENUMBERISARESTART Frame numbers moving backward are
%counted as a restart, and data keeps flowing with no padding.
[st, ~] = hreflexMonitor.assembleLiveChunk([], 5000, ones(20, 1), ...
    ones(20, 1), 1, 0.0005);
[st, chunk] = hreflexMonitor.assembleLiveChunk(st, 10, ones(20, 1), ...
    ones(20, 1), 1, 0.0005);

verifyEqual(testCase, st.numRestarts, 1);
verifyEqual(testCase, numel(chunk.tap), 20);
verifyEqual(testCase, st.numLostFrames, 0);

end

function testLongStallPaddingIsCapped(testCase)
%TESTLONGSTALLPADDINGISCAPPED A huge frame jump is fully counted as lost,
%but pads at most the capped number of frames.
[st, ~] = hreflexMonitor.assembleLiveChunk([], 1, ones(20, 1), ...
    ones(20, 1), 1, 0.0005);
[st, chunk] = hreflexMonitor.assembleLiveChunk(st, 100002, ones(20, 1), ...
    ones(20, 1), 1, 0.0005);

verifyEqual(testCase, st.numLostFrames, 100000);
verifyEqual(testCase, numel(chunk.tap), (1000 + 1) * 20);

end
