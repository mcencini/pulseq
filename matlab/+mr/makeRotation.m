function rotation = makeRotation(rotMatrix)
%makeRotation Create a delay event.
%   rotation=makeRotation(rotMatrix) Create rotation event with given rotation matrix rotMatrix.
%
%   See also  Sequence.addBlock

if nargin<1
    error('makeRotation:invalidArguments','Must supply a rotation matrix');
end

rotation.type = 'rotation';
rotation.rotMatrix = rotMatrix;
end
