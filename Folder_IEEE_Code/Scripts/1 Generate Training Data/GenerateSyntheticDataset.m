%% System Identification of an Aeronautical Application Precooler Heat Exchanger using Neural Networks in an E-TUNI configuration
% Author: Rafael Peluzio
% Contact: rmpeluzio@gmail.com / https://www.linkedin.com/in/rafael-peluzio/
% Date modified: 15/Jul/2026
% Description: Generates synthetic training data by executing a Simulink model 
% of a Precooler Heat Exchanger under various randomly generated input conditions.
% Evaluates subsets with different frequency limits to thoroughly excite the system dynamics.

% Code generated using the Gemini LLM tool for efficiency. Entire code was conceptualized, 
% revised and implemented by the author.

clc; clearvars; close all; 

%% ========================================================================
%  1. DATA GENERATION CONFIGURATION
%  ========================================================================
% --- General Settings ---
modelName      = 'HX_Simulink_Model';
frequency      = 200;               % Hz
step           = 1 / frequency;     % Integration step
fixedStepValue = step;
K1_user        = 0.00767;           % Added to configure the Simulink model

% --- Meta-Parameters Definition ---
dataDescription = struct();
dataDescription.T_data_Row1      = "Future value of Tpc_K";
dataDescription.T_data_Row2      = "Future Mean Derivative of Tpc_K";
dataDescription.StepType         = "Fixed";
dataDescription.StepSize         = string(step);
dataDescription.P_data_Row1      = "Tpc_K";
dataDescription.P_data_Row2      = "Bld_In_T_K";
dataDescription.P_data_Row3      = "Bld_Flow_ppm";
dataDescription.P_data_Row4      = "RAM_In_T_K";
dataDescription.P_data_Row5      = "RAM_Flow_ppm";
dataDescription.DataGeneration_DataType       = "Synthetic";
dataDescription.DataGeneration_ReferenceModel = "OnlyPreCooler_WirhqLossTc.slx";
dataDescription.DataGeneration_Inputs         = "RandomSinesAdjustedToLimits with 5 different subsections for the limits. 50 simulations of 10s and 2.5s";
dataDescription.DataGeneration_Inputs_numWaves= 4;
dataDescription.DataGeneration_NumSubSections = 5;

% Subsection 1 Limits
dataDescription.DataGeneration_Subsect1_Inputs_Limits_PreClr_Bld_Flow = [0 100];
dataDescription.DataGeneration_Subsect1_Inputs_Limits_PreClr_Bld_In_T = [350 750];
dataDescription.DataGeneration_Subsect1_Inputs_Limits_PreClr_Ram_Flow = [0 100];
dataDescription.DataGeneration_Subsect1_Inputs_Limits_PreClr_Fan_In_T = [250 350];
dataDescription.DataGeneration_Subsect1_Inputs_Limits_PreClr_Tpc_T    = [250 750];
dataDescription.DataGeneration_Subsect1_NumDatapoints = "100000";

% Subsection 2 Limits
dataDescription.DataGeneration_Subsect2_Inputs_Limits_PreClr_Bld_Flow = [0 100];
dataDescription.DataGeneration_Subsect2_Inputs_Limits_PreClr_Bld_In_T = [350 750];
dataDescription.DataGeneration_Subsect2_Inputs_Limits_PreClr_Ram_Flow = [0 10];
dataDescription.DataGeneration_Subsect2_Inputs_Limits_PreClr_Fan_In_T = [250 350];
dataDescription.DataGeneration_Subsect2_Inputs_Limits_PreClr_Tpc_T    = [250 750];
%dataDescription.DataGeneration_Subsect2_NumDatapoints = "25000";
dataDescription.DataGeneration_Subsect2_NumDatapoints = "0";

