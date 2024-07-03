import os
import pickle
import numpy as np
from scipy.io import loadmat

def load_IQ_data(measfolder, position):
    # Load measurement parameters
    measParam = loadmat(os.path.join(measfolder, 'measParam.mat'))
    BlockSize = measParam['BlockSize'][0][0]
    TX_angles = measParam['TX_angles'].flatten()
    RX_angles = measParam['RX_angles'].flatten()
    
    
    # Load I and Q data pickle files
    filename_I = os.path.join(measfolder, f'I_data_{position}.pkl')
    filename_Q = os.path.join(measfolder, f'Q_data_{position}.pkl')


    # Load data from pickle files
    with open(filename_I, 'rb') as file:
        I = pickle.load(file)
    with open(filename_Q, 'rb') as file:
        Q = pickle.load(file)

    
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