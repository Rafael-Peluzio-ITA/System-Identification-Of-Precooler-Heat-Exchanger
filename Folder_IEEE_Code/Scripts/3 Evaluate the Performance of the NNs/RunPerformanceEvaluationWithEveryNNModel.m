% Run the Performance Evaluation with 34 tests for every NN model available
% on the folder.

% Author: RPELUZIO
% Last Modified: 2026/01/19

%% Config

ModelType = "ETUNI";
ModelSubType = "None"; % None if no option is selected
ModelTypeForExecution = "ETUNI";

%% List every NN Model available
% Get NN Name
pattern = '\(R(.*?)\)';
tokens = regexp(version, pattern, 'tokens');
matlabVersion = tokens{:}{:};
if ModelSubType ~= "None"
    path = ['Folder_IEEE_Code\NN_Models\',char(ModelType),'\',char(ModelSubType)];
else
    path = ['Folder_IEEE_Code\NN_Models\',char(ModelType)];
end
targetDir = fullfile(pwd, path);
fileList = dir(fullfile(targetDir, '*.slx'));
[~, sortedIdx] = sort({fileList.name});
fileList = fileList(sortedIdx);

%% Run PerformanceEvaluationWith34Tests

%
for file = 1:length(fileList)
    %file = length(fileList)+1-fileInverted;
    modelFullPath = [fileList(file).folder,'\',fileList(file).name];
    realPerformanceStruct = PerformanceEvaluationWith34Tests(NNFileName=fileList(file).name,NNFullPath=modelFullPath,NNModelType=ModelTypeForExecution);
    if ~isstruct(realPerformanceStruct)
        continue
    end
    [~, onlyNetworkName, ~] = fileparts(string(fileList(file).name));
    save(string(onlyNetworkName)+".mat",'realPerformanceStruct','-append')
end

