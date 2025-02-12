function gradCheck(obj, index, check_g, duration, rotEvent)
%gradCheck: check if connection to the previous block is correct using check_g

if isempty(obj.rotationLibrary.data)
    gradCheck_norot(obj, index, check_g, duration);
else
    gradCheck_rot(obj, index, check_g, duration, rotEvent);
end
end

function gradCheck_norot(obj, index, check_g, duration)
%gradCheck_norot: check if connection to the previous block is correct using check_g
%gradients are not rotated: use standard Pulseq gradcheck

for cg_temp = check_g
    cg=cg_temp{1}; % cg_temp is still a cell-array with a single element here...
    if isempty(cg), continue; end
    
    if abs(cg.start(2)) > obj.sys.maxSlew * obj.sys.gradRasterTime % MZ: we only need the following check if the current gradient starts at non-0
        if cg.start(1) ~= 0
            error('Error in block %d: No delay allowed for gradients which start with a non-zero amplitude', index);
        end
        if index > 1
            [~,prev_nonempty_block]=find(obj.blockDurations(1:(index-1))>0, 1, 'last');
            prev_id = obj.blockEvents{prev_nonempty_block}(cg.idx);
            if prev_id ~= 0
                prev_lib = obj.gradLibrary.get(prev_id); % MZ: for performance reasons we access the gradient library directly. I know, this is not elegant
                prev_dat = prev_lib.data;
                prev_type = prev_lib.type;
                if prev_type == 't'
                    error('Error in block %d: Two consecutive gradients need to have the same amplitude at the connection point, this is not possible if the previous gradient is a simple trapezoid', index);
                elseif prev_type == 'g'
                    last = prev_dat(6); % '6' means last; MZ: I know, this is a real hack...
                    if abs(last - cg.start(2)) > obj.sys.maxSlew * obj.sys.gradRasterTime
                        error('Error in block %d: Two consecutive gradients need to have the same amplitude at the connection point', index);
                    end
                end
            else
                error('Error in block %d: Gradient starting at non-zero value need to be preceded by a compatible gradient', index);
            end
        else
            error('First gradient in the the first block has to start at 0.');
        end
    end
    
    % Check if gradients, which do not end at 0, are as long as the block itself.
    if abs(cg.stop(2)) > obj.sys.maxSlew * obj.sys.gradRasterTime && abs(cg.stop(1)-duration) > 1e-7
        error('Error in block %d: A gradient that doesn''t end at zero needs to be aligned to the block boundary', index);
    end
end

end


function gradCheck_rot(obj, index, check_g, duration, rotEvent)
%gradCheck_rot: check if connection to the previous block is correct using check_g
%gradients are rotated: check current against previous block after applying
%rotation to both
do_check = false;
for cg_temp = check_g
    cg=cg_temp{1}; % cg_temp is still a cell-array with a single element here...
    if isempty(cg), continue; end
    
    if abs(cg.start(2)) > obj.sys.maxSlew * obj.sys.gradRasterTime % MZ: we only need the following check if the current gradient starts at non-0
        if cg.start(1) ~= 0
            error('Error in block %d: No delay allowed for gradients which start with a non-zero amplitude', index);
        end
        do_check = true;
    end
end

if do_check && index > 1
    current_has_rot = not(isempty(rotEvent));
    previous_has_rot = false;
    
    % Rotation extension ID
    rot_type_id = obj.getExtensionTypeID('ROTATIONS');
    
    % Get index of previous block
    [~,prev_nonempty_block] = find(obj.blockDurations(1:(index-1))>0, 1, 'last');
    
    % Comparison with previous block
    prev_grad_last = [0, 0, 0];
    
    % Look up the last gradient value in the previous block
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

    % Get previous block rotation matrix
    ext_id = obj.blockEvents{prev_nonempty_block}(end);
    while ext_id && not(previous_has_rot)
        try
            ext = obj.extensionLibrary.data(ext_id).array;
            if ext(1) == rot_type_id
                previous_has_rot = true;
                previous_rotmat = obj.rotationLibrary.data(ext(2)).array;
                previous_rotmat = reshape(previous_rotmat, 3, 3)';
            else
                ext_id = ext(end); % next entry in the list
            end
        catch
            ext_id = 0;
        end
    end

    % Rotate last gradient
    if previous_has_rot
        prev_grad_last = previous_rotmat * prev_grad_last';
        prev_grad_last = prev_grad_last';
    end

    % Look up the first gradient value in current block
    curr_grad_first = [0, 0, 0];
    for cg_temp = check_g
        cg=cg_temp{1}; % cg_temp is still a cell-array with a single element here...
        if isempty(cg), continue; end
        curr_grad_first(cg.idx-2) = cg.start(2);
    end

    % Rotate current gradient
    if current_has_rot
        curr_grad_first = rotEvent.rotMatrix * curr_grad_first';
        curr_grad_first = curr_grad_first';
    end

    % Do comparison
    if any(abs(curr_grad_first - prev_grad_last) > obj.sys.maxSlew * obj.sys.gradRasterTime)
        error('Error in block %d: Two consecutive gradients need to have the same amplitude at the connection point', index);
    end
else
    for cg_temp = check_g
        cg=cg_temp{1}; % cg_temp is still a cell-array with a single element here...
        if isempty(cg), continue; end
        if abs(cg.start(2)) > obj.sys.maxSlew * obj.sys.gradRasterTime % MZ: we only need the following check if the current gradient starts at non-0            if cg.start(1) ~= 0
            error('First gradient in the the first block has to start at 0.');
        end
    end
end

for cg_temp = check_g
    cg=cg_temp{1}; % cg_temp is still a cell-array with a single element here...
    if isempty(cg), continue; end
    % Check if gradients, which do not end at 0, are as long as the block itself.
    if abs(cg.stop(2)) > obj.sys.maxSlew * obj.sys.gradRasterTime && abs(cg.stop(1)-duration) > 1e-7
        error('Error in block %d: A gradient that doesn''t end at zero needs to be aligned to the block boundary', index);
    end
end

end