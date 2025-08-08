classdef ISIRandMethod
    %Define a enum class for allowed randomziation method
    %uniform uses uniform distributio to randomly draw the intervals.
    %Normal uses normal distribution to draw the inerval randomly.
    %Psuedo uses randi but adjusted to fit the total length, so it's a pseudo random or
    %almost manual algorithm. The distribution has a tendency to heavily tail towards ISImin or ISImax.
    %Psuedo order was was used in BW02V05 and BW04V05
    enumeration
        uniform, normal, pseudo
    end
end