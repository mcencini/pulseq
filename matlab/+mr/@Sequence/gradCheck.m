function gradCheck(obj, index, event, check_g)
%gradCheck: check if connection to the previous block is correct using check_g

% Check is necessary only if gradient starts at non-0
% We do not need to rotate for this.
do_check = false;
for cg_temp = check_g
    cg = cg_temp{1}; % cg_temp is still a cell-array with a single element here...
    if isempty(cg), continue; end
    if abs(cg.start(2)) <= obj.sys.maxSlew * obj.sys.gradRasterTime
        do_check = true; % we have at least one axis starting at non-0
    end
    % Check if gradients, which do not end at 0, are as long as the block itself.
    if cg.stop(2) > obj.sys.maxSlew * obj.sys.gradRasterTime && abs(cg.stop(1)-duration) > 1e-7
        error('Error in block %d: A gradient that doesn''t end at zero needs to be aligned to the block boundary', index);
    end
end
if do_check && index <= 1
    error('First gradient in the the first block has to start at 0.');
end
if not(do_check), return; end

% Our gradient event(s) start at non zero; must check against previous
% block

% Get current block start points
curr_grad_first = [0, 0, 0];
for cg_temp = check_g
    cg=cg_temp{1}; % cg_temp is still a cell-array with a single element here...
    if isempty(cg), continue; end
    curr_grad_first(cg.idx-2) = cg.start(2);
end

% Get previous block
[~,prev_nonempty_block] = find(obj.blockDurations(1:(index-1))>0, 1, 'last');

% Current gradient event(s) start at non zero, hence it is arbitrary;
% check if previous block is trapezoid (cannot finish with non-0, hence
% errors
prev_grad_last = [0, 0, 0];
for idx = [3, 4, 5]
    prev_id = obj.blockEvents{prev_nonempty_block}(idx);
    if prev_id ~= 0
        prev_grad = obj.gradLibrary.get(prev_id); % MZ: for performance reasons we access the gradient library directly. I know, this is not elegant
        prev_grad_dat = prev_grad.data;
        prev_grad_type = prev_grad.type;
        if prev_grad_type == 't'
            error('Error in block %d: Two consecutive gradients need to have the same amplitude at the connection point, this is not possible if the previous gradient is a simple trapezoid', index);
        else
            prev_grad_last(idx-2) = prev_grad_dat(6); % '6' means last; MZ: I know, this is a real hack...
        end
    end
end

% Check if current block has rotation
current_has_rot = isfield(event);
current_rotmat = eye(3);
if current_has_rot
    current_rotmat = event.rotation.rotMatrix;
end

% Check if previous block has rotation
previous_has_rot = false;
previous_rotmat = eye(3);

% Rotation extension ID
rot_type_id = obj.getExtensionTypeID('ROTATIONS');

% Get previous block extension ID
ext_id = obj.blockEvents{prev_nonempty_block}(end);
while ext_id || not(previous_has_rot)
    ext = obj.extensionLibrary.get(ext_id);
    if ext(1) == rot_type_id
        previous_has_rot = true;
        previous_rotmat = obj.rotationLibrary.data(ext(2)).array;
        previous_rotmat = resize(previous_rotmat, 3, 3)';
    else
        ext_id = ext(end); % next entry in the list
    end
end

% If either has rotation, get rotated versions of first
% point of current block and last point of previous block (use Identity as
% default
has_rot = current_has_rot || previous_has_rot;
if has_rot
    curr_grad_first = current_rotmat * curr_grad_first;
    prev_grad_last = previous_rotmat * prev_grad_last;
end

% Do comparison
if any(abs(curr_grad_first - prev_grad_last) > obj.sys.maxSlew * obj.sys.gradRasterTime)
    error('Error in block %d: Two consecutive gradients need to have the same amplitude at the connection point', index);
end

end