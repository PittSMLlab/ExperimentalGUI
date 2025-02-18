%% This script generates the random sequence to play for each n-back condition. The sequence needs to have 12 stimulus of single digit numbers from 0-9 and have 3 target among them. 
%The total time for playing the stimulus + interstimulus interval should
%add up to 30s.
%The sequence is generated to avoid 1-1-1 in a row or 1-2-3, or 3-2-1
%sequential element to make the task difficulty even and avoid extremely
%easy cases
%% 1. Check how long the audio file is, this will be used to calculate remaining time available for response windows
% C:\Users\Public\Documents\MATLAB\ExperimentalGUI\controllers\AudioInstructionsMP3/
%set up audio players
%Set up save path
scriptDir = fileparts(matlab.desktop.editor.getActiveFilename);
saveDir = ['C:\Users\Public\Documents\MATLAB\ExperimentalGUI\NirsAutomaticityProtocol' filesep 'BrainGait-n-back-stimulus' filesep];

%Optional, add audio to path
% audioPath = [scriptDir filesep 'AudioInstructionsMP3' filesep];
% addpath(audioPath)
audioids = {'walk','walk0','walk1','walk2','stand0','stand1','stand2',...
    'relax','rest','stopAndRest','0','1','2','3','4','5','6','7','8','9'};
instructions = containers.Map();
durationsSelfCalc = [];
durationsLoaded = [];
for i = 1 : length(audioids)
    [audio_data,audio_fs]=audioread(strcat(audioids{i},'.mp3'));
    instructions(audioids{i}) = audioplayer(audio_data,audio_fs);
    durationsSelfCalc(i) = length(audio_data)/audio_fs;
end
%30s, roughly 2.5 each, 

