import numpy as np
import matplotlib.pyplot as plt
from scipy.io import loadmat
from scipy.signal import correlate
from scipy.constants import c
from PRS_CFO_estimate import PRS_CFO_estimate
from load_IQ_data import load_IQ_data

# Load and plot the map of the measurement environment
tx_rx_positions = loadmat('/home/bailiping/Desktop/radio_SLAM/Auxiliary_files/TX_RX_positions.mat')
TX_pos = tx_rx_positions['TX_pos']
RX_pos = tx_rx_positions['RX_pos']

# Load waveforms and parameters for I/Q data processing
measfolder =  '/home/bailiping/Desktop/Radio_SLAM_data/'

# Load OFDM carrier and PRS signal configuration parameters
prs_config = loadmat('/home/bailiping/Desktop/radio_SLAM/Auxiliary_files/Transmitted_PRS_config.mat')
TX_PRS_config = prs_config['TX_PRS_config']

# Load reference PRS waveforms
prs_waveforms = loadmat('/home/bailiping/Desktop/radio_SLAM/Auxiliary_files/PRS_waveform_bank_PRS_IDs_0_62.mat')
refWaveform = prs_waveforms['refWaveform']

# Load ToA/range calibration terms
calibration_data = loadmat('/home/bailiping/Desktop/radio_SLAM/Auxiliary_files/ToA_calibration_16_17_03_2023.mat')
d_est = calibration_data['d_est']
d_cal = calibration_data['d_cal']

# Choose the LoS component
position_index = 1
rxWaveformMat, power, TX_angles, RX_angles = load_IQ_data(measfolder, position_index)
NumTX = rxWaveformMat.shape[0]

# Calculate the power and plot power map
pmap_lin = np.mean(np.abs(rxWaveformMat)**2, axis=2) * 14
pmap = 10 * np.log10(pmap_lin)


# Plot power map (linear scale) with cleaned data
plt.figure()
plt.imshow(pmap_lin, aspect='auto', extent=[RX_angles.min(), RX_angles.max(), TX_angles.min(), TX_angles.max()], origin='lower')
plt.colorbar(label='Power [mW]')
plt.xlabel('θ, AoA [°]')
plt.ylabel('φ, AoD [°]')
plt.title(f'Power map [mW], position #{position_index}')
plt.grid(False)
plt.clim(vmin=0, vmax=pmap_lin.max())  # Adjust color limits for better contrast
plt.show()

# Plot power map (log scale) with cleaned data
plt.figure()
plt.imshow(pmap, aspect='auto', extent=[RX_angles.min(), RX_angles.max(), TX_angles.min(), TX_angles.max()], origin='lower')
plt.colorbar(label='Power [dBm]')
plt.xlabel('θ, AoA [°]')
plt.ylabel('φ, AoD [°]')
plt.title(f'Power map [dBm], position #{position_index}')
plt.grid(True)
plt.clim(vmin=-55, vmax=-25)  # Adjust color limits for better contrast
plt.show()

# Extras: estimate CFO and the coarse time delay for the most powerful component
ind1, ind2 = np.unravel_index(np.argmax(pmap_lin, axis=None), pmap_lin.shape)
wavfm_rx = rxWaveformMat[ind1, ind2, :]

# Plot the magnitude of the received signal
plt.figure()
plt.plot(np.abs(wavfm_rx))
plt.title('Received signal magnitude')
plt.xlabel('Sample #')
plt.ylabel('Magnitude')
plt.grid(True)
plt.show()

# Estimate CFO
searchBW = 10 * TX_PRS_config['subcarrierSpacing'][0][0]
do_PRS_ID_search = False
if do_PRS_ID_search:
    wavfm_rx, freqOffset, PRS_ID = PRS_CFO_estimate(wavfm_rx, refWaveform, TX_PRS_config, searchBW, range(63), True)
    wavfm_rf = refWaveform[:, PRS_ID]
else:
    PRS_ID = (NumTX - ind1) % 63
    wavfm_rf = refWaveform[:, PRS_ID]
    wavfm_rx, freqOffset = PRS_CFO_estimate(wavfm_rx, wavfm_rf, TX_PRS_config, searchBW, PRS_ID, True)

# Estimate coarse ToA
T = len(wavfm_rx)
minlength = len(wavfm_rf)
if T < minlength:
    wavfm_rx_pad = np.concatenate([wavfm_rx, np.zeros(minlength - T)])
else:
    wavfm_rx_pad = wavfm_rx

refcorr = correlate(wavfm_rx_pad, wavfm_rf)
mag = np.abs(refcorr[len(wavfm_rx_pad) - 1:])
offset = np.argmax(mag)

# Plot the correlation function
fig, ax1 = plt.subplots()
ax2 = ax1.twiny()
ax1.plot(range(len(mag)), mag)
ax2.plot(np.arange(len(mag)) / TX_PRS_config['SampleRate'][0][0] * c - d_est + d_cal, mag)
ax1.set_xlim([1, len(wavfm_rx)])
ax2.set_xlim([1, len(wavfm_rx)] / TX_PRS_config['SampleRate'][0][0] * c - d_est + d_cal)
ax1.set_xlabel('Correlation sample #')
ax2.set_xlabel('Range [m]')
ax1.set_ylabel('Correlation magnitude')
ax1.grid(True)
plt.show()

# Display results
d = offset / TX_PRS_config['SampleRate'][0][0] * c - d_est + d_cal
true_distance = np.linalg.norm(RX_pos[position_index, :] - TX_pos)
print(f'Coarse range estimate (LoS): {d} m')
print(f'True LoS range: {true_distance} m (subject to hand measurement errors)')
