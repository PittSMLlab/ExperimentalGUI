classdef NBackHelper
    %Static helper function to generate N-back sequences matching the
    %requirements, i.e., target every x number of stimulis, total sequence
    %time add up to a given number
        
    methods(Static)
        % Helper funciton to get the target location, break down the total stim into sub-sections to ensure they won't be next to each other. 
        function targetLocs = generateNewTarget(numStimulus, numTarget, nback, existingTargetLocs)
            % Generate locations to insert a target, generate locations by sections
            % to avoid all targets are next to each other and all in the beginning
            % or all in the end.
            % 
            % [OUTPUTARGS]
            %   - targetLocs: array of integer representing indexes of target in
            %       this sequence
            % 
            % [InputArgs]
            %   - numStimulus: integer, number of stimulus total that exist in this
            %   sequence
            %   - numTarget: integer, number of target in this sequence
            %   - existingTargetLocs: 2D array of existing target locations, this
            %       is used to check that no repeat locations are used
            % $Author: Shuqi Liu $	$Date: 2025/02/14 10:12:38 $	$Revision: 0.1 $
            % Copyright: Sensorimotor Learning Laboratory 2025
            
            %break down into subsections.
            
            subSeqLength = floor((numStimulus-nback)/numTarget); %if 12 stim, 3 target, subseq length = 4, insert a random target every 4.
            targetLocs = zeros(1,numTarget)-1; %initialize to default value = -1, so will go into the while loop at least once bc the existing target is defaulted to -1 everywhere too.
            %if using default nan, will not go into the while loop bc nan doesn't
            %equal nan by matlab default, so would think there is no repeat, a new
            %row is generated and return default.

            %Regenerate untill a non-repeat row is found
            while ismember(targetLocs, existingTargetLocs,'rows') %check if a same row with the same target locs already exists
                %this row already exists, regenerate
                %this is not super idea, we may be in an infinte loop but couldn't
                %think of another way right now, hoping that we only need to do
                %this once and we have a good chance of not repeating out of 4*4*4
                %total options

                %if it's 1back, first possible target location is 2 (need to hear 1 stim first); if it's 2-back, first
                %possible target location is 3
