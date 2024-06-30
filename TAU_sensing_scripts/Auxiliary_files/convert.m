function convert_mat_to_csv(matFolder)
    % Specify the folder containing .mat files
    if nargin < 1
        matFolder = '';
    end

    % Get a list of all .mat files in the folder
    matFiles = dir(fullfile(matFolder, '*.mat'));

    % Loop over each .mat file
    for k = 1:length(matFiles)
        % Get the full path of the .mat file
        matFileName = fullfile(matFolder, matFiles(k).name);
        
        % Load the .mat file
        matData = load(matFileName);
        
        % Get the names of all variables in the .mat file
        varNames = fieldnames(matData);
        
        combinedData = [];
        variableNames = {};
        
        % Loop over each variable in the .mat file
        maxLength = 0;
        numericData = struct();
        for i = 1:length(varNames)
            varName = varNames{i};
            
            % Get the variable data
            data = matData.(varName);
            
            % Check if the variable is numeric or logical
            if isnumeric(data) || islogical(data)
                % Flatten the variable to a column vector if it's not already
                data = data(:);
                
                % Store the data and update the maximum length
                numericData.(varName) = data;
                maxLength = max(maxLength, length(data));
                variableNames{end+1} = varName; %#ok<SAGROW>
            elseif isstruct(data)
                % Handle struct by converting each field
                fieldNames = fieldnames(data);
                for j = 1:length(fieldNames)
                    fieldName = fieldNames{j};
                    fieldData = data.(fieldName);
                    if isnumeric(fieldData) || islogical(fieldData)
                        fieldData = fieldData(:);
                        combinedFieldName = strcat(varName, '_', fieldName);
                        numericData.(combinedFieldName) = fieldData;
                        maxLength = max(maxLength, length(fieldData));
                        variableNames{end+1} = combinedFieldName; %#ok<SAGROW>
                    else
                        warning(['Field ', fieldName, ' of variable ', varName, ' in file ', matFiles(k).name, ' is not numeric or logical. Skipping.'])
                    end
                end
            elseif iscell(data)
                warning(['Variable ', varName, ' in file ', matFiles(k).name, ' is a cell. Skipping.'])
            else
                warning(['Variable ', varName, ' in file ', matFiles(k).name, ' is not numeric or logical. Skipping.'])
            end
        end
        
        % Pad the data to ensure all variables have the same length
        for i = 1:length(variableNames)
            varName = variableNames{i};
            data = numericData.(varName);
            if length(data) < maxLength
                data = [data; NaN(maxLength - length(data), 1)];
            end
            combinedData = [combinedData, data];
        end
        
        % Create a .csv file name
        [~, name, ~] = fileparts(matFileName);
        csvFileName = fullfile(matFolder, [name, '.csv']);
        
        % Write the combined data to a .csv file with headers
        if ~isempty(combinedData)
            % Convert combinedData to table
            T = array2table(combinedData, 'VariableNames', variableNames);
            % Write the table to a CSV file
            writetable(T, csvFileName);
        end
    end

    disp('Conversion complete.')
end
