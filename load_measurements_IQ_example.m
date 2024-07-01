clear all, close all
%% Loading binary data files and simple processing
%  - Download auxillary finctions and parameter files.
%  - Download binary measurement files to your local directory.
%  - Assign path to the measurement directory to string variable 'measfolder' (with "\" in the end). 
%  - Use function 'load_IQ_data.m' to load the binary data, TX and RX angles.
%  - Loaded data are in the form of a data cube size L_TX x L_RX x N_waveform. 
%  - Each vector rxWaveformMat(i,j,:) is a received waveform containing one OFDM symbol
%       (PRS) received via (i,j) TX-RX beam pair. 
% 
%  E. Rastorgueva-Foi, 2023-2024
%  elizaveta.rastorgueva-foi@tuni.fi
%
%
addpath('Auxiliary_files','Auxiliary_functions')
%% Load and plot the map of the measurement environment 
% Load coordinates of TX and RX (variables 'TX_pos','RX_pos'), hand-measured.
% Each coordinate is in form (x,y) in global reference frame, in meters.
% RX coordinate variable 'RX_pos' is matrix of size 45x2
load('TX_RX_positions.mat') % 

%
%% Load waveforms and parameters for I/Q data processing
% Incert the name of directory with binary files:
measfolder = '/home/bailiping/Desktop/Radio_SLAM_data/'; 
% Speed of light constant:
c = physconst('LightSpeed');
% Load OFDM carrier and PRS signal configuration parameters 'TX_PRS_config'
load('Transmitted_PRS_config.mat')
% Load reference PRS waveforms (beamformed PRS ID = 0...62), variable 
% 'refWaveform' is loaded as matrix of a size 61632x63, whose columns are 
% complex vectors, each representing a reference waveform (one slot - 14 
% OFDM symbols)  
load('PRS_waveform_bank_PRS_IDs_0_62.mat')
% Load ToA/range calibration terms 'd_est' and 'd_cal' (in meters) to
% offset the electronics-iduced delays
load('ToA_calibration_16_17_03_2023.mat');
%
%% Choose the LoS component (MPC with highest power in case of LoS propagation)
% Incert position number of a LoS propagation position (numbering as in the 
% publication):
% Define the measurement folder and the range of positions
position_indices = 1:19;

% Preallocate cell array to store frame data for the GIF
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

%
%%
%% Extras: estimate CFO and the coarse time delay for the most powerful component
% Finding the indeces of most powerful component
[ind1,ind2] = ind2sub(size(pmap_lin),find(pmap_lin == max(max(pmap_lin))));
% Retrieving a waveform corresponding to the most powerful component
wavfm_rx = squeeze(rxWaveformMat(ind1,ind2,:));
% Plot the magnitude of the received signal
figure,
plot(abs(wavfm_rx))
box on
title('Received signal magnitude')
xlabel('Sample #')
ylabel('Magnitude')
%% Estimate CFO
% Set searching bandwidth with respect to subcarrier spacing:
searchBW = 10*TX_PRS_config.subcarrierSpacing;
% identify if PRS ID search is performed (full range of potential
% PRS IDs and corresponding reference waveform is used) OR known PRS ID is
% used
do_PRS_ID_search = false;
if do_PRS_ID_search
    [wavfm_rx, freqOffset, PRS_ID] = PRS_CFO_estimate(wavfm_rx,refWaveform,TX_PRS_config,searchBW,(0:62),true);
    % Retrieve the reference waveform from the PRS waveform bank based on the 
    %estimated PRS ID
    wavfm_rf = refWaveform(:,PRS_ID+1);
else
    % Retrieve PRS ID of the known TX beam corresponding to the most 
    % powerful component (based on beam sweepng sequence)
    PRS_ID = mod((NumTX-ind1+1),63)-1;
    % Retrieve the reference waveform from the PRS waveform bank based on the 
    %known PRS ID
    wavfm_rf = refWaveform(:,PRS_ID+1);
    [wavfm_rx, freqOffset] = PRS_CFO_estimate(wavfm_rx,wavfm_rf,TX_PRS_config,searchBW,PRS_ID,true);
end

%% Estimate coarse ToA
% Pad the received waveform if necessary to make it longer than the
% correlation reference signal; this is required to normalize xcorr
% behavior as it always pads the shorter input signal
T = size(wavfm_rx,1);
minlength = size(wavfm_rf,1);
if (T < minlength)
    wavfm_rx_pad = [wavfm_rx; zeros(minlength-T,1)];
    T = minlength;
else
    wavfm_rx_pad = wavfm_rx;
end
% Correlate received signal with the reference signal
refcorr = xcorr(wavfm_rx_pad,wavfm_rf);
mag = abs(refcorr(T:end));
% Find timing offset as a peak in the magnitudes of correlation
[~,offset] = max(mag);
% Plot the correlation function
figure
h = tiledlayout(1,1);
ax1 = axes(h);
ax2 = axes(h);
plot(ax1,(1:numel(mag)),mag)
plot(ax2,(1:numel(mag))./TX_PRS_config.SampleRate*c - d_est+d_cal,mag)
ax1.XLim = [1,numel(wavfm_rx)];
ax2.XLim = [1,numel(wavfm_rx)]./TX_PRS_config.SampleRate*c - d_est+d_cal;
ax1.XLabel.String='Correlation sample #';
ax2.XAxisLocation = 'top';
ax1.Box = 'off';
ax2.Box = 'off';
box on
ax2.XLabel.String = 'Range [m]';
ylabel('Correlation magnituda')
%% Display results
% Display the coarse range extimate (calibrated for the electronics delay): 
d = offset/TX_PRS_config.SampleRate*c - d_est+d_cal;
disp(['Coase range estimate (LoS): ',num2str(d),' m']);
disp(['True LoS range: ',num2str(norm(RX_pos(position_index,:)-TX_pos)),' m (subject to hand measurement errors)']);