%% 2. Generate the sequence in a pseurandom fashion such the sequence is generated to match the req to begine with.
rng(2000) %set seeds for repeatability
numStimulus = 12; %12 stimulus
numTargets = 3;
trials = 8; %5 trials, each with 2 (ST, and DT), and familiarizations (3? trials x 2)
taskTypes = {'walk','stand'};
totalCondTimeMs = 30*1000; %30,000ms (30s) per condition including all the instruction times
%ms %2350-3150 from literature won'twork. If we count time played per number, a good range is 1450-2300
%if we ignore the time needed to finish playing a number, the average per number across all conditions is
%2280ms = mean((30s-each task instruction duration)/12), assume +-400s (following the range from literature
ISIMin = 1880; 
ISIMax= 2680; %max
instructionAudioBufferSec = 1; %don't play the first number right after, give a 1s buffer other wise the instruction barely finishes and the first number is already out.

for taskTp = 1:length(taskTypes) %1 is ST, 2 is DT
    for n = 0:2 %parameter of the N to generate
        condAudioKey = [taskTypes{taskTp}, num2str(n)];
        fullSequence = nan(trials, numStimulus);
        fullTargetLocs = zeros(trials, numTargets)-1; %initialize to invalid values -1, if it's nan, when do comparison, by default nan~=nan.
        fullInterStimIntervals = fullSequence;
        for rep = 1:trials
            sequenceToPlay = nan(1,numStimulus);
            targetLocs = NBackHelper.generateNewTarget(numStimulus, numTargets, n, fullTargetLocs);
            if n >=1
                %now generate 3 numbers to be used as target
                targets = randperm(10,numTargets) - 1; %3 numbers from 1:10 no repeats, subtract1 for the numbers to be in 0-9
            else %if it's 0back, target is always 0.
                targets = zeros(1,numTargets);
            end

            for targetIdx = 1:numTargets
                %place the target
                sequenceToPlay(targetLocs(targetIdx)) = targets(targetIdx);
                
                if n >= 1 %if it's 1or 2 back also place the n-back location to match the target.
                    if isnan(sequenceToPlay(targetLocs(targetIdx)-n)) %place the n-back to be the same as target, if it's not a target already
                        sequenceToPlay(targetLocs(targetIdx)-n) = targets(targetIdx);
                    else %the nth back is already a target, this means we have to change the current target to match the last one
                        %Alt. could also retro change the previous target
                        %and previous target-n to be the current, but that
                        %seems more complicated.
                        
                        %this is problematic here if the n-back location is also a
                    %target, this should happen max 2 time per sequence, so
                    %just use the same target there and we will have only 2
                    %unique target numebrs for this specific sequence.
                    
                        sequenceToPlay(targetLocs(targetIdx)) = sequenceToPlay(targetLocs(targetIdx)-n);
                        %this would happen if in 1-back target location is 4-5, or in
                        %2-back, target location is 4-6; with the current
                        %design won't have all 3 targets in a row, max repeat
                        %twice.
                    end
                end
            end
            
            actualTargets = unique(sequenceToPlay(~isnan(sequenceToPlay)));
            
            %now place random numbers in the rest of the sequence, while
            %ensuring there is no sequential numbers like  1-2-3-4 or repeating the exact same numbers like 1-1-1-1
            for i=1:numStimulus
                if isnan(sequenceToPlay(i)) %empty needs to insert
                    possibleStim = 0:9; %reset the all possible stim to be 0-9 single digits
                    if i >=2 %at least 1 number exist prior to this current location
                        prevNum = sequenceToPlay(i-1);
                        if prevNum == 0
                            numToAvoid = prevNum + [0:1]; %if prevNum = 0, would only disallow 0 and 1,
                        elseif prevNum == 9 %if it's 9, only disallow 8 and 9, no 10 present
                            numToAvoid = prevNum + [-1:0]; 
                        else
                            numToAvoid = prevNum + [-1:1]; %avoid same, or sequential up or down
                        end
                        numToAvoid = numToAvoid + 1; %the index is 1-based, so number 3 is in index 4 (0-1-2-3)
                    else %1st number, nothing to avoid.
                        numToAvoid = [];
                    end
                    
                    if n == 2 && i >=3 %if 2back, also avoid the same number 2-back ago, accidental targets.
                        numToAvoid(end+1) = sequenceToPlay(i-2) + 1; %avoid the 2-back and bump the index by 1
                    end
                    %remove numbers that are target, or the same as before
                    %or consecutive as before. (the uniont operation
                    %returns union with no repeats)
                    possibleStim(union(actualTargets+1, numToAvoid)) = []; %remove ineligible stims, use the set approach bc the numtoavoid and actualTarget all use indexing assuming we have 1-10 index corresponding to num 0-9, so leave the array manipulation to last
                    stimIdx = randi(length(possibleStim),1); %rand perm doesn't let you give a specific arraay to use, 
                    %so have to randomly generate an index to choose
                    %stimulus from the remaining eligible stimulus. At this
                    %point using randi vs randperm is the same bc i'm just
                    %choosing 1 number from 1:arg1
                    
                    sequenceToPlay(i) = possibleStim(stimIdx);
                end
            end
            
            fullSequence(rep,:) = sequenceToPlay;
            fullTargetLocs(rep,:) = targetLocs; %targetLocs is by default sorted
            
            %now set up intervals. for this condition, participant will
            %hear walk0, then 12 numbers that we randomly generated. Count
            %total times to say these numbers and instructions (right now
            %in the other matlab code, also has a pause right after
            %instructions to avoid saying the 1st number before instruction
            %finishes.
            condAudioKey
            totalAudioTime = instructions(condAudioKey).TotalSamples/instructions(condAudioKey).SampleRate + instructionAudioBufferSec;
%             for i = sequenceToPlay %assume no time spent on this, allow
%             participant to answer right away before the audio file is
%             done
%                 totalAudioTime = totalAudioTime+instructions(num2str(i)).TotalSamples/instructions(num2str(i)).SampleRate;
%             end
            %TODO: the 4s offset to wait for instruciton to finish is too
            %long, maybe try to pause for the exact amount of time...
            %longest is 2.4s
%             totalAudioTime = totalAudioTime +4; %
            
            totalTimeLeftMs = totalCondTimeMs -  totalAudioTime*1000;%30s - instruction - letter audio length
            fullInterStimIntervals(rep,:) = NBackHelper.generateISI(totalTimeLeftMs, numStimulus, ISIMin,ISIMax);
        end
        fullSequence %visually exam to avoid 1-2-3-4, or 4-3-2-1 etc.    
        fullTargetLocs  
        fullInterStimIntervals
        
        save([saveDir condAudioKey '-backSequences.mat'],'fullTargetLocs','fullSequence','fullInterStimIntervals')
    end
end

%% 3. Test the generated sequences,, make sure all sequence will be 30s and make sure the n-back is designed as planned.
clearvars -except instructions taskTypes totalCondTimeMs saveDir instructionAudioBufferSec
dataTimingInfo = []; %taskxn x trial x 3 info: totalAudio, minISI, maxISI
for taskTp = 1:length(taskTypes) %1 is ST, 2 is DT
    for n = 0:2 %parameter of the N to generate
        condAudioKey = [taskTypes{taskTp}, num2str(n)];
        load([saveDir condAudioKey '-backSequences.mat'])
        [trials,stims]=size(fullSequence);
        for t=1:trials
            targets = [];
            for stimIdx = 1:stims
                if n == 0 && fullSequence(t,stimIdx) == 0
                    targets(end+1) = stimIdx;
                elseif n == 1 && stimIdx >=2 && fullSequence(t,stimIdx-1) == fullSequence(t,stimIdx)
                    %1back, check if this is the same the one before
                    targets(end+1) = stimIdx;
                elseif n == 2 && stimIdx >=3 && fullSequence(t,stimIdx-2) == fullSequence(t,stimIdx)
                    targets(end+1) = stimIdx;
                end
            end
            %now check if the target matches what i planned
            if ~isequal(targets, fullTargetLocs(t,:))
                fprintf('Full sequence:')
                fullSequence(t,:)
                fprintf('Expected targets:')
                fullTargetLocs(t,:)
                targets
                error('Invalid trial generated %s trial: %d',condAudioKey, t)
            end

            %now check if the timing is good.
            totalAudioTime = instructions(condAudioKey).TotalSamples/instructions(condAudioKey).SampleRate + instructionAudioBufferSec;
%             for i = fullSequence(t,:)
%                 totalAudioTime = totalAudioTime+instructions(num2str(i)).TotalSamples/instructions(num2str(i)).SampleRate;
%             end
            totalAudioTime = totalAudioTime * 1000;
            if totalAudioTime + sum(fullInterStimIntervals(t,:)) ~= totalCondTimeMs
                error('Invalid trial time found %s trial: %d. Expected: %d, found: %d',condAudioKey, t, totalCondTimeMs, totalAudioTime*1000 + sum(fullInterStimIntervals(t,:)))
            end
            dataTimingInfo(taskTp,n+1,t,:) = [totalAudioTime, min(fullInterStimIntervals(t,:)), max(fullInterStimIntervals(t,:)), mean(fullInterStimIntervals(t,:))];
        end
    end
end

%% Get timing summary
fprintf('\nMin response time across task x n')
min(squeeze(dataTimingInfo(:,:,:,2)),[],3) %the resulting format is task x n, min response time
fprintf('\nMax response time across task x n')
max(squeeze(dataTimingInfo(:,:,:,3)),[],3) %max response time across task x n
fprintf('\nAverage response time across task x n')
mean(squeeze(dataTimingInfo(:,:,:,4)),3) %average response time across task x n
fprintf('\nAverage instruction time (with a short buffer after) across task x n')
mean(squeeze(dataTimingInfo(:,:,:,1)),3) %average instruction time across task x n

%% OLD - Brute force, try untill I satisfy req
% %% Make 6 sequences of 12 letters with 4 hits. if it's 6 back will do 12 + 6 at least 12 opportunities to answer)
% clc;
% rng(2000)
% numStimulus = 12; %12 stimulus
% numTargets = 3;
% repetitions = 16; %5 trials, each with 2 (ST, and DT), and familiarizations (3? trials x 2)
% ISIMin = 1450; %ms %2350-3150 won'twork, on average we need to be at 1879.4ms
% ISIMax= 2300; %max
% for taskTypes = 1:2 %1 is ST, 2 is DT
%     for n = 0:2 %parameter of the N to generate
%         if taskTypes == 2
%             condAudioKey = ['walk', num2str(n)];%build the string walk0, or stand0
%         elseif taskTypes == 1
%             condAudioKey = ['stand', num2str(n)];
%         end
%         totalAudioTime = instructions(audioids{i}).TotalSamples/instructions(audioids{i}).SampleRate;
%         
%         fullSequence = nan(repetitions, numStimulus + n);
%         fullTargetLocs = nan(repetitions, numTargets);
%         interStimIntervals = fullSequence;
%         for rep = 1:repetitions
%             acceptSequence = false; %initialize to false.
%             while ~acceptSequence
%                 if n == 0
%                     sequenceToPlay = [];
%                 else
%                     sequenceToPlay = randi(10,1,n)-1;%keep track of the numbers selected, start with at least N numbers in the array.
%                 end
%                 %randomly generate 4 locations to insert the target, avoid repeating
%                 %target locations, if n=1, avoid more than 4 same numbers in a row
%                 targetLocs = NBackHelper.generateNewTargets(fullTargetLocs, numStimulus, numTargets);
% 
%                 if n == 0 %generate random sequence with 0 in the targetLocs
%                     sequenceToPlay = randi(9,1,numStimulus); %from 1-9 numbers in a sequence
%                     sequenceToPlay(targetLocs) = 0; %set 0 in targe tlocations.
%                 else
%                     for i = 1:numStimulus
%                         isNumNonTarget = false; % a boolean to state a letter has not yet been selected
%                         if ~ismember(i, targetLocs) % this is not a target trial, pick a non-target num
%                             while ~isNumNonTarget % repeat the content of this loop until a non target # is selected
%                                 newNum = randi(10) - 1;% if this is not a target then randomly choose from 0-9
%                                 if newNum ~= sequenceToPlay(end-n+1) % if this is not the same as the n-th trial back
%                                     isNumNonTarget = true; % accept this as the chosen letter
%                                 end
%                             end
%                             %TODO: this can be made slightly smarter using
%                             %Caroline's way of just pick a random sample from the
%                             %remaining non-matching letters.
%                         else %this is a target trial
%                             newNum = sequenceToPlay(end-n+1);% if this was a target choose the n'th back
%                         end
%                         sequenceToPlay=[sequenceToPlay,newNum]; %append to the sequence.
%                     end
%                 end
% 
%                 %this finds locations where the values are consecutive.
%                 consecutiveInSeq = diff(sequenceToPlay,1,2)==1; %find 1st order diff along dimension2/columns. ok to have 1-2-3 but no more than 3 elements in a row
%                 %should have no more than 3 consecutive elements (i.e., no
%                 %more than 2 diff == 1 next to each other).
%                 consecutiveInSeqLoc = find(consecutiveInSeq');
%                 %now find the longest sequence of 1s. (sliding window....)
%                 consecutiveInSeqLoc
%                 moreThan2ConsecInSeq = diff(consecutiveInSeqLoc); %print out to see how many sequential elements are there and locations of the sequential elements, shouldn't have more than 1 (2 1s in a row).
%                 moreThan2ConsecInSeq = find(moreThan2ConsecInSeq == 1); %locations where sequential elements are next to each other.
%                 
%                 %locations with 1-2-3-4
%                 moreThan3ConsecInSeq = diff(moreThan2ConsecInSeq); %print out to see how many sequential elements are there and locations of the sequential elements, shouldn't have more than 1 (2 1s in a row).
%                 moreThan3ConsecInSeq = moreThan3ConsecInSeq == 1; %locations where sequential elements are next to each other, followed by another sequential elements next to each other --> 1-2-3-4
%                 
%                 if any(moreThan3ConsecInSeq)
%                    continue %didn't pass go straight to next loop 
%                 end
%                 
%                 %also avoids number that are exactly the same
%                 % Find indices where the value changes
%                 changeIndices = find(diff(sequenceToPlay) ~= 0);
%                 % Calculate length of each subarray
%                 subarrayLengths = diff(changeIndices);
%                 % Find index of the longest subarray
%                 maxSameNumber = max(subarrayLengths);
%   
%                 %check for any more than 3 together.
%                 if maxSameNumber >= 4 %can have 4-4-4, but not 4-4-4-4
%                     acceptSequence = false;
%                     continue;
%                 end
%                 
%                 %now a good sequence is found quit the loop and save it.
%                 acceptSequence = true;
%             end
%             
%             fullSequence(rep,:) = sequenceToPlay;
%             fullTargetLocs(rep,:) = sort(targetLocs);
%             
%             for i = sequenceToPlay
%                 totalAudioTime = totalAudioTime+instructions(num2str(i)).TotalSamples/instructions(num2str(i)).SampleRate;
%             end
%             
%             totalTimeLeftMs = 30000 -  totalAudioTime*1000;%30s - instruction - letter audio length
%             interStimIntervals(rep,:) = generateInterstimIntervals(totalTimeLeftMs, numStimulus, ISIMin,ISIMax);
%         end
%         fullSequence %visually exam to avoid 1-2-3-4, or 4-3-2-1 etc.    
%         fullTargetLocs  
%         interStimIntervals
%         
%         save(['C:\Users\Public\Documents\MATLAB\ExperimentalGUI\NirsAutomaticityProtocol\n-back-stimulus-new\' condAudioKey '-backSequences.mat'],'fullTargetLocs','fullSequence','interStimIntervals')
%     end
% end
% 
% function targetLocs = generateNewTargets(fullTargetLocs, numStimulus, numTargets)
%     targetLocs = randperm(numStimulus,numTargets); %choose 4 from 1-12 inclusive
%     maxInArow = maxTargetInARow(targetLocs);
%     while all(ismember(targetLocs, fullTargetLocs)) || maxInArow >= 1%|| sum(diff(sort(targetLocs)) == 1) >= 1 
%         %all this sequence exists already, %avoid multiple targets in a
%         %row, i.e., can have 2-2, but not
%         %2-2-2, or 2-5-2 but not 2-5-2-5
%         %I think this is avoiding anything in a row.
%         targetLocs = randperm(numStimulus,numTargets); %choose a new set of targets
% %             while sum(diff(sort(targetLocs)) == 1) > 1 
% %                 %there is more than 1 adjacent targets, redo it (i.e., can have 2-2-2 max, but not 2-2-2-2)
% %                 %only an issue if it's 1-back
% %                 targetLocs = randperm(numStimulus,numTargets); %choose a new set of targets
% %             end
% 
%          maxInArow = maxTargetInARow(targetLocs);
%     end
% end
% 
% function maxInArow = maxTargetInARow(targetLocs)
%     targetsInARow = diff(sort(targetLocs)) == 1; %longes in a row should be <=2;
%     %find max length of the subarrays that have 11111s. 
%     ii = 1; jj = 1; maxInArow = 0;
%     while ii<= jj && jj <= length(targetsInARow)
%         if targetsInARow(jj)
%             jj = jj + 1;
%         else
%             maxInArow = max(maxInArow,jj-ii);
%             ii = jj+1; jj = jj+1;
%         end
%     end
% end
% 
% function interStimIntervals = generateInterstimIntervals(totalTimeLeftMs,numStimulus, rangeMin, rangeMax)
%     %generate intervals between stimulus for the N-back sequence. The
%     %intervals will be between [2350, 3150] ms (inclusive) and the total time will add
%     %up to 71.5s.
%     % Current approach uses a brute force method, keep trying untill the
%     % sum requirement is met. Probably can be optimized. 
%     %Arg     -- numStmiulus: integer representing the # of stimulus in a
%     %sequence
%     %Return  -- interStimIntervals: a matrix with 10 x numStimulus,
%     %1st 2 rows for sitdown capacity assessment trial, 3-6 rows for OG walking trial,
%     %and 7-10 rows for TM walking trials,
%     
%     interStimIntervals = nan(1, numStimulus);
%     range = [rangeMin, rangeMax];
% %     for c = 1:size(interStimIntervals,1)
%         interStimIntervals = randi(range,1,numStimulus-1);
%         interStimIntervals(end+1) = totalTimeLeftMs - sum(interStimIntervals);
%         %TODO: should make this better, by randomize the first n-1, then
%         %the last 1 take the remaining time.
%         
% %         while sum(interval) ~= totalTimeLeftMs %this is brute-force, keep randomizing untill i get something that adds up to the total I want, which could take a while 
% %             interval = randi(range,1,numStimulus);
% %         end
% %         interStimIntervals(c,:) = interval;
% %     end
% end
            
            