% Subsection 3 Limits
dataDescription.DataGeneration_Subsect3_Inputs_Limits_PreClr_Bld_Flow = [0 100];
dataDescription.DataGeneration_Subsect3_Inputs_Limits_PreClr_Bld_In_T = [350 750];
dataDescription.DataGeneration_Subsect3_Inputs_Limits_PreClr_Ram_Flow = [0 1];
dataDescription.DataGeneration_Subsect3_Inputs_Limits_PreClr_Fan_In_T = [250 350];
dataDescription.DataGeneration_Subsect3_Inputs_Limits_PreClr_Tpc_T    = [250 750];
%dataDescription.DataGeneration_Subsect3_NumDatapoints = "25000";
dataDescription.DataGeneration_Subsect3_NumDatapoints = "0";

% Subsection 4 Limits
dataDescription.DataGeneration_Subsect4_Inputs_Limits_PreClr_Bld_Flow = [0 10];
dataDescription.DataGeneration_Subsect4_Inputs_Limits_PreClr_Bld_In_T = [350 750];
dataDescription.DataGeneration_Subsect4_Inputs_Limits_PreClr_Ram_Flow = [0 100];
dataDescription.DataGeneration_Subsect4_Inputs_Limits_PreClr_Fan_In_T = [250 350];
dataDescription.DataGeneration_Subsect4_Inputs_Limits_PreClr_Tpc_T    = [250 750];
%dataDescription.DataGeneration_Subsect4_NumDatapoints = "25000";
dataDescription.DataGeneration_Subsect4_NumDatapoints = "0";

% Subsection 5 Limits
dataDescription.DataGeneration_Subsect5_Inputs_Limits_PreClr_Bld_Flow = [0 1];
dataDescription.DataGeneration_Subsect5_Inputs_Limits_PreClr_Bld_In_T = [350 750];
dataDescription.DataGeneration_Subsect5_Inputs_Limits_PreClr_Ram_Flow = [0 100];
dataDescription.DataGeneration_Subsect5_Inputs_Limits_PreClr_Fan_In_T = [250 350];
dataDescription.DataGeneration_Subsect5_Inputs_Limits_PreClr_Tpc_T    = [250 750];
%dataDescription.DataGeneration_Subsect5_NumDatapoints = "25000";
dataDescription.DataGeneration_Subsect5_NumDatapoints = "0";

%% ========================================================================
%  2. SUBSET ARCHITECTURE & STRUCTURING
%  ========================================================================
% --- Subset 1 Configuration ---
subset1 = struct();
subset1.numSimulations = 250/5; 
subset1.simTime        = 10; % seconds
subset1.timeVector     = (0:step:subset1.simTime)'; 
subset1.limits.PreClr_Bld_Flow = [0 100];   % ppm
subset1.limits.PreClr_Bld_In_T = [350 750]; % Kelvin
subset1.limits.PreClr_Ram_Flow = [0 100];   % ppm
subset1.limits.PreClr_Fan_In_T = [250 350]; % Kelvin
subset1.limits.PreClr_Tpc_T    = [250 750]; % Kelvin Min(Ram,Bld) & Max(Ram,Bld)

% --- Subset 2 Configuration ---
subset2 = struct();
%subset2.numSimulations = 250/5;
subset2.numSimulations = 0;
subset2.simTime        = 2.5; 
subset2.timeVector     = (0:step:subset2.simTime)'; 
subset2.limits.PreClr_Bld_Flow = [0 100]; 
subset2.limits.PreClr_Bld_In_T = [350 750]; 
subset2.limits.PreClr_Ram_Flow = [0 10]; 
subset2.limits.PreClr_Fan_In_T = [250 350]; 
subset2.limits.PreClr_Tpc_T    = [250 750]; 

% --- Subset 3 Configuration ---
subset3 = struct();
%subset3.numSimulations = 250/5;
subset3.numSimulations = 0;
subset3.simTime        = 2.5; 
subset3.timeVector     = (0:step:subset3.simTime)'; 
subset3.limits.PreClr_Bld_Flow = [0 100]; 
subset3.limits.PreClr_Bld_In_T = [350 750]; 
subset3.limits.PreClr_Ram_Flow = [0 1]; 
subset3.limits.PreClr_Fan_In_T = [250 350]; 
subset3.limits.PreClr_Tpc_T    = [250 750]; 

