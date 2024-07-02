import os
import numpy as np
from scipy.io import loadmat

def load_IQ_data(measfolder, position):

    # Load measurement parameters
    measParam = loadmat(os.path.join(measfolder, 'measParam.mat'))
    BlockSize = measParam['BlockSize'][0][0]
    TX_angles = measParam['TX_angles'].flatten()
    RX_angles = measParam['RX_angles'].flatten()

    # Load I and Q data files
    filelist_I = [f for f in os.listdir(measfolder) if f.startswith(f'pos{position}_I')]
    filename_I = os.path.join(measfolder, filelist_I[0])
    filelist_Q = [f for f in os.listdir(measfolder) if f.startswith(f'pos{position}_Q')]
    filename_Q = os.path.join(measfolder, filelist_Q[0])

    I = np.fromfile(filename_I, dtype=np.double)
    Q = np.fromfile(filename_Q, dtype=np.double)
    iqData = I + 1j * Q

    # Reshape and permute data
    data_sorted = iqData.reshape((BlockSize, len(TX_angles), len(RX_angles)))
    power = 10 * np.log10(1000 / 50 * np.var(data_sorted, axis=0))
    data_sorted = np.transpose(data_sorted, (1, 2, 0))

    # Translate the angles to the local reference frames of TX and RX used in the paper
    data_sorted = data_sorted[::-1, ::-1, :]
    TX_angles = -TX_angles[::-1]
    RX_angles = -RX_angles[::-1]

    return data_sorted, power, TX_angles, RX_angles
