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