% --- Subset 4 Configuration ---
subset4 = struct();
%subset4.numSimulations = 250/5;
subset4.numSimulations = 0;
subset4.simTime        = 2.5; 
subset4.timeVector     = (0:step:subset4.simTime)'; 
subset4.limits.PreClr_Bld_Flow = [0 10]; 
subset4.limits.PreClr_Bld_In_T = [350 750]; 
subset4.limits.PreClr_Ram_Flow = [0 100]; 
subset4.limits.PreClr_Fan_In_T = [250 350]; 
subset4.limits.PreClr_Tpc_T    = [250 750]; 

% --- Subset 5 Configuration ---
subset5 = struct();
%subset5.numSimulations = 250/5;
subset5.numSimulations = 0;
subset5.simTime        = 2.5; 
subset5.timeVector     = (0:step:subset5.simTime)'; 
subset5.limits.PreClr_Bld_Flow = [0 1]; 
subset5.limits.PreClr_Bld_In_T = [350 750]; 
subset5.limits.PreClr_Ram_Flow = [0 100]; 
subset5.limits.PreClr_Fan_In_T = [250 350]; 
subset5.limits.PreClr_Tpc_T    = [250 750]; 

% Grouping all subsets
subsets = {subset1; subset2; subset3; subset4; subset5};

% --- Data Matrices Initialization ---
P_data = []; % Network Input Matrix (Predictors)
T_data = []; % Network Output Matrix (Targets)

%% ========================================================================
%  3. MAIN SIMULATION & DATA EXTRACTION LOOP
%  ========================================================================
disp(['Starting ', num2str(length(subsets)), ' Simulation Subsets...']);

for j = 1:numel(subsets) % Optimization: Using numel instead of length for cell arrays
    for i = 1:subsets{j}.numSimulations
        
        fprintf('Simulation %d of %d...\n', (j-1)*subsets{j}.numSimulations+i, length(subsets)*subsets{j}.numSimulations);
        
        % --- 3.1. Generate Time-Varying Input Signals ---
        % Generating random ramps and sine waves to appropriately "excite" the system dynamics
        PreClr_Bld_Flow_signal = rand_signal(subsets{j}.timeVector, subsets{j}.limits.PreClr_Bld_Flow);
        PreClr_Bld_In_T_signal = rand_signal(subsets{j}.timeVector, subsets{j}.limits.PreClr_Bld_In_T);
        PreClr_Ram_Flow_signal = rand_signal(subsets{j}.timeVector, subsets{j}.limits.PreClr_Ram_Flow);
        PreClr_Fan_In_T_signal = rand_signal(subsets{j}.timeVector, subsets{j}.limits.PreClr_Fan_In_T);
        
        % Create timetable for current simulation to match Simulink model requirements
        TimeTable2 = timetable(seconds(subsets{j}.timeVector), ...
                               PreClr_Bld_Flow_signal, ...
                               PreClr_Bld_In_T_signal, ...
                               PreClr_Ram_Flow_signal, ...
                               PreClr_Fan_In_T_signal, ...
                               'VariableNames', {'PreClr_Bld_Flow', 'PreClr_Bld_In_T', 'PreClr_Ram_Flow', 'PreClr_Ram_In_T'});
        
        % NOTE: Initial core temperature is ignored in the Embraer model as it 
        % uses the average temperature between the initial Thot and Tcold.
        % T_Core_initial = rand * (limits.T_Core_init(2) - limits.T_Core_init(1)) + limits.T_Core_init(1);
        % T_Core_initial_signal = timeseries(T_Core_initial, timeVector);
        
        % --- 3.2. Execute Simulink Model ---
        % The 'sim' command runs the model and returns the logged data
        out = sim(modelName, 'StopTime', num2str(subsets{j}.simTime));
        
        % --- 3.3. Extract and Structure Logged Data ---
        % Variable names must match the "Log signal data" configuration in Simulink
        log_Tpc_K          = out.Tpc_K';
        log_Bleed_In_T     = out.Bleed_In_T';
        log_Bleed_Flow_ppm = out.Bleed_Flow_ppm';
        log_Fan_In_T       = out.Fan_In_T';
        log_Fan_Flow_ppm   = out.Fan_Flow_ppm';
        log_Thot_Out_K     = out.Thot_Out_K';
        log_Tcold_Out_K    = out.Tcold_Out_K';
        
        % --- 3.4. Assemble Predictor (P) and Target (T) Matrices ---
        P_temp = [log_Tpc_K; log_Bleed_In_T; log_Bleed_Flow_ppm; log_Fan_In_T; log_Fan_Flow_ppm];
        T_temp = [log_Tpc_K];
        
        % Optimization applied: Vectorized derivative calculation replaces slow 'for' loop
        delta_Thot_Out_K  = diff(log_Thot_Out_K);
        delta_Tpc_K       = diff(log_Tpc_K);
        delta_Tcold_Out_K = diff(log_Tcold_Out_K);
        
        % Current simulation time step
        timeStep = subsets{j}.timeVector(2);
        
        % Target data extraction (aligning dimensions by removing the first col)
        % T_temp = [delta_Tpc_K / timeStep]; % Uncomment if network target is the derivative
        T_temp1 = T_temp(:, 2:end);
        T_temp2 = delta_Tpc_K/step;
        P_temp = P_temp(:, 1:end-1);
        
        % Append to total vectors
        P_data = [P_data, P_temp];
        T_data = [T_data, [T_temp1;T_temp2]];
    end
