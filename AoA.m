clear all; close all;
addpath('Auxiliary_files','Auxiliary_functions')
load('TX_RX_positions.mat') 
measfolder = '/home/bailiping/Desktop/Radio_SLAM_data/'; 
% Speed of light constant:
c = physconst('LightSpeed');
% Load OFDM carrier and PRS signal configuration parameters 'TX_PRS_config'
load('Transmitted_PRS_config.mat')
load('PRS_waveform_bank_PRS_IDs_0_62.mat')
load('ToA_calibration_16_17_03_2023.mat');
position_indices = 1:25;
frames = cell(length(position_indices), 1);

% Loop through each position index, generate the power map and store frames
for idx = 1:length(position_indices)
    position_index = position_indices(idx);
    [rxWaveformMat,~,TX_angles,RX_angles] = load_IQ_data(measfolder, position_index);
    % Number of transmitted beams
    NumTX = size(rxWaveformMat,1); 

    % Calculate the power and plot power map
    % Form the power matrix (in mW)
    pmap_lin = mean(abs(rxWaveformMat).^2,3)*14; % Factor 14 is used to normalize power to one slot, as only one OFDM symbol is transmitted
    % Form the power matrix (in dBm)
    pmap = 10*log10(pmap_lin); 

    % Plot power map (in log scale)
    figure;
    imagesc(RX_angles, TX_angles, pmap);
    daspect([1,1,1]);
    colorbar;
    xlabel('\theta, AoA [\circ]');
    ylabel('\phi, AoD [\circ]');
    title(['Power map [dBm], position #',num2str(position_index)]);
    
    % Capture the frame
    frames{idx} = getframe(gcf);
    close(gcf);
end

% Write the frames to a GIF file
gif_filename = 'power_maps.gif';
for idx = 1:length(frames)
    [imind, cm] = rgb2ind(frame2im(frames{idx}), 256);
    if idx == 1
        imwrite(imind, cm, gif_filename, 'gif', 'Loopcount', inf, 'DelayTime', 0.5);
    else
        imwrite(imind, cm, gif_filename, 'gif', 'WriteMode', 'append', 'DelayTime', 0.5);
    end
end

disp(['GIF saved as ', gif_filename]);