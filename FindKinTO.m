function TO = FindKinTO(start,stop,ankdata,n)
%FINDKINTO Find toe-off index as the local minimum of a limb-angle trace.
%
%   Scans from start to stop and returns the first index ii such that
%   ankdata(ii) is less than or equal to all values in the n-sample window
%   on each side.
%
% Inputs:
%   start   - first sample index to search (scalar integer)
%   stop    - last sample index to search (scalar integer)
%   ankdata - limb-angle trace (numeric vector)
%   n       - half-width of the local-minimum window (scalar integer)
%
% Outputs:
%   TO - sample index of the detected toe-off
%
% Toolbox Dependencies:
%   None
%
% See also FINDKINHS.

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
    if all(ankdata(i)<= ankdata(a)) && all(ankdata(i)<=ankdata(b))
        break;
    end
end
TO = i;
end