end

%% ========================================================================
%  4. DYNAMIC DATA SAVING ROUTINE
%  ========================================================================
disp('Data Generation Successfully Completed!');
disp('Initiating dynamic saving routine...');

% 1. Dynamically acquire the folder where this exact script is located
[scriptDirectory, ~, ~] = fileparts(mfilename('fullpath'));

% 2. Dynamically determine the number of generated data points
% Assuming P_data is structured as [Variables x Datapoints]
numDataPoints = size(P_data, 2); 

% 3. Generate the timestamp in the requested format (YYYYMMDDhhmm)
% We use the modern datetime function for precise formatting
timeStampStr = char(datetime('now', 'Format', 'yyyyMMddHHmm'));

% 4. Construct the dynamic filename using sprintf for clean formatting
fileName = sprintf('%s_HeatExchanger_SyntheticData_%d.mat', timeStampStr, numDataPoints);

% 5. Build the absolute OS-agnostic path
fullSavePath = fullfile(scriptDirectory, fileName);

% 6. Save the data arrays and structural metadata
save(fullSavePath, 'P_data', 'T_data', 'dataDescription');

% 7. Output confirmation to the command window
fprintf('Success! Training data natively saved to:\n%s\n', fullSavePath);

%% ========================================================================
%  5. AUXILIARY FUNCTIONS
%  ========================================================================
function signal = rand_signal(t, limits)
    % Generates a randomized sum of sine waves to ensure robust frequency excitation
    num_waves = 4;
    signal = zeros(size(t));
    for k = 1:num_waves
        amp   = rand / k;
        phase = rand * 2 * pi;
        freq  = rand * 0.1;
        signal = signal + amp * sin(2 * pi * freq * t + phase);
    end
    
    % Normalize signal to [0,1] domain, then map to user-defined limits
    signal_min = min(signal);
    signal_max = max(signal);
    signal = (signal - signal_min) / (signal_max - signal_min);
    signal = signal * (limits(2) - limits(1)) + limits(1);
end