function HS = FindKinHS(start,stop,ankdata,n)
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

for i = start:stop
    if i == 1
        a = 1;
    elseif (i-n) < 1
        a = 1:i-1;
    else
        a = i-n:i-1;
    end
    if i == stop
        b = stop;
    elseif (i+n) > stop
        b = i+1:stop;
    else
        b = i+1:i+n;
    end
    if all(ankdata(i)>=ankdata(a)) && all(ankdata(i)>=ankdata(b)) %HH added "=" for the very rare case where the two max/min are the same value.
        break;
    end
end
HS = i;
end

