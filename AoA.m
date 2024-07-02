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
position_indices = 1:45;
frames = cell(length(position_indices), 1);

% Target frame size
target_frame_size = [800, 1000];

% Create a directory to store the frames
frames_folder = 'frames';
if ~exist(frames_folder, 'dir')
    mkdir(frames_folder);
end

% Second pass: generate the frames
for idx = 1:length(position_indices)
    position_index = position_indices(idx);
    % Load IQ data and angles, make sure the function call is correct
    try
        [rxWaveformMat,~,TX_angles,RX_angles] = load_IQ_data(measfolder, position_index);
    catch e
        error('Error loading IQ data for position index %d: %s', position_index, e.message);
    end

    % Check the dimensions of rxWaveformMat
    if isempty(rxWaveformMat)
        error('Received empty rxWaveformMat for position index %d', position_index);
    end

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
    frame = getframe(gcf);
    
    % Resize the frame to the target size
    resized_frame = imresize(frame.cdata, target_frame_size);
    
    % Store the resized frame as a PNG file
    frame_filename = fullfile(frames_folder, sprintf('frame_%03d.png', idx));
    imwrite(resized_frame, frame_filename);
    
    % Store the frame in the cell array
    frames{idx} = resized_frame;
    
    close(gcf);
end

% Create a VideoWriter object for the MP4 file
video_filename = 'power_maps.avi'; % Changed from .mp4 to .avi
v = VideoWriter(video_filename, 'Motion JPEG AVI'); % Changed profile to 'Motion JPEG AVI'
v.FrameRate = 2; % Set frame rate to 2 frames per second
open(v);

% Write the frames to the video file
for idx = 1:length(frames)
    writeVideo(v, frames{idx});
end

% Close the VideoWriter object
close(v);

% Write the frames to a GIF file
gif_filename = 'power_maps.gif';
for idx = 1:length(frames)
    % Convert the frame to an indexed image
    [imind, cm] = rgb2ind(frames{idx}, 256);
    if idx == 1
        imwrite(imind, cm, gif_filename, 'gif', 'Loopcount', inf, 'DelayTime', 0.5);
    else
        imwrite(imind, cm, gif_filename, 'gif', 'WriteMode', 'append', 'DelayTime', 0.5);
    end
end

disp(['GIF saved as ', gif_filename]);
disp(['AVI video saved as ', video_filename]);
