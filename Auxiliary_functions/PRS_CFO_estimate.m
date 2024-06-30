function [rxWaveformFreqCorrected, varargout] = PRS_CFO_estimate(rxWaveform,refWaveform,TX_PRS_config,searchBW,varargin)
% Performs a search for central frequency offset (CFO) and PRS ID
%   (optionally).
% INPUTS:
%       rxWaveform - received waveform, vector N_RXsym x 1
%       refWaveform - reference waveform, vector N_RefSym x 1 or matrix N_RefSym x N_PRSid
%       TX_PRS_config - transmit/reference signal configuration file 
%       searchBW - bandwidth for the frequency offset search
%       prsIDlist - list for potential PRS IDs (if search is performed), or
%               known PRS ID (if search is not performed)
%   Optional input:
%       do_plot - indicator of plotting capability (true or false, false being default)
% OUTPUTS: 
%       rxWaveformFreqCorrected - frequency offset-corrected received
%           waveform
%       freqOffset - estimated frequency offset
%   Optional output:
%       prsID - found PRS ID (if search is performed)
%
if size(refWaveform,2) == 1
    doPRSSearch = false;
else
    doPRSSearch = true;
end
% Vector of potential PRS IDs to check against OR a known PRS ID
prsIDlist = varargin{1};
if numel(varargin) > 1
    do_plot = varargin{2};
else
    do_plot = false; 
end
%
% Set the CFO searching step
fshifts = (-searchBW:TX_PRS_config.subcarrierSpacing:searchBW) * 1e3 / 2; % Half subcarrier step
t = (0:size(rxWaveform,1)-1).' / TX_PRS_config.SampleRate;
% Calculate the correlation function between received and reference
% waveform, perform PRS ID (optional) and CFO search
if doPRSSearch
    peak_value = zeros(numel(fshifts),size(refWaveform,2));
    peak_index = zeros(numel(fshifts),size(refWaveform,2));
    for fIdx = 1:numel(fshifts)
        coarseFrequencyOffset = fshifts(fIdx);
        rxWaveformFreqCorrected = rxWaveform .* exp(-1i*2*pi*coarseFrequencyOffset*t);
        %         % Downsample to the minumum sampling rate to cover SSB bandwidth
        %         rxWaveformDS = resample(rxWaveformFreqCorrected,syncSR,rxSampleRate);
        T = numel(rxWaveform);
        for prsIdx = 1:size(refWaveform,2)
            refW = refWaveform(:,prsIdx);
            minlength = size(refWaveform,1);
            % Get the number of time samples T and receive antennas R in the
            % waveform
            if (T < minlength)
                waveformPad = [rxWaveformFreqCorrected; zeros(minlength-T,1)];
                T = minlength;
            else
                waveformPad = rxWaveformFreqCorrected;
            end
            refcorr = xcorr(waveformPad,refW);
            corr = abs(refcorr(T:end));
            
            [peak_value(fIdx,prsIdx),peak_index(fIdx,prsIdx)] = max(corr);
            peak_index(fIdx,prsIdx) = peak_index(fIdx,prsIdx) + TX_PRS_config.SymbolLengths(1);
            
        end
    end
else
    peak_value = zeros(numel(fshifts),1);
    peak_index = zeros(numel(fshifts),1);
    for fIdx = 1:numel(fshifts)
        coarseFrequencyOffset = fshifts(fIdx);
        rxWaveformFreqCorrected = rxWaveform .* exp(-1i*2*pi*coarseFrequencyOffset*t);
        %         % Downsample to the minumum sampling rate to cover SSB bandwidth
        %         rxWaveformDS = resample(rxWaveformFreqCorrected,syncSR,rxSampleRate);
        T = numel(rxWaveform);
        minlength = size(refWaveform,1);
        % Get the number of time samples T and receive antennas R in the
        % waveform
        if (T < minlength)
            waveformPad = [rxWaveformFreqCorrected; zeros(minlength-T,1)];
            T = minlength;
        else
            waveformPad = rxWaveformFreqCorrected;
        end
        refcorr = xcorr(waveformPad,refWaveform);
        corr = abs(refcorr(T:end));
        [peak_value(fIdx),peak_index(fIdx)] = max(corr);
        peak_index(fIdx) = peak_index(fIdx) + TX_PRS_config.SymbolLengths(1);
    end
end
% Determine PRS ID and coarse frequency offset by finding the strongest
% correlation
[fIdx,prsIdx] = find(peak_value==max(peak_value(:)));
coarseFrequencyOffset = fshifts(fIdx(1));

if do_plot
    % Plot PRS correlations and selected PRS ID
    figure;
    hold on;
    plot(fshifts/1e3,peak_value);
    title('PRS Correlations versus Frequency Offset');
    ylabel('Magnitude');
    xlabel('Frequency Offset (kHz)');
    plot(coarseFrequencyOffset/1e3,peak_value(fIdx(1),prsIdx(1)),'kx','LineWidth',2,'MarkerSize',8);
%     legends = "PRS ID" + num2cell(prsIDlist);
%     legend([legends "coarse $\Delta_f$ = " + num2str(coarseFrequencyOffset) + ", PRS ID = " + num2str(prsID)],'Location','SouthEast');
%     lgd = legend;
%     lgd.Interpreter = 'latex';
end
% Apply the coarse CFO correction
rxWaveformFreqCorrected = rxWaveform .* exp(-1i*2*pi*coarseFrequencyOffset*t);

freqOffset = coarseFrequencyOffset;
varargout{1} = freqOffset;
if doPRSSearch
    prsID = prsIDlist(prsIdx);
    varargout{2} = prsID;
end
end