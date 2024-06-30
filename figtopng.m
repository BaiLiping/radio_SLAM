% MATLAB script to convert .fig file to .png file
function convertFigToPng(inputFigFile, outputPngFile)
    % Open the .fig file
    figHandle = openfig(inputFigFile);
    
    % Save the figure as a .png file
    saveas(figHandle, outputPngFile);
    
    % Close the figure
    close(figHandle);
end

% Example usage:
convertFigToPng('kampusarena_map.fig', 'kampusarena_map.png');
