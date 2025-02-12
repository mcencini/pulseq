function grad = rotate_array(grad, rot_matrix)
    grad_channels = {'gx', 'gy', 'gz'};
    
    % Get the length of gradient waveforms
    wave_lengths = [];
    for i = 1:length(grad_channels)
        ch = grad_channels{i};
        if isfield(grad, ch)
            wave_lengths = [wave_lengths, length(grad.(ch))];
        end
    end
    
    unique_lengths = unique(wave_lengths);
    unique_lengths(unique_lengths == 0) = [];
    
    assert(numel(unique_lengths) == 1, ...
        'All the waveforms along different channels must have the same length');
    
    wave_length = unique_lengths;
    
    % Create zero-filled waveforms for empty gradient channels
    for i = 1:length(grad_channels)
        ch = grad_channels{i};
        if isfield(grad, ch)
            grad.(ch) = grad.(ch)(:); % Ensure column vector
        else
            grad.(ch) = zeros(wave_length, 1);
        end
    end
    
    % Stack matrix
    grad_mat = [grad.gx, grad.gy, grad.gz]'; % (3, wave_length)
    
    % Apply rotation
    grad_mat = rot_matrix * grad_mat;
    grad_mat = grad_mat'; % (wave_length, 3)
    
    % Put back in the struct
    for j = 1:3
        ch = grad_channels{j};
        grad.(ch) = grad_mat(:, j)';
    end
    
    % Remove all zero waveforms
    for i = 1:length(grad_channels)
        ch = grad_channels{i};
        if all(abs(grad.(ch)) < 1e-6) % Equivalent to np.allclose
            grad = rmfield(grad, ch);
        end
    end
end

