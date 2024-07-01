
clear all; close all;

addpath('Auxiliary_files', 'Auxiliary_functions');

% Load waveforms and parameters for I/Q data processing
measfolder = '/home/bailiping/Desktop/Radio_SLAM_data/';
c = physconst('LightSpeed');

% Load required data
load('Transmitted_PRS_config.mat');
load('PRS_waveform_bank_PRS_IDs_0_62.mat');
load('ToA_calibration_16_17_03_2023.mat');
load('TX_RX_positions.mat');

% Initialize estimated positions array
RX_pos_estimated = zeros(size(RX_pos, 1), 2);
AoA_estimated = zeros(size(RX_pos, 1), 1);
d_estimated = zeros(size(RX_pos, 1), 1);

% Calculate estimated positions based on AoA and distance
for idx = 1:19
    % Load the IQ data
    [rxWaveformMat, ~, TX_angles, RX_angles] = load_IQ_data(measfolder, idx);
    
    % Compute power map
    pmap_lin = mean(abs(rxWaveformMat).^2, 3) * 14; % Normalizing power to one slot
    
    % Find indices of the most powerful component
    [ind1, ind2] = ind2sub(size(pmap_lin), find(pmap_lin == max(max(pmap_lin))));
    AoA = RX_angles(ind2);
    AoA_estimated(idx, 1) = AoA;
    
    % Retrieve the waveform corresponding to the most powerful component
    wavfm_rx = squeeze(rxWaveformMat(ind1, ind2, :));
    
    % Set searching bandwidth
    searchBW = 10 * TX_PRS_config.subcarrierSpacing;
    
    % Estimate frequency offset and PRS ID
    [wavfm_rx, freqOffset, PRS_ID] = PRS_CFO_estimate(wavfm_rx, refWaveform, TX_PRS_config, searchBW, (0:62), true);
    
    % Retrieve reference waveform
    wavfm_rf = refWaveform(:, PRS_ID + 1);
    
    % Ensure the length of the received waveform matches the reference waveform
    T = size(wavfm_rx, 1);
    minlength = size(wavfm_rf, 1);
    if T < minlength
        wavfm_rx_pad = [wavfm_rx; zeros(minlength - T, 1)];
        T = minlength;
    else
        wavfm_rx_pad = wavfm_rx;
    end
    
    % Correlate received signal with the reference signal
    refcorr = xcorr(wavfm_rx_pad, wavfm_rf);
    mag = abs(refcorr(T:end));
    
    % Find timing offset
    [~, offset] = max(mag);
    
    % Calculate distance estimate
    distance = offset / TX_PRS_config.SampleRate * c - d_est + d_cal;
    d_estimated(idx, 1) = distance;
    
    % Calculate estimated position
    RX_pos_estimated(idx, 1) = TX_pos(1) - distance * cosd(AoA);
    RX_pos_estimated(idx, 2) = TX_pos(2) - distance * sind(AoA);
end

% Plot the ground truth and estimated positions
fig = openfig('kampusarena_map.fig');
ax = gca;
hold on;

% Plot the TX position
plot(ax, TX_pos(1), TX_pos(2), 'b^', 'MarkerSize', 10, 'LineWidth', 2);
text(ax, TX_pos(1) + 0.5, TX_pos(2) + 0.5, 'TX', 'FontSize', 12);

% Plot the entire RX trajectory as a transparent red line
plot(ax, RX_pos(:, 1), RX_pos(:, 2), 'r', 'LineWidth', 2);
plot(ax, RX_pos_estimated(:, 1), RX_pos_estimated(:, 2), 'gx', 'MarkerSize', 8, 'LineWidth', 2);

% Add legend
%legend(ax, {'TX Position', 'RX Ground Truth', 'RX Estimated'}, 'Location', 'best');

% Adjust the axis limits to fit the data tightly
axis tight;
set(ax, 'LooseInset', get(ax, 'TightInset'));

% Add title
title('Ground Truth vs Estimated RX Positions');
box on;

% Loop through each position to create a frame
frames = cell(size(RX_pos, 1), 1);
for idx = 1:19
    % Plot the current ground truth and estimated positions
    rx_gt_plot = plot(ax, RX_pos(idx, 1), RX_pos(idx, 2), 'ro', 'MarkerSize', 20, 'LineWidth', 2);
    rx_est_plot = plot(ax, RX_pos_estimated(idx, 1), RX_pos_estimated(idx, 2), 'gx', 'MarkerSize', 20, 'LineWidth', 2);
    
    % Draw a red dashed line between TX and the current RX ground truth position
    gt_line_plot = plot(ax, [TX_pos(1), RX_pos(idx, 1)], [TX_pos(2), RX_pos(idx, 2)], 'r--', 'LineWidth', 3);
    
    % Draw a green dashed line from the estimated RX position along the estimated AoA direction
    est_line_length = d_estimated(idx, 1); % length of the AoA line
    AoA_rad = deg2rad(AoA_estimated(idx, 1));
    est_line_end_x = RX_pos_estimated(idx, 1) + est_line_length * cos(AoA_rad);
    est_line_end_y = RX_pos_estimated(idx, 2) + est_line_length * sin(AoA_rad);
    est_line_plot = plot(ax, [RX_pos_estimated(idx, 1), est_line_end_x], [RX_pos_estimated(idx, 2), est_line_end_y], 'g--', 'LineWidth', 3);
    
    % Update the title with the frame number and angle
    title(sprintf('Frame %d, Angle: %.2f°', idx, AoA)); 

    % Capture the frame
    drawnow;
    frames{idx} = getframe(gcf); % Capture the entire figure
    
    % Save each frame as an image
    imwrite(frame2im(frames{idx}), sprintf('frame_%02d.png', idx));
    
    % Remove RX-related plots for the next frame
    delete(rx_gt_plot);
    delete(rx_est_plot);
    delete(gt_line_plot);
    delete(est_line_plot);
end

% Write the frames to a GIF file
gif_filename = 'rx_positions_comparison.gif';
for idx = 1:length(frames)
    [imind, cm] = rgb2ind(frame2im(frames{idx}), 256);
    if idx == 1
        imwrite(imind, cm, gif_filename, 'gif', 'Loopcount', inf, 'DelayTime', 0.5);
    else
        imwrite(imind, cm, gif_filename, 'gif', 'WriteMode', 'append', 'DelayTime', 0.5);
    end
end

hold off;
disp(['GIF saved as ', gif_filename]);
