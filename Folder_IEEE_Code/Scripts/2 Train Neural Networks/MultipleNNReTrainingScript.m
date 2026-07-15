%% Neural Network Re Training Script
% Author: Rafael Machado Peluzio
% Contact: rmpeluzio@gmail.com / 19999314029
% Date modified: 27/01/2026
% References: Based on similar scripts by Prof. P. M. Tasinaffo

clc; clear; close all; 

%% Config NN re-training characteristics

% Here we're using the Matlab eval function to update the NN's setup, so
% the syntax is as presented in the "newParam" line

% List of NN training parameters from the setupNN script
% options.TrainingRatios (1,3) double {mustBeNumeric} = [0.7 0.15 0.15]
% options.DivideFcn (1,1) string = "dividerand"
% options.Topology (1,2) double = [30 5] % [Neurons, Layers] or [Width, Depth]
% options.MaxEpochs (1,1) double {mustBePositive} = 10000
% options.MaxTime (1,1) double {mustBePositive} = 3600
% options.MaxFail (1,1) double {mustBeInteger, mustBePositive} = 5
% options.MinGrad (1,1) double {mustBePositive} = 1e-10
% options.LearningRate (1,1) double {mustBePositive} = 0.2
% options.PerformFcn (1,1) string = "msereg"
% options.TrainingAlgorithm (1,1) string = "trainlm"

newParam = {'max_fail = 10', 'time = 3600'}; %If no changes needed, create empty cell array
ModelType = "ETUNI";
ModelSubTypeSource = "None"; % None if no option is selected
ModelSubTypeDestination = 'ReTrain1';
newTrainingDataset = "202607150056_HeatExchanger_SyntheticData_100000.mat";
% Get List of Existing NNs
fprintf("### Executing Neural Network Re-Training Script ###\n");

