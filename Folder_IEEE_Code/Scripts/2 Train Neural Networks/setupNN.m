%% Setup Neural Network Configuration
% Author: Rafael Machado Peluzio
% Contact: rmpeluzio@gmail.com / 19999314029
% Date modified: 15-Jan-2026
% References: Based on similar scripts by Prof. P. M. Tasinaffo

function netOBJ = setupNN(options)
    % SETUPNN Creates a configuration structure for NN training.
    %
    % This function defines the hyperparameters, data sources, and integrator
    % settings. It uses Name-Value arguments for flexibility.
    
    arguments
        
        % --- Neural Network Specifications ---
        options.TrainingRatios (1,3) double {mustBeNumeric} = [0.7 0.15 0.15]
        options.DivideFcn (1,1) string = "dividerand"
        options.Topology (1,2) double = [30 5] % [Neurons, Layers] or [Width, Depth]
        options.MaxEpochs (1,1) double {mustBePositive} = 10000
        options.MaxTime (1,1) double {mustBePositive} = 3600
        options.MaxFail (1,1) double {mustBeInteger, mustBePositive} = 5
        options.MinGrad (1,1) double {mustBePositive} = 1e-10
        options.LearningRate (1,1) double {mustBePositive} = 0.2
        options.PerformFcn (1,1) string = "msereg"
        options.TrainingAlgorithm (1,1) string = "trainlm"
    end
    
    fprintf("Setting Up Neural Network ... ")

    %% 1. Initialize Structure
    NNSetup = struct();
    
    %% 2. NN Specifications Packing
    NNSetup.NNSpecs = struct();
    NNSetup.NNSpecs.trainingRatios = options.TrainingRatios;
    NNSetup.NNSpecs.divideFcn = options.DivideFcn;
    NNSetup.NNSpecs.topology = options.Topology;
    NNSetup.NNSpecs.maxEpochs = options.MaxEpochs;
    NNSetup.NNSpecs.maxTime = options.MaxTime;
    NNSetup.NNSpecs.maxFail = options.MaxFail;
    NNSetup.NNSpecs.min_grad = options.MinGrad;
    NNSetup.NNSpecs.lr = options.LearningRate;
    NNSetup.NNSpecs.performFcn = options.PerformFcn;
    NNSetup.NNSpecs.TrainingAlgorithm = options.TrainingAlgorithm;

    %% 3. Initialize Forward Neural Network Object
    
    % --- Topology ---
    hiddenLayerSizes = repmat(NNSetup.NNSpecs.topology(1), 1, NNSetup.NNSpecs.topology(2));
    netOBJ = feedforwardnet(hiddenLayerSizes,NNSetup.NNSpecs.TrainingAlgorithm);

    % --- Data Division ---
    netOBJ.divideFcn = NNSetup.NNSpecs.divideFcn;
    netOBJ.divideParam.trainRatio = NNSetup.NNSpecs.trainingRatios(1);
    netOBJ.divideParam.valRatio   = NNSetup.NNSpecs.trainingRatios(2); % Note CamelCase 'valRatio'
    netOBJ.divideParam.testRatio  = NNSetup.NNSpecs.trainingRatios(3);
    
    % --- Visualization ---
    netOBJ.trainParam.showWindow = true;

    % --- Performance Metric ---
    netOBJ.performFcn = NNSetup.NNSpecs.performFcn;

    % --- Hyperparameters ---
    netOBJ.trainParam.epochs   = NNSetup.NNSpecs.maxEpochs;
    netOBJ.trainParam.time     = NNSetup.NNSpecs.maxTime;
    netOBJ.trainParam.lr       = NNSetup.NNSpecs.lr;
    netOBJ.trainParam.min_grad = NNSetup.NNSpecs.min_grad;
    netOBJ.trainParam.max_fail = NNSetup.NNSpecs.maxFail;
    fprintf("Complete!\n")
end