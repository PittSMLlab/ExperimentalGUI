%% TODO: familarization of each condition (incremental order) maybe 30s window, avg 2.5s/letter, 12 letters.
% each trial time will vary depends on the randomization (vary in a 9.6s
% window), make sure first and last have no hit?, always take the middle 28
% or 30s for analysis. 
% then 4 more sets more of randomize the order of load (randomize and use the same for all
% people, full randomize, or 123456-654321 
% pregenerate 6 sequences of 12 digits per load condition, avoid 0-1-2-3 or 3-2-1-0, or
% 1-1-1-1, have 25% of hit, 3 correct response 
% given load level & trial#, load sequence, play - pause random btw 2350ms
% - 3150ms (have the answer within this window, maybe randomize between 1-2s around 1.5s) - next letter
% when done: stop and rest for 20s. 
% Send to NIRS the events from beginning of instruction to next instruction
% (like now). 
% if on TM. send times of instruction. start of ramp, start of steady
% speed, end of steady speed, and end of ramp/start of rest. 

%% Make 6 sequences of 12 letters with 4 hits. if it's 6 back will do 12 +6 at least 12 opportunities to answer)
clc;
rng(2000)
numStimulus = 26; %12 stimulus
repetitions = 10; %2 for sitdown, 4 for OG, 4 for TM
numTargets = 6;
for n = 0:8 %parameter of the N to generate
    fullSequence = nan(repetitions, numStimulus + n);
    fullTargetLocs = nan(repetitions, numTargets);
    for rep = 1:repetitions
        if n == 0
            presentedSequence = [];
        else
            presentedSequence = randi(10,1,n)-1;%keep track of the numbers selected, start with at least N numbers in the array.
        end
        %randomly generate 4 locations to insert the target, avoid repeating
        %target locations, if n=1, avoid more than 4 same numbers in a row
        targetLocs = generateNewTargets(rep, fullTargetLocs, numStimulus, numTargets);
        
        if n == 0 %generate random sequence with 0 in the targetLocs
            presentedSequence = randi(9,1,numStimulus); %from 1-9 numbers in a sequence
            presentedSequence(targetLocs) = 0; %set 0 in targe tlocations.
        else
            for i = 1:numStimulus
                isNumNonTarget = false; % a boolean to state a letter has not yet been selected
                if ~ismember(i, targetLocs) % this is not a target trial, pick a non-target num
                    while ~isNumNonTarget % repeat the content of this loop until a non target # is selected
                        newNum = randi(10) - 1;% if this is not a target then randomly choose from 0-9
                        if newNum ~= presentedSequence(end-n+1) % if this is not the same as the n-th trial back
                            isNumNonTarget = true; % accept this as the chosen letter
                        end
                    end
                else %this is a target trial
                    newNum = presentedSequence(end-n+1);% if this was a target choose the n'th back
                end
                presentedSequence=[presentedSequence,newNum];
            end
        end
        fullSequence(rep,:) = presentedSequence;
        fullTargetLocs(rep,:) = sort(targetLocs);
    end

    fullTargetLocs
    fullSequence %visually exam to avoid 1-2-3-4, or 4-3-2-1 etc.
    diffInSeq = diff(fullSequence,1,2)==1 %ok to have 1-2-3 but no more than 3 elements in a row
    diff(find(diffInSeq')) %print out to see how many sequential elements are there, shouldn't have more than 1 (2 1s in a row).

    interStimIntervals = generateInterstimIntervals(numStimulus);
    save([num2str(n) '-backSequences.mat'],'fullTargetLocs','fullSequence','interStimIntervals')
end

function targetLocs = generateNewTargets(rep, fullTargetLocs, numStimulus, numTargets)
    targetLocs = randperm(numStimulus,numTargets); %choose 4 from 1-12 inclusive
    for j = 1:rep %check for repeats
        while all(ismember(targetLocs, fullTargetLocs(j,:))) || sum(diff(sort(targetLocs)) == 1) >= 1 
            %all this sequence exists already, %avoid multiple targets in a
            %row (max 2 in a row), i.e., can have 2-2-2 max, but not
            %2-2-2-2, or 2-5-2-5 but not 2-5-2-5-2-5 
            targetLocs = randperm(numStimulus,numTargets); %choose a new set of targets
%             while sum(diff(sort(targetLocs)) == 1) > 1 
%                 %there is more than 1 adjacent targets, redo it (i.e., can have 2-2-2 max, but not 2-2-2-2)
%                 %only an issue if it's 1-back
%                 targetLocs = randperm(numStimulus,numTargets); %choose a new set of targets
%             end
        end
    end
end

function interStimIntervals = generateInterstimIntervals(numStimulus)
    %generate intervals between stimulus for the N-back sequence. The
    %intervals will be between [2350, 3150] ms (inclusive) and the total time will add
    %up to 71.5s.
    % Current approach uses a brute force method, keep trying untill the
    % sum requirement is met. Probably can be optimized. 
    %Arg     -- numStmiulus: integer representing the # of stimulus in a
    %sequence
    %Return  -- interStimIntervals: a matrix with 10 x numStimulus,
    %1st 2 rows for sitdown capacity assessment trial, 3-6 rows for OG walking trial,
    %and 7-10 rows for TM walking trials,
    
    interStimIntervals = nan(10, numStimulus);
    range = [2350, 3150];
    for c = 1:size(interStimIntervals,1)
        interval = randi(range,1,26);
        while sum(interval) ~= 71500
            interval = randi(range,1,26);
        end
        interStimIntervals(c,:) = interval;
    end
end
            
            