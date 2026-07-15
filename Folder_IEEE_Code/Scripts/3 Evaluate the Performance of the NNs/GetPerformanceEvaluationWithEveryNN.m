% Get the performance evaluation from all .mat files & Turn them into a
% table.

% Author: RPELUZIO
% Last Modified: 2026/01/20


clc; clear; close all;

modelType = 'ETUNI';
subType = "None"; %may also be "ALL" for all subtypes
groupSize = 4; %Amount of different NNs run per Depth. Example: 30 40 50 60 = 4

%% List every NN Model data available
% Get NN Name
pattern = '\(R(.*?)\)';
tokens = regexp(version, pattern, 'tokens');
matlabVersion = tokens{:}{:};
if ~(subType=="None")
    path = ['Folder_IEEE_Code\NN_Models\',char(modelType),'\',char(subType)];
else
    path = ['Folder_IEEE_Code\NN_Models\',char(modelType)];
end
%path = ['Implementacao Rafael Peluzio\3. Precooler_NNModel\',matlabVersion,'\NN_Models\',char(modelType)];

targetDir = fullfile(pwd, path);
fileList = dir(fullfile(targetDir, '*.mat'));
[~, sortedIdx] = sort({fileList.name});
fileList = fileList(sortedIdx);

%Order fileList to have W then D sorted

allNames = string({fileList.name});

tokens = regexp(allNames, '(?<width>\d+)W(?<depth>\d+)D', 'names');

% 3. Convert the cell of structs into a numeric matrix for sorting
% We must ensure these are doubles to avoid '10' < '2' logic errors
widths = cellfun(@(x) str2double(x.width), tokens);
depths = cellfun(@(x) str2double(x.depth), tokens);

% 3. Create a Table to visualize the Hierarchy
% We include the original index (ID) to reorder the struct later
T = table(widths', depths', (1:numel(allNames))', 'VariableNames', {'W', 'D', 'ID'});

% 4. Perform the Nested Sort
% PRIMARY KEY: 'D' (Depth) -> This groups the files by Depth first.
% SECONDARY KEY: 'W' (Width) -> This sorts the Widths within each Depth group.
% DIRECTION: 'descend' matches your diagram (High values -> Low values).
% NOTE: Change to 'ascend' if you want 1D to appear before 2D.
T_sorted = sortrows(T, {'D', 'W'}, {'ascend', 'ascend'});

% 5. Apply the new order to the structure
fileList = fileList(T_sorted.ID);

clear matlabVersion path pattern sortedIdx targetDir tokens
%% Get data from trained NN

Tpc_NN_MSE_Matrix = {};
Tpc_NN_PerformanceTable = {};
Tpc_NN_PerformanceTable{1,1} = "NN Model\ Performance Metric";
Tpc_NN_PerformanceTable{1,2} = "Num_epochs";
Tpc_NN_PerformanceTable{1,3} = "Performance function";
Tpc_NN_PerformanceTable{1,4} = "Training Performance";
Tpc_NN_PerformanceTable{1,5} = "Validation Performance";
Tpc_NN_PerformanceTable{1,6} = "Testing Performance";
Tpc_NN_PerformanceTable{1,7} = "Gradient";
Tpc_NN_PerformanceTable{1,8} = "Validation Fails";
Tpc_NN_PerformanceTable{1,9} = "Training Time";
Tpc_NN_PerformanceTable{1,10} = "Training Stop Condition";

% New fileList variable to filter-out the entries without the performance
% check
newFileList = fileList;
numRemoved = 0; %For matching the rows between newFileLIst and old

%length(fileList)
for i = 1:length(fileList)
    Struct = load(fileList(i).name);
    try
        Tpc_NN_MSE_Vector = Struct.realPerformanceStruct.PrecoolerPhase2APerformance.Tpc_NN_MSE_Vector;
    catch
        newFileList(i-numRemoved,:)=[]; %deletes row i from newFileList
        numRemoved = numRemoved+1;
        continue %skip
    end
    Tpc_NN_MSE_Matrix = [Tpc_NN_MSE_Matrix; [{fileList(i).name},num2cell(Tpc_NN_MSE_Vector)]];

    Tpc_NN_PerformanceTable{i+1,1} = fileList(i).name;
    Tpc_NN_PerformanceTable{i+1,2} = Struct.trNN.num_epochs;
    Tpc_NN_PerformanceTable{i+1,3} = Struct.trNN.performFcn;
    Tpc_NN_PerformanceTable{i+1,4} = Struct.trNN.best_tperf;
    Tpc_NN_PerformanceTable{i+1,5} = Struct.trNN.best_vperf;
    Tpc_NN_PerformanceTable{i+1,6} = Struct.trNN.best_perf;
    Tpc_NN_PerformanceTable{i+1,7} = Struct.trNN.gradient(end);
    Tpc_NN_PerformanceTable{i+1,8} = Struct.trNN.val_fail(end);
    Tpc_NN_PerformanceTable{i+1,9} = Struct.trNN.time(end);
    Tpc_NN_PerformanceTable{i+1,10} = "None for now";
end

clear i Struct Tpc_NN_MSE_Vector
%% Get data from main database

% Average temperature values
data = load("HeatExchangerExperimentalDataset.mat"); data = data.data;

% For each test in Data
    % Get the TimeSeries for Tpc
    % Get the average
    % Populate the table containing TestName | Average Value
%% Write to excel

%excelFileName = "AllTestsNNMSEPerformance.xlsx";
%writecell(Tpc_NN_MSE_Matrix, excelFileName);

%% Graph 1: Strip Plot / Gráfico de dispersão

% Data Processing

% Step A: Extract Model Names (Column 1)
model_names_str = string(Tpc_NN_MSE_Matrix(:, 1));
num_models = length(model_names_str);

% Step B: Extract MSE Data (Columns 2 to 35) and Convert to Matrix
mse_values = cell2mat(Tpc_NN_MSE_Matrix(:, 2:end));

% Step C: Convert MSE to RMSE (Root Mean Squared Error)
rmse_values = sqrt(mse_values);

% Step C1: Calculate final statistic as RMSE as % over average temperature
load("AverageTestValues.mat");
averageValues = cell2mat(averageValuesMatrix(2:end,2));
rmse_values_percent = [];
for i = 1:size(rmse_values,1)
    rmse_values_percent(i,:) = (rmse_values(i,:)./averageValues')*100;
end

% Step D: Calculate Statistics for the Summary Line
mean_rmse_percent = mean(rmse_values_percent, 2, 'omitnan'); % 'omitnan' adds robustness

% Step E: Extract NW (Neurons) / MD definition from naming convention
% Assuming names contain a pattern like "..._30_..." or similar architecture markers.
% This regex looks for the specific numeric markers used in your file naming.
short_labels = strings(num_models, 1);
for i = 1:num_models
    % Extracting the numerical architecture (NW) often found near the end of your strings
    parts = split(model_names_str(i), '_');
    short_labels(i) = "NN"+string(i)+": "+parts(6); 
end

% 3. Plotting

figure('Name', 'Model Performance Comparison', 'Color', 'w', 'Position', [100, 100, 1000, 600]);
hold on;

% --- Layer 1: The "Strip Plot" (The 'x' marks) ---
% We need to plot 34 points for Model 1, 34 points for Model 2, etc.
% We create an X-coordinate matrix matching the size of rmse_values.
x_coords = repmat((1:num_models)', 1, size(rmse_values_percent, 2));

% Plot all individual test results
scatter(x_coords(:), rmse_values_percent(:), 40, 'k', 'x', ...
    'LineWidth', 1.0, 'DisplayName', 'Individual Test RMSE %');

% --- Layer 2: The Summary Line (The blue line) ---
plot(1:num_models, mean_rmse_percent, '-o', ...
    'Color', 'b', ...
    'LineWidth', 2, ...
    'MarkerFaceColor', 'b', ...
    'MarkerSize', 6, ...
    'DisplayName', 'Mean RMSE %');

% --- Layer 3: Formatting (Matching the Sketch) ---

% Set Y-Axis to Logarithmic Scale
set(gca, 'YScale', 'log');

% Labels
ylabel('RMSE % (Log)', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Neural Network Models Topology', 'FontSize', 12, 'FontWeight', 'bold');
title('Topology x Performance with 34 tests', 'FontSize', 14);

% X-Axis Ticks
xlim([0, num_models + 1]);
xticks(1:num_models);
xticklabels(short_labels);
xtickangle(45); % Kept at 0 for readability if labels are short numbers

% If you have too many models (44), the names might overlap.
% We rotate them for better visibility.
%xticklabels(model_names_str);
%xtickangle(90); 

% Grid and Legend
grid on;
% Customize grid to show minor log lines (looks technical)
set(gca, 'YMinorGrid', 'on', 'YGrid', 'on'); 

legend('Location', 'northeast');

hold off;

%% Graph 2: NN Complexity strip plot

% Parsing and Calculation
% Extract Model Names and MSE Data
model_names = string(Tpc_NN_MSE_Matrix(:, 1));
mse_values = cell2mat(Tpc_NN_MSE_Matrix(:, 2:end));
% Delete line 19 because it is an outlier
%mse_values = [cell2mat(Tpc_NN_MSE_Matrix(1:18, 2:end)); cell2mat(Tpc_NN_MSE_Matrix(20:end, 2:end))];
%model_names = [string(Tpc_NN_MSE_Matrix(1:18, 1)); string(Tpc_NN_MSE_Matrix(20:end, 1))];

rmse_values_percent = sqrt(mse_values); % Convert to RMSE
mean_rmse_percent = mean(rmse_values_percent, 2, 'omitnan');

% Initialize Topology Vectors
num_models = length(model_names);
vec_width = zeros(num_models, 1);
vec_depth = zeros(num_models, 1);
vec_neurons = zeros(num_models, 1);
vec_connections = zeros(num_models, 1);

% Constants for Connection Calculation
n_input = 5;  
n_output = 1; 

for i = 1:num_models
    name = model_names(i);
    
    % REGEX: Find digits before 'W' and before 'D'
    % (\d+) captures one or more digits.
    tokens = regexp(name, '(\d+)W(\d+)D', 'tokens');
    
    if ~isempty(tokens)
        % regexp returns nested cells: {{'10', '2'}}
        w = str2double(tokens{1}{1});
        d = str2double(tokens{1}{2});
        
        vec_width(i) = w;
        vec_depth(i) = d;
        
        % Metric 1: Total Hidden Neurons
        vec_neurons(i) = w * d;
        
        % Metric 2: Total Connections (Weights + Biases)
        % Input Layer -> First Hidden
        conn_in = (n_input * w) + w; % Weights + Biases
        
        % Hidden -> Hidden (if Depth > 1)
        if d > 1
            % (d-1) transitions between hidden layers of size w
            conn_hidden = (d - 1) * (w * w + w); 
        else
            conn_hidden = 0;
        end
        
        % Last Hidden -> Output
        conn_out = (w * n_output);
        
        vec_connections(i) = conn_in + conn_hidden + conn_out;
    else
        warning('Model name "%s" does not match format NWND.', name);
    end
end

% Plot
% We define a local function to avoid code repetition for the two plots.
create_complexity_plot(vec_neurons, rmse_values_percent, mean_rmse_percent, ...
    'Performance vs. Number of Neurons', 'Total Hidden Neurons');

create_complexity_plot(vec_connections, rmse_values_percent, mean_rmse_percent, ...
    'Performance vs. Number of Connections', 'Total Connections (Weights + Biases)');

% Helper Function for Plotting
function create_complexity_plot(x_data, rmse_matrix, rmse_means, title_str, xlabel_str)
    
    % --- SORTING ---
    % Critical: We must sort the X-axis data to draw a clean line.
    [x_sorted, sort_idx] = sort(x_data);
    
    % Reorder the Y-data to match the sorted X
    rmse_matrix_sorted = rmse_matrix(sort_idx, :);
    rmse_means_sorted = rmse_means(sort_idx);
    
    figure('Name', title_str, 'Color', 'w', 'Position', [100, 100, 900, 600]);
    hold on;
    
    % 1. Strip Plot (Scatter of all tests)
    % Create X-coordinates matrix matching the 34 columns of data
    x_matrix = repmat(x_sorted, 1, size(rmse_matrix, 2));
    
    scatter(x_matrix(:), rmse_matrix_sorted(:), 40, 'k', 'x', ...
        'LineWidth', 1.0, 'DisplayName', 'Individual Test RMSE');
    
    % 2. Summary Line (Mean)
    plot(x_sorted, rmse_means_sorted, '-o', ...
        'Color', 'b', ...
        'LineWidth', 2, ...
        'MarkerFaceColor', 'b', ...
        'MarkerSize', 6, ...
        'DisplayName', 'Mean RMSE');
    
    % 3. Formatting
    set(gca, 'YScale', 'log');
    ylabel('RMSE (Log Scale)', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel(xlabel_str, 'FontSize', 12, 'FontWeight', 'bold');
    title(title_str, 'FontSize', 14);
    
    grid on;
    set(gca, 'YMinorGrid', 'on', 'YGrid', 'on');
    legend('Location', 'northeast');
    
    hold off;
end