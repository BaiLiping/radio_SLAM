function [data_sorted,power,TX_angles,RX_angles] = load_IQ_data(measfolder,position)
% Function to load the measured I/Q data from the original binary files
% INPUTS:
%       measfolder - path to the folder containing binary files (ending
%                    with '\'),
%       position - RX position number.
% OUTPUTS:
%       data_sorted - 3D matrix containing received complex samples.
%                   Dimensions are: [TX direction number x RX direction 
%                   number x I/Q sample number],
%       power - estimates power in the channel,
%       TX_angles - TX main beam directions for each measurement,
%       RX_angles - RX main beam directions for each measurement.
%       
% ! Note that this function relies on the I/Q binary files naming convention.
% If binary file names changed, edit function accordingly
%

load(strcat(measfolder,'measParam.mat')); %

filelist = dir(fullfile(measfolder, ['pos',num2str(position),'_I*']));
filename_I = fullfile(measfolder, filelist(1).name);
filelist = dir(fullfile(measfolder, ['pos',num2str(position),'_Q*']));
filename_Q = fullfile(measfolder, filelist(1).name);
fid = fopen(filename_I, 'r', 's');
[I, N] = fread(fid, Inf, 'double');
fclose(fid);

fid = fopen(filename_Q, 'r', 's');
[Q, N] = fread(fid, Inf, 'double');
fclose(fid);
iqData = I+1i*Q;

data_sorted = reshape(iqData,BlockSize,numel(TX_angles),numel(RX_angles));
power =10*log10(1000/50*squeeze(var(data_sorted)));
% Permute for convenience of use (original dimensions are [samples,TX index, RX index]): 
data_sorted = permute(data_sorted,[2,3,1]);
% Translate the angles to the local reference frames of TX and RX used in the paper:
data_sorted = data_sorted(end:-1:1,end:-1:1,:);
TX_angles = -TX_angles(end:-1:1);
RX_angles = -RX_angles(end:-1:1);

end