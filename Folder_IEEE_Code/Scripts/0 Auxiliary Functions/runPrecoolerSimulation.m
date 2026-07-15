% Run the Isolated Precooler Model with NN Model in a wrapped function
% format.
% Author: RPELUZIO
% Last Modified: 2026/04/12
% Modifications:
% 08/feb/2026 - Added full path capability for NN model

function out = runPrecoolerSimulation(options)
    
    %% Step 0: Function arguments definition
    arguments
        
        options.plot (1,1) logical = true; % If result graphs sould be plotted or not
        options.modelFileName (1,1) string = "HX_Simulink_Model"; %Without the model type sufix
        options.dataFileName (1,1) string = "HeatExchangerExperimentalDataset.mat";
        options.showCMD (1,1) string = "Full"; %Level of description for CMD messages (Full, Simple, None)
        options.useNN (1,1) logical = true; % If wishes to use NN or not to run the model
        options.useSpecificModel (1,1) logical = false;

        % NN definition
        options.NNFullPath (1,1) string = "None"; % If full path is specified, no need to inform name or number of the NN.
        options.NNModelType (1,1) string = "ETUNI"; %NARMAX ETUNI or RKNN
        options.NNFileName (1,1) string = "NN_ETUNI_OnlyTpc_20260116_0026_30W5D_5In1Out.slx";
        options.NNNumber (1,1) double {mustBeInteger} = 1;
        options.useNNNumberOrName (1,1) string = "Number"; % Number or Name

        % Test definition
        options.testNumber (1,1) double {mustBeInteger} = 1;
        options.testName (1,1) string = "day1_test01_Interval1";
        options.useTestNumOrName (1,1) string = "Number"; % Number or Name

        % K1 definition for cold side loss coefficient
        options.K1_user (1,1) double = 0.00767;

        % Parallel safety flag (disables set_param modifications)
        options.useParallelComputing (1,1) logical = true;
        options.workerID (1,1) double = 1;
    end
    
    %% Step 1: Pre-processing and workspace preparation
    
    % Complete model file name with the suffix for the respective type of
    % NN
    if options.useSpecificModel
        options.modelFileName = options.modelFileName+".slx";
    else
        if options.NNModelType == "ETUNI"
            options.modelFileName = options.modelFileName+"_ETUNI.slx"; 
        elseif options.NNModelType == "NARMAX"
            options.modelFileName = options.modelFileName+"_NARMAX.slx"; 
        else
            error('HX Simulink Model Name not Available')
        end
    end

    % Files existance verification
    if ~exist(options.modelFileName, 'file')
        error('Simulink model "%s" not found.', options.modelFileName);
    elseif ~exist(options.NNFileName, 'file') & options.NNFullPath == "None"
        error('Neural network model "%s" not found.', options.NNFileName);
    elseif ~exist(options.dataFileName, 'file')
        error('Data file "%s" not found.', options.dataFileName);
    end
    
    % Extract data from source
    data = load(options.dataFileName);
    data = data.data;
    
    % Get test name from data struct
    namesArray = fieldnames(data);
    
    if options.useTestNumOrName == "Number"
        
        if ~max(ismember(namesArray, options.testName))
            error('Test name "%s" not found in data.', options.testName);
        end
        options.testName = namesArray{options.testNumber};
    else
        options.testNumber = 0;
        for i = 1:length(namesArray)
           if  string(namesArray{i})==string(options.testName)
              options.testNumber = i;
              break
           end
        end
        if options.testNumber == 0
            error('Test name "%s" not found in data.', options.testName);
    
        end
    end

    % Get experimental data

    TimeTable = data.(options.testName).TimeTable;
    dataStruct = data.(options.testName).dataStruct;
    
    %% Step 2: Open Simulink model and setup Simulink blocks
    [~, onlyModelName, ~] = fileparts(options.modelFileName);
    load_system(onlyModelName);

    % Only load if it's not already loaded by the worker
    if ~bdIsLoaded(onlyModelName)
        load_system(onlyModelName);
    end

    
    % Set Model Reference to use specified neural network

    % Set the ModelReference File Name to NN_FileName
    if options.useNN 
        if options.NNFullPath == "None"
            % Current Matlab Version
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
            end
        else
            % Get NN Name
            onlyNetworkName = split(options.NNFullPath,"\");
            onlyNetworkName = onlyNetworkName(end);
            onlyNetworkName = split(onlyNetworkName,".");
            onlyNetworkName = onlyNetworkName(1);
            onlyNetworkName = onlyNetworkName{1};
        end
        
        if ~options.useParallelComputing
            blockPath = onlyModelName+"/"+"Model";
            set_param(blockPath, 'ModelName', onlyNetworkName);
        end
    end

    %% Step 2.5: Display on CMD current run configuration
    if options.showCMD == "Full" | options.showCMD == "Simple"
        if options.useNN
            fprintf("Simulating %s for Test %s with NN %s\n",onlyModelName,string(options.testNumber),onlyNetworkName)
        elseif ~options.useNN
            fprintf("Simulating %s for Test\n",onlyModelName,string(options.testNumber))
        end

    elseif options.showCMD == "No"

    end
  
    %% Step 3: Run Simulink model to determine total consolidation time

    % Add 200s repeated data at the start of experimental data
    TimeToConsolidateInitialConditions = 200; %[seconds], amount of time the initial conditions will be forced during the start of the simulation
    firstRow = TimeTable(1,:); %Obtain the first row from Time Table
    dt = seconds(TimeTable.Time(2)-TimeTable.Time(1)); %Obtain the fixed step value from Time Table
    extraSteps = floor(TimeToConsolidateInitialConditions / dt); %Calculate the amount of extra steps required for the informed time to consolidate initial conditions
    newTimes = seconds((0:extraSteps)'*dt+seconds(TimeTable.Time(1)));
    repeatedBlock = repmat(firstRow, [extraSteps+1, 1]);
    repeatedBlock.Time = newTimes;
    
    % New TimeTable that repeats first row for consolidation Time seconds
    temp = TimeTable(2:end,:);
    temp.Time = seconds(seconds(temp.Time)+TimeToConsolidateInitialConditions);
    TimeTable2 = [repeatedBlock; temp];
  
    % Run using simulink input object
    
    if options.showCMD == "Full"
        disp('Running Simulink model to determine consolidation time...');
    end
    
    simIn = Simulink.SimulationInput(onlyModelName);
    simIn = simIn.setModelParameter('stopTime',string(seconds(max(TimeTable2.Time))));
    simIn = simIn.setVariable('TimeTable2', TimeTable2);
    simIn = simIn.setVariable('K1_user', options.K1_user);
    out = sim(simIn);
    
    minGradient = 5e-3;
    Tcold_Out_K_consolidateTime = 0;
    Tpc_K_consolidateTime = 0;
    Thot_Out_K_consolidateTime = 0;
    for i = 1:length(out.tout)
       if out.tout(i)>= TimeToConsolidateInitialConditions
           error(sprintf('Did not have enough time to consolidate in %i seconds', TimeToConsolidateInitialConditions));
       end
       if abs(out.Tcold_Out_K(i)-out.Tcold_Out_K(i+1))<minGradient && (Tcold_Out_K_consolidateTime == 0)
           Tcold_Out_K_consolidateTime=i;
       end
       if abs(out.Thot_Out_K(i)-out.Thot_Out_K(i+1))<minGradient && (Thot_Out_K_consolidateTime == 0)
           Thot_Out_K_consolidateTime=i;
       end
       if abs(out.Tpc_K(i)-out.Tpc_K(i+1))<minGradient && (Tpc_K_consolidateTime == 0)
           Tpc_K_consolidateTime=i;
       end
       if min([Tpc_K_consolidateTime Thot_Out_K_consolidateTime Tcold_Out_K_consolidateTime])>0
          break 
       end
    end
    
    stepsToConsolidateInitialConditions = max([Tpc_K_consolidateTime Thot_Out_K_consolidateTime Tcold_Out_K_consolidateTime]);
    TimeToConsolidateInitialConditions = min(max(out.tout(stepsToConsolidateInitialConditions),25),100);
    firstRow = TimeTable(1,:); %Obtain the first row from Time Table
    dt = seconds(TimeTable.Time(2)-TimeTable.Time(1)); %Obtain the fixed step value from Time Table
    extraSteps = floor(TimeToConsolidateInitialConditions / dt); %Calculate the amount of extra steps required for the informed time to consolidate initial conditions
    newTimes = seconds((0:extraSteps)'*dt+seconds(TimeTable.Time(1)));
    repeatedBlock = repmat(firstRow, [extraSteps+1, 1]);
    repeatedBlock.Time = newTimes;
    
    % New TimeTable that repeats first row for consolidation Time seconds
    temp = TimeTable(2:end,:);
    temp.Time = seconds(seconds(temp.Time)+TimeToConsolidateInitialConditions);
    TimeTable2 = [repeatedBlock; temp];
    stopTime = seconds(max(TimeTable2.Time));
    
    %% Step 4: Run Simulink model to get final results
    stopTime = seconds(max(TimeTable2.Time));
    
    if options.showCMD=="Full"
        disp('Running Simulink model with adjusted consolidation Time...');
    end

    simIn = Simulink.SimulationInput(onlyModelName);
    simIn = simIn.setModelParameter('stopTime',string(seconds(max(TimeTable2.Time))));
    simIn = simIn.setVariable('TimeTable2', TimeTable2);
    simIn = simIn.setVariable('K1_user', options.K1_user);
    out = sim(simIn);

    % Add variable with total amount of simulation steps added to output
    out.ExtraSteps = extraSteps*dt/(out.tout(2)-out.tout(1));

    
    %% Step 4.5: Add values to output
    out.stepsToConsolidateInitialConditions = stepsToConsolidateInitialConditions;
    out.TimeToConsolidateInitialConditions = TimeToConsolidateInitialConditions;
    
    %% Step 5: Plots

    if ~options.plot
        return
    end
    
    % Ensure 'out' signals are resampled to match TimeTable2.Time if needed
    % Use 'interp1' for synchronization

    simTime = out.tout; % Simulink time vector
    tcold = interp1(simTime, out.Tcold_Out_K, seconds(TimeTable2.Time)); % Resample to timetable time
    thot  = interp1(simTime, out.Thot_Out_K, seconds(TimeTable2.Time));
    tpc   = interp1(simTime, out.Tpc_K, seconds(TimeTable2.Time));
    
    % add values for NN output if they exist
    if ~(options.NNModelType == "None")
        tcold_NN = interp1(simTime, out.Tcold_Out_K_NN, seconds(TimeTable2.Time)); % Resample to timetable time
        thot_NN  = interp1(simTime, out.Thot_Out_K_NN, seconds(TimeTable2.Time));
        tpc_NN   = interp1(simTime, out.Tpc_K_NN, seconds(TimeTable2.Time));
    end
    
    % Standard colors definition
    
    % Saturated Red (Hot Intake)
    colorRedSat = [1.0, 0.0, 0.0];        % RGB: (255, 0, 0)
    colorRedSatFaded = [1.0, 0.0, 0.0, 0.1];        % RGB: (255, 0, 0)
    % Saturated Orange (Hot Output)
    colorOrangeSat = [1.0, 0.5, 0.0];     % RGB: (255, 128, 0)
    colorOrangeSatFaded = [1.0, 0.5, 0.0, 0.1];     % RGB: (255, 128, 0)
    % Faded Orange (Hot output extra measurements)
    colorOrangeFaded = [1.0, 0.8, 0.6];   % RGB: (255, 204, 153)
    colorOrangeFadedFaded = [1.0, 0.8, 0.6, 0.1];   % RGB: (255, 204, 153)
    % Satur6ated Dark Blue (Cold Intake)
    colorBlueDarkSat = [0.0, 0.2, 0.6];   % RGB: (0, 51, 153)
    colorBlueDarkSatFaded = [0.0, 0.2, 0.6, 0.1];   % RGB: (0, 51, 153)
    % Saturated Light Blue (Cold Output)
    colorBlueLightSat = [0.0, 0.6, 1.0];  % RGB: (0, 153, 255)
    colorBlueLightSatFaded = [0.0, 0.6, 1.0, 0.1];  % RGB: (0, 153, 255)
    % Faded Light Blue (Cold Output extra measurements)
    colorBlueLightFaded = [0.6, 0.8, 1.0];% RGB: (153, 204, 255)
    colorBlueLightFadedFaded = [0.6, 0.8, 1.0, 0.1];% RGB: (153, 204, 255)
    % Black (Core Temperature)
    colorBlack = [0.0, 0.0, 0.0];         % RGB: (0, 0, 0)
    
    %% -------------------- GRAPH 1: Precooler Flows --------------------
    figure('Name', 'Overview', 'NumberTitle', 'off');
    
    plot(TimeTable2.Time, TimeTable2.PreClr_Bld_Flow, 'LineWidth', 1.5,'Color',colorRedSat); hold on;
    plot(TimeTable2.Time, TimeTable2.PreClr_Ram_Flow, 'LineWidth', 1.5,'Color',colorBlueDarkSat);
    xline(TimeToConsolidateInitialConditions,'--','Label',sprintf('Consolidation to initial conditions'))
    title('Precooler Flows');
    xlabel('Time (s)'); ylabel('Flow (lb/min)');
    legend('Bleed Flow (Exp)', 'Fan Flow (Exp)');
    grid on;
    
    %% -------------------- GRAPH 2: Temperatures --------------------
    figure('Name', 'Temperatures', 'NumberTitle', 'off','WindowState','maximized');
    plot(TimeTable2.Time, TimeTable2.PreClr_Bld_In_T, 'LineWidth', 1.5,'Color',colorRedSat); hold on;
    plot(TimeTable2.Time, TimeTable2.PreClr_Bld_Out_T1, 'LineWidth', 0.4,'Color',colorOrangeFaded);
    plot(TimeTable2.Time, TimeTable2.PreClr_Bld_Out_T2, 'LineWidth', 0.4,'Color',colorOrangeFaded);
    plot(TimeTable2.Time, TimeTable2.PreClr_Bld_Out_T_Avg, 'LineWidth', 1.5,'Color',colorOrangeSat);
    plot(TimeTable2.Time, thot,'--', 'LineWidth', 1.5,'Color',colorOrangeSat);
    plot(TimeTable2.Time, TimeTable2.PreClr_Ram_In_T, 'LineWidth', 1.5,'Color',colorBlueDarkSat);
    plot(TimeTable2.Time, TimeTable2.PreClr_Ram_Out_T1, 'LineWidth', 0.4,'Color',colorBlueLightFaded);
    plot(TimeTable2.Time, TimeTable2.PreClr_Ram_Out_T2,'LineWidth', 0.4,'Color',colorBlueLightFaded);
    plot(TimeTable2.Time, TimeTable2.PreClr_Ram_Out_T3,'LineWidth', 0.4,'Color',colorBlueLightFaded);
    plot(TimeTable2.Time, TimeTable2.PreClr_Ram_Out_T_Avg, 'LineWidth', 1.5,'Color',colorBlueLightSat);
    plot(TimeTable2.Time, tcold,'--', 'LineWidth', 1.5,'Color',colorBlueLightSat);
    plot(TimeTable2.Time, tpc, '--', 'LineWidth', 1.5,'Color',colorBlack);
    xline(TimeToConsolidateInitialConditions,'--','Label',sprintf('Consolidation to initial conditions'))
    
    
    title(sprintf('Experimental vs Simulation Temperatures [Experiment Label (%i): %s]',options.testNumber,string(options.testName)),'Interpreter','none'); %Interpreter = none so that _ does not become subscribed
    xlabel('Time (s)'); ylabel('Temperature [K]');
    legend({'Bleed Input Temp(Exp)','Bleed Output Temp1(Exp)','Bleed Output Temp2(Exp)','Bleed Output Temp Avg(Exp)','Bleed Output Temp(Sim)',...
        'Ram Input Temp(Exp)','RAM Output Temp1(Exp)','RAM Output Temp2(Exp)','RAM Output Temp3(Exp)','RAM Output Temp Avg(Exp)','RAM Output Temp(Sim)',...
        'Core Temp(Sim)'},'Location','best')
    grid on;
    
    % Add two texts using normalized figure coordinates
    annotation('textbox', [0.73 0.93 0.18 0.05], 'String', sprintf('%.1f ppm',mean(TimeTable2.PreClr_Bld_Flow)), ...
        'Color', 'r', 'FontSize', 12, 'EdgeColor', 'none', 'HorizontalAlignment', 'right');
    
    annotation('textbox', [0.73 0.91 0.18 0.05], 'String', sprintf('%.1f ppm',mean(TimeTable2.PreClr_Ram_Flow)), ...
        'Color', 'b', 'FontSize', 12, 'EdgeColor', 'none', 'HorizontalAlignment', 'right');
    
    %% -------------------- GRAPH 3: NN Temperatures --------------------
    if options.plot
        figure('Name', 'NNTemperatures', 'NumberTitle', 'off','WindowState','maximized');
        plot(TimeTable2.Time, TimeTable2.PreClr_Bld_In_T, 'LineWidth', 1.5,'Color',colorRedSatFaded); hold on;
        plot(TimeTable2.Time, TimeTable2.PreClr_Bld_Out_T1, 'LineWidth', 0.4,'Color',colorOrangeFadedFaded);
        plot(TimeTable2.Time, TimeTable2.PreClr_Bld_Out_T2, 'LineWidth', 0.4,'Color',colorOrangeFadedFaded);
        plot(TimeTable2.Time, TimeTable2.PreClr_Bld_Out_T_Avg, 'LineWidth', 1.5,'Color',colorOrangeSatFaded);
        plot(TimeTable2.Time, TimeTable2.PreClr_Ram_In_T, 'LineWidth', 1.5,'Color',colorBlueDarkSatFaded);
        plot(TimeTable2.Time, TimeTable2.PreClr_Ram_Out_T1, 'LineWidth', 0.4,'Color',colorBlueLightFadedFaded);
        plot(TimeTable2.Time, TimeTable2.PreClr_Ram_Out_T2,'LineWidth', 0.4,'Color',colorBlueLightFadedFaded);
        plot(TimeTable2.Time, TimeTable2.PreClr_Ram_Out_T3,'LineWidth', 0.4,'Color',colorBlueLightFadedFaded);
        plot(TimeTable2.Time, TimeTable2.PreClr_Ram_Out_T_Avg, 'LineWidth', 1.5,'Color',colorBlueLightSatFaded);
        plot(TimeTable2.Time, thot,'--', 'LineWidth', 1.5,'Color',colorOrangeSat);
        plot(TimeTable2.Time, tcold,'--', 'LineWidth', 1.5,'Color',colorBlueLightSat);
        plot(TimeTable2.Time, tpc, '--', 'LineWidth', 1.5,'Color',colorBlack);
        
        xline(TimeToConsolidateInitialConditions,'--','Label',sprintf('Consolidation to initial conditions'))
        xlabel('Time (s)'); ylabel('Temperature [K]');
        grid on;

        if ~(options.NNModelType == "None")
            %NN Plots
            plot(TimeTable2.Time, thot_NN,':', 'LineWidth', 1.5,'Color',colorOrangeSat);
            plot(TimeTable2.Time, tcold_NN,':', 'LineWidth', 1.5,'Color',colorBlueLightSat);
            plot(TimeTable2.Time, tpc_NN, ':', 'LineWidth', 1.5,'Color',colorBlack);
    
            title(sprintf('Classical x NN Simulation Temperatures [Experiment Label (%i): %s]',options.testNumber,string(options.testName)),'Interpreter','none'); %Interpreter = none so that _ does not become subscribed
             
            legend({'Bleed Input Temp(Exp)','Bleed Output Temp1(Exp)','Bleed Output Temp2(Exp)','Bleed Output Temp Avg(Exp)', ...
            'Ram Input Temp(Exp)','RAM Output Temp1(Exp)','RAM Output Temp2(Exp)','RAM Output Temp3(Exp)','RAM Output Temp Avg(Exp)','Bleed Output Temp(Sim)','RAM Output Temp(Sim)',...
            'Core Temp(Sim)','Bleed Output Temp(NN)','RAM Output Temp(NN)','Core Temp(NN)'},'Location','best')
        else
            title(sprintf('Classical Simulation Temperatures [Experiment Label (%i): %s]',options.testNumber,string(options.testName)),'Interpreter','none'); %Interpreter = none so that _ does not become subscribed
             
            legend({'Bleed Input Temp(Exp)','Bleed Output Temp1(Exp)','Bleed Output Temp2(Exp)','Bleed Output Temp Avg(Exp)', ...
            'Ram Input Temp(Exp)','RAM Output Temp1(Exp)','RAM Output Temp2(Exp)','RAM Output Temp3(Exp)','RAM Output Temp Avg(Exp)','Bleed Output Temp(Sim)','RAM Output Temp(Sim)',...
            'Core Temp(Sim)'},'Location','best')
        end
        
        
        % Add two texts using normalized figure coordinates
        annotation('textbox', [0.73 0.93 0.18 0.05], 'String', sprintf('%.1f ppm',mean(TimeTable2.PreClr_Bld_Flow)), ...
            'Color', 'r', 'FontSize', 12, 'EdgeColor', 'none', 'HorizontalAlignment', 'right');
        
        annotation('textbox', [0.73 0.91 0.18 0.05], 'String', sprintf('%.1f ppm',mean(TimeTable2.PreClr_Ram_Flow)), ...
            'Color', 'b', 'FontSize', 12, 'EdgeColor', 'none', 'HorizontalAlignment', 'right');
    end
    
    %% figure adjustment so they show up in an orderly way
    % Define a 2x3 grid of figure windows on the screen
    nRows = 2; nCols = 3;
    
    % Get monitor size (in pixels)
    set(0,'Units','pixels');
    scr = get(0,'ScreenSize');  % [left bottom width height]
    
    % Margins and sizing (in pixels)
    margin = 40;
    W = (scr(3) - (nCols+1)*margin) / nCols; % width per window
    H = (scr(4) - (nRows+1)*margin) / nRows; % height per window
    
    % Plot indices in top-row-first order: 1..3 top, 4..6 bottom
    for k = 1:(nRows*nCols)
        % Convert k to (row, col) with row 1 at the top
        row = ceil(k / nCols);           % 1..nRows
        col = k - (row-1)*nCols;         % 1..nCols
    
        % Compute window position: screen coordinates have y=0 at bottom
        y_from_top = margin + (row-1)*(H + margin);
        y = scr(4) - y_from_top - H-30;     % convert to bottom-origin
        x = margin + (col-1)*(W + margin);
        try
            f = figure(k); shg;
            set(f, 'Units','pixels', 'Position', [x, y, W, H]);
            %title(sprintf('Figure %d (row=%d, col=%d)', k, row, col));
        end
end


end