%                 targetLocs(1) = randperm(subSeqLength - nback,1) + nback;
                for i = 1:numTarget
                    targetLocs(i) = randperm(subSeqLength,1) + (i-1)*subSeqLength; %random permutations of 1:arg1, no repeat; then offset by the length of prev sequence generated (the 2nd time, would be 4 + new rand location)
                end
            end
            targetLocs = targetLocs + nback;
        end

        % Helper funciton to set up inter stimulus intervals (ISI) such that they are between [ISIMin, and ISIMax], but also add up to the total left remaining
        function responseTime = generatePseudoISI(totalTimeLeftMs, numStimulus, ISIMin,ISIMax)
            %Generate inter stimulus intervals, aka time for paticipant to respond, randomized such that the interval
            %is in [min, max] but also sum to the total time left. This is a
            %pseudorandom procedure, using a heureustic that we first allocate min
            %time for all intervals, then randomly add time between [0, max-min],
            %the last location by default takes totalRemainin - totalUsed. If that
            %makes the last location <min, then start from location1 and
            %give the minimum required for the last location to > min while keep location1 > min
            %if that's not possible, then make location1 = 0, give it all to last location and continue with location 2
            %Vice versa for if last location > max.
            %Notice that this will likely make the first few and last
            %location very close to minISI and the middle ones will be
            %bigger. Which is true confirmed by plotting the ISI generated.
            % 
            % [OUTPUTARGS]
            %   - ISIs: array of integer representing inter stimulus interval in
            %       ms. All stimulus will have an ISI including the last one, bc we
            %       will give ISI length for participant to respond
            % 
            % [InputArgs]
            %   - totalTimeLeftMs: integer representing remaining time to use for
            %       ISI in ms
            %   - numStimulus: integer, number of stimulus total that exist in this
            %       sequence
            %   - numTarget: integer, number of target in this sequence
            %   - ISIMin: integer, representing min interval length in ms
            %       (inclusive).
            %   - ISIMax:integer, representing max interval length in ms
            %       (inclusive).
            % $Author: Shuqi Liu $	$Date: 2025/02/14 10:12:38 $	$Revision: 0.1 $
            % Copyright: Sensorimotor Learning Laboratory 2025

            %first check that it's possible to find ISIs that match all the
            %requirements, i.e., the total time left is not too short or too long
            
            if totalTimeLeftMs > numStimulus * ISIMax || totalTimeLeftMs < numStimulus * ISIMin
                %even if all itnerval is max, or min, it's still below or above
                %total left, ill condition
                error('Bad ISI range and total condition given')
            end

            generationSuccess = false;
            while ~generationSuccess %most likely will suceed in 1 try, failed re-balance likelyhood is low or almost impossible, unless an ill condition is given.
                responseTime = repmat(ISIMin,1,numStimulus);
                for i = 1:numStimulus - 1
                    responseTime(i) = responseTime(i) + randi([0,ISIMax-ISIMin],1);
                end
                responseTime(end) = totalTimeLeftMs - sum(responseTime(1:end-1));

                %now check if the last one satisfies requirement
                if responseTime(end) < ISIMin
                    %go through everyone that's above min and give it all untill not
                    %needed anymore
                    for i = 1:numStimulus - 1
                        canShed = responseTime(i) - ISIMin;
                        missingTime = ISIMin - responseTime(end);
                        if canShed >= missingTime
                            responseTime(end) = responseTime(end) + missingTime; %this is the same as ISImin
                            responseTime(i) = responseTime(i) - missingTime;
                            %we are good now, break
                            break
                        else
                            %not enough time, keep going.
                            responseTime(i) = ISIMin; %equivalenet to resposneTime(i) - canShed, shed it all
                            responseTime(end) = responseTime(end) + canShed;
                        end
                    end
                elseif responseTime(end) > ISIMax
                    %go through everyone that's above min and give it all untill not
                    %needed anymore
                    for i = 1:numStimulus - 1
                        canGrow = ISIMax - responseTime(i);
                        extraTime = - ISIMax + responseTime(end);
                        if canGrow >= extraTime
                            responseTime(end) = responseTime(end) - extraTime; %this is the same as ISImin
                            responseTime(i) = responseTime(i) + extraTime;
                            %we are good now, break
                            break
                        else
                            %not enough time, keep going.
                            responseTime(i) = ISIMax; %equivalenet to resposneTime(i) + cangrow, grow it all
                            responseTime(end) = responseTime(end) - canGrow;
                        end
                    end
                end

                if responseTime(end) >= ISIMin && responseTime(end) <+ ISIMax %rebalanced, success accespt the sequence
                    generationSuccess = true;
                end
            end
            %now shuffle the response time to avoid beginning and end very
            %close to min ISI due to the algorithm deficits.
            responseTime = responseTime(randperm(length(responseTime)));
        end
        
        function responseTime = generateNormalISI(totalTimeLeftMs, numStimulus, ISIMin, ISIMax)
            % Generate ISIs from a truncated normal distribution and adjust them to sum to totalTimeLeftMs

            % Check feasibility
            if totalTimeLeftMs < numStimulus * ISIMin || totalTimeLeftMs > numStimulus * ISIMax
                error('Impossible to allocate time within ISI bounds');
            end

            % Parameters for normal distribution
            mu = (ISIMin + ISIMax) / 2;
            sigma = (ISIMax - ISIMin) / 6; % ~99.7% data within bounds in normal dist

            % Generate truncated normal samples
            rawISI = zeros(1, numStimulus);
            generated = [];

            for i = 1:numStimulus
                val = inf;
                attempts = 0;
                maxAttempts = 1000;

                while (val < ISIMin || val > ISIMax || ismember(val, generated)) && attempts < maxAttempts
                    val = round(normrnd(mu, sigma));
                    attempts = attempts + 1;
                end

                if attempts >= maxAttempts
                    error('Could not generate enough unique ISIs. Consider widening ISI range or reducing numStimulus.');
                end

                rawISI(i) = val;
                generated(end+1) = val;
            end


            % Rescale ISIs so their sum equals totalTimeLeftMs
            scaleFactor = totalTimeLeftMs / sum(rawISI);
            responseTime = round(rawISI * scaleFactor);

            % Fix rounding issues: adjust final element so total sum is exact
            discrepancy = totalTimeLeftMs - sum(responseTime);
            responseTime(end) = responseTime(end) + discrepancy;

            % Shuffle to randomize order
            responseTime = responseTime(randperm(numStimulus));
        end

        function responseTime = generateUniformISI(totalTimeLeftMs, numStimulus, ISIMin, ISIMax)
            % Generate uniformly distributed ISIs with constraints on min and max values

            numBins = 6;
            ISIsPerBin = numStimulus / numBins;

            % Check feasibility
            if totalTimeLeftMs < numStimulus * ISIMin || totalTimeLeftMs > numStimulus * ISIMax
                error('Impossible to allocate time within ISI bounds');
            end

            % Define bin edges
            binEdges = linspace(ISIMin, ISIMax, numBins + 1);

            validISI = false;

            while ~validISI
                rawISI = [];

                for b = 1:numBins
                    binMin = ceil(binEdges(b));
                    binMax = floor(binEdges(b + 1));

                    if binMin > binMax
                        error('Bin range is invalid — increase ISI range or reduce number of bins.');
                    end

                    % Generate uniform ISIs from current bin
                    binSamples = randi([binMin, binMax], 1, ISIsPerBin);
                    rawISI = [rawISI binSamples];
                end

                % Rescale ISIs to match total time
                scaleFactor = totalTimeLeftMs / sum(rawISI);
                responseTime = round(rawISI * scaleFactor);

                % Fix rounding discrepancy
                discrepancy = totalTimeLeftMs - sum(responseTime);
                responseTime(end) = responseTime(end) + discrepancy;

                % Check if all ISIs are at least ISIMin
                if all(responseTime >= ISIMin) && all(responseTime <= ISIMax)
                    validISI = true;
                end
            end

            % Shuffle
            responseTime = responseTime(randperm(numStimulus));
        end     
        
    end
end