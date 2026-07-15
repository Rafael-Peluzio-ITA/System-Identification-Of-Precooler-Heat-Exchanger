%% Init_Peluzio.m
% Author: Rafael Machado Peluzio
% Contact: rmpeluzio@gmail.com / 19999314029
% Date modified: 15/Jul/2026
% References: Based on similar scripts by Prof. P. M. Tasinaffo

% Description: Initializes the MATLAB environment, clears memory, locates 
% the target workspace folder within the user's Documents, sets the 
% current path, and cleans up legacy/old directories from the MATLAB path.

% Code generated using the Gemini LLM tool for efficiency. Entire code was conceptualized, 
% revised and implemented by the author.

% Remove all paths currently in the MATLAB path and clear all MATLAB
% variables
restoredefaultpath;
clc
clear all;
% Close all open figures
close all;

% Find the "Implementação Rafael Peluzio" folder within "Documents"
documentsFolder = fullfile(getenv('USERPROFILE'), 'Embraer');
targetFolder = '';

% Recursively search for the target folder
folderList = dir(documentsFolder);
targetFolder = 'Folder_IEEE_Code';
while ~isempty(folderList)
    folder = folderList(1);
    folderList(1) = [];
    if folder.isdir && ~strcmp(folder.name, '.') && ~strcmp(folder.name, '..')
        if strcmp(folder.name, targetFolder)
            targetFolder = fullfile(folder.folder, folder.name);
            break;
        else
            subFolders = dir(fullfile(folder.folder, folder.name));
            folderList = [folderList; subFolders];
        end
    end
end

% Set the current folder to the target folder if found
if ~isempty(targetFolder)
    cd(targetFolder);
    fprintf('Current folder set to: %s\n', targetFolder);
    
    % Add the target folder and all its subfolders to the MATLAB path
    addpath(genpath(targetFolder));
    fprintf('Added "%s" and all its subfolders to the MATLAB path.\n', targetFolder);
    
    
end
% Get current MATLAB path as a cell array
currentPath = strsplit(path, pathsep);

% Find all paths that contain "\old\" or end with "\old"
idxOld = contains(currentPath, [filesep 'old' filesep]) | ...
         endsWith(currentPath, [filesep 'old']) | ...
         contains(currentPath, [filesep '99. old' filesep])| ...
         endsWith(currentPath, [filesep '99. old']);

% Remove those paths
if any(idxOld)
    oldPaths = currentPath(idxOld);
    for i = 1:numel(oldPaths)
        rmpath(oldPaths{i});
        %fprintf('Removed: %s\n', oldPaths{i});
    end
    fprintf('Removed old folder from path\n');
else
    fprintf('No "old" folders found in the current path.\n');
end


% Clear all temporary variables created by this startup script
clear all;