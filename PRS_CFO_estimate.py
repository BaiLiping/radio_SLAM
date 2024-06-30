import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import correlate

def PRS_CFO_estimate(rxWaveform, refWaveform, TX_PRS_config, searchBW, prsIDlist, do_plot=False):
    """
    Performs a search for central frequency offset (CFO) and PRS ID (optionally).
    
    INPUTS:
        rxWaveform - received waveform, vector N_RXsym x 1
        refWaveform - reference waveform, vector N_RefSym x 1 or matrix N_RefSym x N_PRSid
        TX_PRS_config - transmit/reference signal configuration file
        searchBW - bandwidth for the frequency offset search
        prsIDlist - list for potential PRS IDs (if search is performed), or known PRS ID (if search is not performed)
        do_plot - indicator of plotting capability (True or False, False being default)
        
    OUTPUTS:
        rxWaveformFreqCorrected - frequency offset-corrected received waveform
        freqOffset - estimated frequency offset
        
    Optional output:
        prsID - found PRS ID (if search is performed)
    """
    
    if refWaveform.shape[1] == 1:
        doPRSSearch = False
    else:
        doPRSSearch = True

    # Set the CFO searching step
    fshifts = np.arange(-searchBW, searchBW + TX_PRS_config['subcarrierSpacing'][0][0], TX_PRS_config['subcarrierSpacing'][0][0]) * 1e3 / 2
    t = np.arange(rxWaveform.size) / TX_PRS_config['SampleRate'][0][0]
    
    peak_value = np.zeros((fshifts.size, refWaveform.shape[1])) if doPRSSearch else np.zeros(fshifts.size)
    peak_index = np.zeros((fshifts.size, refWaveform.shape[1])) if doPRSSearch else np.zeros(fshifts.size)

    for fIdx in range(fshifts.size):
        coarseFrequencyOffset = fshifts[fIdx]
        rxWaveformFreqCorrected = rxWaveform * np.exp(-1j * 2 * np.pi * coarseFrequencyOffset * t)
        T = rxWaveform.size
        
        if doPRSSearch:
            for prsIdx in range(refWaveform.shape[1]):
                refW = refWaveform[:, prsIdx]
                minlength = refWaveform.shape[0]
                
                if T < minlength:
                    waveformPad = np.concatenate([rxWaveformFreqCorrected, np.zeros(minlength - T)])
                    T = minlength
                else:
                    waveformPad = rxWaveformFreqCorrected
                
                refcorr = correlate(waveformPad, refW)
                corr = np.abs(refcorr[T-1:])
                peak_value[fIdx, prsIdx], peak_index[fIdx, prsIdx] = corr.max(), corr.argmax() + TX_PRS_config['SymbolLengths'][0][0]
        else:
            minlength = refWaveform.size
            
            if T < minlength:
                waveformPad = np.concatenate([rxWaveformFreqCorrected, np.zeros(minlength - T)])
                T = minlength
            else:
                waveformPad = rxWaveformFreqCorrected
                
            refcorr = correlate(waveformPad, refWaveform)
            corr = np.abs(refcorr[T-1:])
            peak_value[fIdx], peak_index[fIdx] = corr.max(), corr.argmax() + TX_PRS_config['SymbolLengths'][0][0]

    fIdx, prsIdx = np.unravel_index(np.argmax(peak_value, axis=None), peak_value.shape)
    coarseFrequencyOffset = fshifts[fIdx]

    if do_plot:
        plt.figure()
        plt.plot(fshifts / 1e3, peak_value)
        plt.title('PRS Correlations versus Frequency Offset')
        plt.ylabel('Magnitude')
        plt.xlabel('Frequency Offset (kHz)')
        plt.plot(coarseFrequencyOffset / 1e3, peak_value[fIdx, prsIdx] if doPRSSearch else peak_value[fIdx], 'kx', linewidth=2, markersize=8)
        plt.show()

    rxWaveformFreqCorrected = rxWaveform * np.exp(-1j * 2 * np.pi * coarseFrequencyOffset * t)
    freqOffset = coarseFrequencyOffset

    if doPRSSearch:
        prsID = prsIDlist[prsIdx]
        return rxWaveformFreqCorrected, freqOffset, prsID
    else:
        return rxWaveformFreqCorrected, freqOffset
