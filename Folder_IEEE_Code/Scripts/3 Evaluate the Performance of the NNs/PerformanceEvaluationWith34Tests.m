% Evaluate the performance of a specific NN with all 34 experimental tests
% Author: RPELUZIO
% Last Modified: 2026/04/12
% Description:
%   1) Get a list of all the tests the NN has already been evaluated on.
%   2) Distribute remaining tests across N parallel workers using isolated Plant models.
%   3) Return the updated structure.

function performanceStruct = PerformanceEvaluationWith34Tests(options)

    arguments
            options.NNFullPath (1,1) string = "None";
            options.NNFileName (1,1) string = "";
            options.NNNumber (1,1) double {mustBeInteger} = 1;
            options.useNNNumberOrName (1,1) string = "Number" 
            options.NNModelType (1,1) string = "ETUNI" 
            options.performanceStructName (1,1) string = "realPerformanceStruct"
            options.useSpecificModel (1,1) logical = false
            options.modelFileName (1,1) string = "HX_Simulink_Model";
            
            % Parallel Options
            options.numWorkers (1,1) double = 1;
            options.tempPlantNames (1,:) string = []; % Contains the N copies
            options.useParallelComputing (1,1) logical = false
    end

    if options.NNFullPath == "None"
        pattern = '\(R(.*?)\)';
        tokens = regexp(version, pattern, 'tokens');
        matlabVersion = tokens{:}{:};
        path = ['Folder_IEEE_Code\NN_Models\',char(options.NNModelType)];
    
        % Get NN number and name from files
        if options.useNNNumberOrName == "Number"
            % Get NN Name
            targetDir = fullfile(pwd, path);
            fileList = dir(fullfile(targetDir, '*.slx'));
            [~, sortedIdx] = sort({fileList.name});
            fileList = fileList(sortedIdx);
            NN_FileName = string(fileList(options.NNNumber).name);
            [~, onlyNetworkName, ~] = fileparts(NN_FileName);
        else
            NN_FileName = options.NNFileName;
            targetDir = fullfile(pwd, path);
            fileList = dir(fullfile(targetDir, '*.slx'));
            [~, sortedIdx] = sort({fileList.name});
            fileList = fileList(sortedIdx);
            for j = 1:length(fileList)
                if NN_FileName == fileList(j).name
                    options.NNNumber = j;
                    break
                end
            end
        end

        % 1) Get a list of all the tests the NN has already been evaluated on. If
        %   no new run is required, break.
    
        % 1.1) Navigate to desired struct field. If it doesn't exist, create
        % it.
        [~, onlyNetworkName, ~] = fileparts(NN_FileName);

    else
        % Get NN Name
        onlyNetworkName = split(options.NNFullPath,"\");
        onlyNetworkName = onlyNetworkName(end);
        onlyNetworkName = split(onlyNetworkName,".");
        onlyNetworkName = onlyNetworkName(1);
        onlyNetworkName = onlyNetworkName{1};
    end

    % Reading NNs
    fprintf("Evaluating NN %s. Currently ", onlyNetworkName)

    % File is read sequentially before parallelization
    originalStruct = load(onlyNetworkName+".mat"); 
    performanceStruct = originalStruct;

    if not(isfield(originalStruct,options.performanceStructName))
        performanceStruct = struct();
    else
        eval("performanceStruct = originalStruct."+options.performanceStructName+";");
    end

    if not(isfield(performanceStruct,"PrecoolerPhase2APerformance"))
        performanceStruct.PrecoolerPhase2APerformance = struct();
        performanceStruct.PrecoolerPhase2APerformance.Description = "This is the performance evaluated using the 34 test samples.";
        performanceStruct.PrecoolerPhase2APerformance.Tpc_NN_MSE_Vector = zeros(1,34);
    end

    mse_vector = performanceStruct.PrecoolerPhase2APerformance.Tpc_NN_MSE_Vector;
    testsToRunIdx = find(mse_vector == 0);
    
    if isempty(testsToRunIdx)
        fprintf("0 tests to perform. Skipping...\n")
        performanceStruct = 0;
        return
    end

    fprintf("%i tests to perform across %i workers.\n", length(testsToRunIdx), options.numWorkers);

    % Matrix to hold results safely from parfor (Rows = Workers, Cols = 34 Tests)
    workerResults = zeros(options.numWorkers, length(mse_vector));

    % Update Model Full Path
    options.NNFullPath;


    if options.numWorkers >1
        % --- The Chunked Parallel Loop ---
        parfor w = 1:options.numWorkers
            
            % Slice the remaining tests for this specific worker
            myTests = testsToRunIdx(w:options.numWorkers:end);
            
            % Determine which Plant model copy this worker will use
            if ~isempty(options.tempPlantNames) && length(options.tempPlantNames) >= w
                myPlantName = options.tempPlantNames(w);
            else
                myPlantName = options.modelFileName;
            end
            
            local_results = zeros(1, length(mse_vector));
            
            % Run the tests assigned to this worker sequentially
            for j = 1:length(myTests)
                i = myTests(j);
                
                fprintf('   [Worker %d] Evaluating Test %02d/%02d (Test ID: %d)...\n',w, j, length(myTests), i);

                if ~options.useSpecificModel
                    workspaceOutput = runPrecoolerSimulation(...
                        'NNFullPath', options.NNFullPath, 'testNumber', i, 'plot', false, ...
                        'showCMD', "Simple", 'NNModelType', options.NNModelType, ...
                        'useParallelComputing', options.useParallelComputing,'workerID',w,'fixedStepValue');
                else
                    workspaceOutput = runPrecoolerSimulation(...
                        'NNFullPath', options.NNFullPath, 'testNumber', i, 'plot', false, ...
                        'showCMD', "Simple", 'NNModelType', options.NNModelType, ...
                        'useSpecificModel', options.useSpecificModel, 'modelFileName', myPlantName, ...
                        'useParallelComputing', options.useParallelComputing,'workerID',w,'fixedStepValue');
                end
                
                % Calculate MSE
                local_results(i) = sum((workspaceOutput.Tpc_K_NN(int32(workspaceOutput.ExtraSteps):end) - ...
                                       workspaceOutput.Tpc_K(int32(workspaceOutput.ExtraSteps):end)).^2) / ...
                                       (length(workspaceOutput.Tpc_K_NN) - workspaceOutput.ExtraSteps);
            end
            
            % Push worker results to the matrix
            workerResults(w, :) = local_results;
            bdclose('all'); %Close all files associated with this worker
        end
    else
        % --- The Chunked Parallel Loop ---
        for w = 1:options.numWorkers
            
            % Slice the remaining tests for this specific worker
            myTests = testsToRunIdx(w:options.numWorkers:end);
            
            % Determine which Plant model copy this worker will use
            if ~isempty(options.tempPlantNames) && length(options.tempPlantNames) >= w
                myPlantName = options.tempPlantNames(w);
            else
                myPlantName = options.modelFileName;
            end
            
            local_results = zeros(1, length(mse_vector));
            
            % Run the tests assigned to this worker sequentially
            for j = 1:length(myTests)
                i = myTests(j);
                
                fprintf('   [Worker %d] Evaluating Test %02d/%02d (Test ID: %d)...\n',w, j, length(myTests), i);
    
                if ~options.useSpecificModel
                    workspaceOutput = runPrecoolerSimulation(...
                        'NNFullPath', options.NNFullPath, 'testNumber', i, 'plot', false, ...
                        'showCMD', "None", 'NNModelType', options.NNModelType, ...
                        'useParallelComputing', options.useParallelComputing,'workerID',w);
                else
                    workspaceOutput = runPrecoolerSimulation(...
                        'NNFullPath', options.NNFullPath, 'testNumber', i, 'plot', false, ...
                        'showCMD', "None", 'NNModelType', options.NNModelType, ...
                        'useSpecificModel', options.useSpecificModel, 'modelFileName', myPlantName, ...
                        'useParallelComputing', options.useParallelComputing,'workerID',w); 
                end
                
                % Calculate MSE
                local_results(i) = sum((workspaceOutput.Tpc_K_NN(int32(workspaceOutput.ExtraSteps):end) - ...
                                       workspaceOutput.Tpc_K(int32(workspaceOutput.ExtraSteps):end)).^2) / ...
                                       (length(workspaceOutput.Tpc_K_NN) - workspaceOutput.ExtraSteps);
            end
            
            % Push worker results to the matrix
            workerResults(w, :) = local_results;
            bdclose('all'); %Close all files associated with this worker
        end
    end

    % Combine results from the worker matrix back into a 1D vector
    for i = 1:length(testsToRunIdx)
        idx = testsToRunIdx(i);
        mse_vector(idx) = sum(workerResults(:, idx));
    end

    performanceStruct.PrecoolerPhase2APerformance.Tpc_NN_MSE_Vector = mse_vector;
end