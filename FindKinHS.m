function HS = FindKinHS(start, stop, ankdata, n)
%FINDKINHS Find heel-strike index as the local maximum of a limb-angle trace.
%
%   Scans from start to stop and returns the first index ii such that
%   ankdata(ii) is greater than or equal to all values in the n-sample
%   window on each side. The >= comparisons handle the rare case where
%   consecutive samples share the same maximum value.
%
% Inputs:
%   start   - first sample index to search (scalar integer)
%   stop    - last sample index to search (scalar integer)
%   ankdata - limb-angle trace (numeric vector)
%   n       - half-width of the local-maximum window (scalar integer)
%
% Outputs:
%   HS - sample index of the detected heel strike
%
% Toolbox Dependencies:
%   None
%
% See also FINDKINTO.

for ii = start:stop
    if ii == 1
        a = 1;
    elseif (ii - n) < 1
        a = 1:ii - 1;
    else
        a = ii - n:ii - 1;
    end
    if ii == stop
        b = stop;
    elseif (ii + n) > stop
        b = ii + 1:stop;
    else
        b = ii + 1:ii + n;
    end
    if all(ankdata(ii) >= ankdata(a)) && all(ankdata(ii) >= ankdata(b))
        break;
    end
end
HS = ii;
end
