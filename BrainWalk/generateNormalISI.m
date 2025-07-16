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