% List every NN Model available for Re-Training
% Get NN Name
pattern = '\(R(.*?)\)';
tokens = regexp(version, pattern, 'tokens');
matlabVersion = tokens{:}{:};
if ModelSubTypeSource ~= "None"
    path = ['Folder_IEEE_Code\NN_Models\',char(ModelType),'\',char(ModelSubTypeSource)];
else
    path = ['Folder_IEEE_Code\NN_Models\',char(ModelType)];
end

% Get a list of all .mat files within specified folder
targetDir = fullfile(pwd, path);
fileList = dir(fullfile(targetDir, '*.mat'));
[~, sortedIdx] = sort({fileList.name});
fileList = fileList(sortedIdx);
clear targetDir matlabVersion OldNN_FileName pattern tokens path sortedIdx;

% List every NN Model already Re-Trained
% Get NN Name
pattern = '\(R(.*?)\)';
tokens = regexp(version, pattern, 'tokens');
matlabVersion = tokens{:}{:};
if ModelSubTypeDestination ~= "None"
    path = ['Folder_IEEE_Code\NN_Models\',char(ModelType),'\',char(ModelSubTypeDestination)];
else
    path = ['Folder_IEEE_Code\NN_Models\',char(ModelType),'\Retraining_Folder'];
end

% Get a list of all .mat files within specified folder
targetDir = fullfile(pwd, path);
fileListDestination = dir(fullfile(targetDir, '*.mat'));
[~, sortedIdx] = sort({fileListDestination.name});
fileListDestination = fileListDestination(sortedIdx);
clear targetDir matlabVersion OldNN_FileName pattern tokens path sortedIdx;

% Add "Topology" feature to fileList structs
pattern = '_(\d+W\d+D)_';

for i = 1:length(fileList)
    % Extract the match using tokens
    match = regexp(fileList(i).name, pattern, 'tokens');
    
    if ~isempty(match)
        % match{1}{1} accesses the first capture group of the first match
        fileList(i).Topology = match{1}{1};
    else
        % Handling cases where the pattern might not be found
        fileList(i).Topology = 'Unknown';
        warning('Pattern not found in entry %d: %s', i, fileList(i).name);
    end
end
for i = 1:length(fileListDestination)

    % Extract the match using tokens
    match = regexp(fileListDestination(i).name, pattern, 'tokens');
    
    if ~isempty(match)
        % match{1}{1} accesses the first capture group of the first match
        fileListDestination(i).Topology = match{1}{1};
    else
        % Handling cases where the pattern might not be found
        fileListDestination(i).Topology = 'Unknown';
        warning('Pattern not found in entry %d: %s', i, fileListDestination(i).name);
    end
end

% Remove NNs already trained from list
try
    destTopologies = {fileListDestination.Topology};
    isDuplicate = ismember({fileList.Topology}, destTopologies);
    fileList(isDuplicate) = [];
end
%% ReTraining
for fileNum = 1:length(fileList)       
    % Setup
    
    % Load current file
    load(fileList(fileNum).name);
    
    % Replace previous files
    trainingDataSet = newTrainingDataset;

    % Delete files that must not be kept
    clear newTrainingDataSet realPerformanceStruct

    % Data Loading
    fprintf("Collecting input and output patterns from file ... ")
    dataSet = load(newTrainingDataset);
    try
        trainingDataSetDescription = dataSet.dataDescription;
    end
    fprintf("done\n")
    
    %% Training
    
    % Update re-training counter
    if exist('reTrainCounter') == 0 %Hasn't been retrained yet, first re-training
        reTrainCounter = 1;
    else
        reTrainCounter = reTrainCounter +1;
    end

    % Update NN training parameters if specified
    for i = 1:length(newParam)
        eval("NN.trainParam."+string(newParam{i})+";");
    end

    % Train NN
    fprintf('Training NN ... ')
    tic;
    if ModelType == "ETUNI"
        [NN, trNN]=train(NN,gpuArray(dataSet.P_data),gpuArray(dataSet.T_data(2,:)),'useGPU','yes');
    elseif ModelType =="NARX"
        [NN, trNN]=train(NN,gpuArray(dataSet.P_data),gpuArray(dataSet.T_data(1,:)),'useGPU','yes');
    else 
        error("Invalid Model Type informed")
    end
    total_time = toc;
    fprintf('done\n')
    
    %% Saving Results
    
    fprintf("Saving Data ... ");

    % Defining new name based on the previous one
    OldNN_FileName = string(fileList(fileNum).name);
    [~, OldNN_FileName, ~] = fileparts(OldNN_FileName);
    
    % 1. Generate new timestamp (Format: YYYYMMDD_HHMM)
    timeStampDay = datestr(now, 'yyyymmdd');
    timeStampHour = datestr(now, 'HHMM');
    newTimestamp = upper(string(datetime('now', 'Format', 'yyyyMMdd_HHmm')));
    
    timestampPattern = '\d{8}_\d{4}';
    retrainPattern = '_ReTrain\d+';
    tempName = regexprep(OldNN_FileName, timestampPattern, newTimestamp);
    newSuffix = "_ReTrain" + string(reTrainCounter);
    
    if contains(tempName, "ReTrain", 'IgnoreCase', true)
        NewFileName = regexprep(tempName, retrainPattern, newSuffix);
    else
        NewFileName = tempName + newSuffix;
    end

    try
        step = config.step;
    end
    % Save the Workspace (.mat)
    save(NewFileName,"NN", "trNN","step", "trainingDataSet","trainingDataSetDescription");
    fprintf('done\n');
    
    % Generating Simulink Block (.slx)
    fprintf('Generating Simulink Block ... ');
    
    sysHandle = gensim(NN, 'InputMode', 'port', 'OutputMode', 'port');
    slxFileName = [char(NewFileName), '.slx'];
    
    % Set model to use fixed step
    set_param(sysHandle, 'SolverType', 'Fixed-step');
    set_param(sysHandle, 'FixedStep', string(step));
    
    % Save the system to disk
    save_system(sysHandle, slxFileName);
    
    % Close the system to clean up the desktop
    close_system(slxFileName);
    
    fprintf("done\n")

end