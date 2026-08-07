function tests = testParseStimEcho()
%TESTPARSESTIMECHO Unit tests for PARSESTIMECHO and the online %SS math.
%
%   Hardware-free validation of the H-reflex device stim-echo pipeline:
%   parses synthetic Arduino byte streams (including a record split across
%   two serial reads and interleaved foreign lines) and checks the
%   single-stance percentage computed by the controller from each record.
%   Run with: runtests('testParseStimEcho').
%
% Inputs:
%   None
%
% Outputs:
%   tests - test array produced by FUNCTIONTESTS
%
% Toolbox Dependencies: None
%
% See also PARSESTIMECHO, NIRSHREFLEXARDUINOOPENLOOPWITHAUDIO.

tests = functiontests(localfunctions);

end

function testSingleLeftRecord(testCase)
%TESTSINGLELEFTRECORD A lone CRLF-terminated left record parses cleanly.
[bufOut,recs] = parseStimEcho(sprintf('S,L,5,12345,12150,398.2\r\n'));
verifyEmpty(testCase,bufOut);
verifyEqual(testCase,recs,[1 5 12345 12150 398.2 1],'AbsTol',1e-6);

end

function testSingleRightRecord(testCase)
%TESTSINGLERIGHTRECORD A lone right record maps to leg code 2.
[~,recs] = parseStimEcho(sprintf('S,R,6,20000,19800,401.0\r\n'));
verifyEqual(testCase,recs,[2 6 20000 19800 401.0 1],'AbsTol',1e-6);

end

function testTwoRecordsOneBuffer(testCase)
%TESTTWORECORDSONEBUFFER Two records in one read return two rows.
[bufOut,recs] = parseStimEcho(sprintf( ...
    'S,L,5,12345,12150,398.2\r\nS,R,6,20000,19800,401.0\r\n'));
verifyEmpty(testCase,bufOut);
verifyEqual(testCase,size(recs,1),2);
verifyEqual(testCase,recs(2,:),[2 6 20000 19800 401.0 1],'AbsTol',1e-6);

end

function testRecordSplitAcrossReads(testCase)
%TESTRECORDSPLITACROSSREADS A record split mid-line is reassembled via
%the carried-over buffer, exercising the partial-line path.
[buf1,recs1] = parseStimEcho('S,L,5,12345,121');
verifyEqual(testCase,recs1,zeros(0,6));   % nothing complete yet
verifyEqual(testCase,buf1,'S,L,5,12345,121');

[buf2,recs2] = parseStimEcho([buf1 sprintf('50,398.2\r\n')]);
verifyEmpty(testCase,buf2);
verifyEqual(testCase,recs2,[1 5 12345 12150 398.2 1],'AbsTol',1e-6);

end

function testForeignAndMalformedLinesIgnored(testCase)
%TESTFOREIGNANDMALFORMEDLINESIGNORED Non-echo lines (e.g., the disabled
%force CSV) and malformed records are dropped, valid ones still parsed.
stream = sprintf(['12345,10,12\r\n' ...        % force CSV: wrong tag/cols
    'S,X,1,2,3,4\r\n' ...                       % bad leg field
    'S,L,bad,12345,12150,398.2\r\n' ...         % non-numeric field
    'S,R,6,20000,19800,401.0\r\n']);            % the one valid record
[bufOut,recs] = parseStimEcho(stream);
verifyEmpty(testCase,bufOut);
verifyEqual(testCase,recs,[2 6 20000 19800 401.0 1],'AbsTol',1e-6);

end

function testTrailingPartialAfterValidRecord(testCase)
%TESTTRAILINGPARTIALAFTERVALIDRECORD A complete record followed by the
%start of the next returns the record and carries the partial remainder.
[bufOut,recs] = parseStimEcho(sprintf('S,L,5,12345,12150,398.2\r\nS,R,6'));
verifyEqual(testCase,recs,[1 5 12345 12150 398.2 1],'AbsTol',1e-6);
verifyEqual(testCase,bufOut,'S,R,6');

end

function testDroppedGateRecord(testCase)
%TESTDROPPEDGATERECORD A 'D' record (gate dropped by the firmware's
%lateness or gate-expiry guard) parses with isDelivered = 0.
[bufOut,recs] = parseStimEcho(sprintf('D,L,5,12800,12150,398.2\r\n'));
verifyEmpty(testCase,bufOut);
verifyEqual(testCase,recs,[1 5 12800 12150 398.2 0],'AbsTol',1e-6);

end

function testMixedDeliveredAndDroppedRecords(testCase)
%TESTMIXEDDELIVEREDANDDROPPEDRECORDS 'S' and 'D' records interleaved in
%one buffer are each parsed with the correct isDelivered flag.
stream = sprintf(['S,L,5,12345,12150,398.2\r\n' ...
    'D,R,6,20500,19800,401.0\r\n' ...
    'S,R,7,23000,22700,401.0\r\n']);
[bufOut,recs] = parseStimEcho(stream);
verifyEmpty(testCase,bufOut);
verifyEqual(testCase,size(recs,1),3);
verifyEqual(testCase,recs(1,6),1);   % delivered
verifyEqual(testCase,recs(2,6),0);   % dropped
verifyEqual(testCase,recs(3,6),1);   % delivered

end

function testDroppedRecordSplitAcrossReads(testCase)
%TESTDROPPEDRECORDSPLITACROSSREADS A 'D' record split mid-line is
%reassembled via the carried-over buffer, same as an 'S' record.
[buf1,recs1] = parseStimEcho('D,R,6,20500,198');
verifyEqual(testCase,recs1,zeros(0,6));   % nothing complete yet
verifyEqual(testCase,buf1,'D,R,6,20500,198');

[buf2,recs2] = parseStimEcho([buf1 sprintf('00,401.0\r\n')]);
verifyEmpty(testCase,buf2);
verifyEqual(testCase,recs2,[2 6 20500 19800 401.0 0],'AbsTol',1e-6);

end

function testOnlinePctSSFromRecord(testCase)
%TESTONLINEPCTSSFROMRECORD The controller's %-single-stance formula,
%100*(stimMs-toRefMs)/durSSms, lands near 50% when the device fires at
%its target and the measured single stance matches the estimate.
[~,recs] = parseStimEcho(sprintf('S,L,5,12345,12150,398.2\r\n'));
dtStimMs = recs(1,3) - recs(1,4);   % 12345 - 12150 = 195 ms
durSSms  = 396.6;                   % normative single-stance duration (ms)
pctSS    = 100 * dtStimMs / durSSms;
verifyEqual(testCase,pctSS,49.17,'AbsTol',0.5);

end
