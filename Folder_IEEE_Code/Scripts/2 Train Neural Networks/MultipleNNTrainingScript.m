%% Neural Network Training Script
% Author: Rafael Machado Peluzio
% Contact: rmpeluzio@gmail.com / 19999314029
% Date modified: 15/Jul/2026
% References: Based on similar scripts by Prof. P. M. Tasinaffo
% Code generated using the Gemini LLM tool for efficiency. Entire code was conceptualized, 
% revised and implemented by the author.

clc; clearvars; close all; 
fprintf('### Executing Neural Network Batch Training Script ###\n');

%% ========================================================================
%  1. GLOBAL SETUP & DATA LOADING
%  ========================================================================

% --- Static Configuration ---
config = struct();
config.NNType = "ETUNI"; %ETUNI or NARX
config.modelName = "NN";
config.dataSetName = "202607150056_HeatExchanger_SyntheticData_100000.mat";
% --- Data Loading ---
fprintf('Collecting input and output patterns from file... ');
try
    dataSet = load(config.dataSetName);
    config.step = dataSet.dataDescription.StepSize;
    % Pre-allocate GPU arrays once to avoid overhead during the loop
    gpu_P_data = gpuArray(dataSet.P_data);
    
    if config.NNType == "ETUNI"
        gpu_T_data = gpuArray(dataSet.T_data(2,:));
    elseif config.NNType == "NARX"
        gpu_T_data = gpuArray(dataSet.T_data(1,:));
    else
        error("config.NNType with invalid value");
    end
    fprintf('done\n');
catch ME
    error('Data file not found. Ensure the .mat file is in the current directory: %s', ME.message);
end

%% ========================================================================
%  2. BATCH TRAINING LOOP
%  ========================================================================
W_list = [30];
D_list = [1 2];
for D_index = 1:length(D_list)
    for W_index = 1:length(W_list)
        W = W_list(W_index);
        D = D_list(D_index);
        fprintf('\n--- Training Topology: Width = %d, Depth = %d ---\n', W, D);
        
        % --- NN Initialization ---
        % Note: Ensure your setupNN function is configured to accept Name-Value pairs
        NN = setupNN('Topology', [W D], 'MaxTime', 3600);
        
        % --- Training ---
        fprintf('Training NN on GPU... ');
        tic;
        [NN, trNN] = train(NN, gpu_P_data, gpu_T_data, 'useGPU', 'yes');
        total_time = toc;
        fprintf('done in %.2f seconds\n', total_time);
        
        %% ========================================================================
        %  3. SAVING RESULTS & EXPORTING MODEL
        %  ========================================================================
        fprintf('Saving Data... ');
        
        % --- Construct the Filename ---
        % Format: NN_RafaelPeluzio_ETUNI_YYYYMMDD_WxD_NiMo
        currentTime   = datetime('now');
        timeStampDay  = char(datetime(currentTime, 'Format', 'yyyyMMdd'));
        timeStampHour = char(datetime(currentTime, 'Format', 'HHmm'));
        
        baseName = sprintf('%s_%s_%s_%s_%s_%dW%dD_%dIn%dOut', ...
            "NN",config.NNType, config.modelName, timeStampDay, timeStampHour, ...
            NN.layers{1}.size, NN.numLayers - 1, NN.inputs{1}.size, NN.outputs{end}.size);
        
        matFileName = [baseName, '.mat'];
        
        % Save ONLY essential variables to prevent storage bloat
        save(matFileName, 'NN', 'trNN', 'config', 'total_time');
        fprintf('done. Saved to %s\n', matFileName);
        
        % --- Generating Simulink Block (.slx) ---
        fprintf('Generating Simulink Block... ');
        sysHandle = gensim(NN, 'InputMode', 'port', 'OutputMode', 'port');
        slxFileName = [baseName, '.slx'];
        
        % Set model to use fixed step
        set_param(sysHandle, 'SolverType', 'Fixed-step');
        set_param(sysHandle, 'FixedStep', config.step);
        
        % Save the system to disk
        save_system(sysHandle, slxFileName);
        
        % Close the system to clean up the desktop and free memory
        close_system(slxFileName);
        fprintf('done. Simulink model saved.\n');
        
    end
end

fprintf('\n### Batch Training Execution Completed Successfully ###\n');