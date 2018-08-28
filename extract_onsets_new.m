%% extract_onsets.m function
% This function takes the .log files, and extracts the onset times for the
% start and stop events within the trial. 

% If cleans up the .log files in many ways, and generates an output table
% that states if there were any errors.

%% Define global variables
clear; clc; close all;
dbstop if error;

warning('off','MATLAB:table:RowsAddedExistingVars');

% Define where the files are
home = 'C:\Users\levan\human-rat-analog';

% Create an array of paths to each log file
filepaths = sort_nat(lsDir(fullfile(home,'LOG'),{'log'}))';

% Create a report table
error_table   = table;
error_counter = 1;

%% Start looping over files
for iLog = 1:length(filepaths)
    
    % Reset durations and onsets files
    durations = cell(1,2);
    onsets    = cell(1,2);
    names     = {'cued' 'hidden'};
    
    iLog
    filepaths{iLog}
    tbl = import_log_files(filepaths{iLog});
     
    %% Get sub_ID and conditions
    
    % Look inside the path to see which subject this file belongs to
    split_name = strsplit(filepaths{iLog},'_');
    sub_ID = strsplit(split_name{1},'\');
    sub_ID = sub_ID{end};
    
    % Look inside the path to see which stage this log belongs to: learning or retest
    if strfind(filepaths{iLog},'learning')
        stage = 'learning';
    elseif strfind(filepaths{iLog},'retest')
        stage = 'retest';
    else
        error('Somethings up with names');
    end
    
    % Look inside the path to see which condition this log file belongs to: allo or ego
    if strfind(split_name{end},'ego')
        condition = 'ego';
    elseif strfind(split_name{end},'allo')
        condition = 'allo';
    else
        error('Somethings up with getting condition name');
    end
    
    % Create the name of the file by which it will be saved:
    file_save_name    = ['sub_' sub_ID '_' stage '.mat'];
    file_save_name_30 = ['sub_' sub_ID '_' stage '_30sec.mat'];
    
    %% Loop by trial ID, and record onsets and durations
    all_trials = unique(tbl.trial_ID);
    if ~isequal(all_trials',1:16)
       % Update error table 
       disp('Not 16 trials');
       % Update error table
       error_table.sub_ID    {error_counter} = sub_ID;
       error_table.condition {error_counter} = condition;
       error_table.stage     {error_counter} = stage;
       error_table.filepath  {error_counter} = filepaths{iLog};
       error_table.error_type{error_counter} = [int2str(numel(all_trials)) ' Trials, instead of 16'];
       
       error_counter = error_counter + 1;
    end
    
    % Mark the rows that have "Begin", "Stopped", and "End";
    begin_idx   = find(strcmp(tbl.event_type,'Begin'));
    stopped_idx = find(strcmp(tbl.event_type,'Stopped'));
    end_idx     = find(strcmp(tbl.event_type,'End'));
    
    for iTrial = 1:numel(all_trials)
        
        % Reset the variables
        iTrial_idx = [];
        has_begin = [];
        has_stopped = [];
        has_end = [];
        trial_names = [];        
        is_cued = [];
        iDuration = [];
        begin_timestamp = [];
        stopped_timestamp = [];
        end_timestamp = [];
        skip_trial = 0;
        
        iTrial_idx = find(tbl.trial_ID == iTrial);
        
        
        %% Get begin info
        has_begin = intersect(iTrial_idx,begin_idx);
        if iTrial ~= 1
            
            % Check that begin line exists
            assert(~isempty(has_begin),'No Begin line');
            if sum(numel(has_begin)) > 1
                disp('More than 1 begin line within a trial');
                % Update error table
                error_table.sub_ID    {error_counter} = sub_ID;
                error_table.condition {error_counter} = condition;
                error_table.stage     {error_counter} = stage;
                error_table.filepath  {error_counter} = filepaths{iLog};
                error_table.trial_ID  {error_counter} = iTrial;
                error_table.error_type{error_counter} = 'More than 1 begin line within a trial';
                
                error_counter = error_counter + 1;
            end
            
            begin_timestamp = tbl.sync_onset(has_begin(1)); % always takes the first "begin" line
        elseif iTrial == 1
            
            % First begin line never exists in the log file, so that onset is 0.
            begin_timestamp = 0;
        end
        
        %% Get end info
        has_end = intersect(iTrial_idx,end_idx);
        
        if sum(numel(has_end)) > 1
            disp('More than 1 end line within a trial');
            % Update error table
            error_table.sub_ID    {error_counter} = sub_ID;
            error_table.condition {error_counter} = condition;
            error_table.stage     {error_counter} = stage;
            error_table.filepath  {error_counter} = filepaths{iLog};
            error_table.trial_ID  {error_counter} = iTrial;
            error_table.error_type{error_counter} = 'More than 1 end line within a trial';
            
            error_counter = error_counter + 1;
        elseif isempty(has_end)
            disp('No end line');
            % Update error table
            error_table.sub_ID    {error_counter} = sub_ID;
            error_table.condition {error_counter} = condition;
            error_table.stage     {error_counter} = stage;
            error_table.filepath  {error_counter} = filepaths{iLog};
            error_table.trial_ID  {error_counter} = iTrial;
            error_table.error_type{error_counter} = 'No end line!';
            
            error_counter = error_counter + 1;
            
        end
        
        if ~isempty(has_end)
            end_timestamp = tbl.sync_onset(has_end(1)); % always takes the first "end" line within the trial
        end
        
        %% Get stopped info
        has_stopped = intersect(iTrial_idx,stopped_idx);
        
        if ~isempty(has_stopped) % so if "Stopped" line exists
            stopped_timestamp = tbl.sync_onset(has_stopped(1)); % always takes the first "stopped" line within the trial.
            
            iDuration = stopped_timestamp - begin_timestamp;
        
        elseif isempty(has_stopped) % if "Stopped" doesn't exist, take 15 seconds before the "End" line.
            filepaths{iLog}
            disp('No stopped');
            iTrial

            disp('No stopped line');
            % Update error table
            error_table.sub_ID    {error_counter} = sub_ID;
            error_table.condition {error_counter} = condition;
            error_table.stage     {error_counter} = stage;
            error_table.filepath  {error_counter} = filepaths{iLog};
            error_table.trial_ID  {error_counter} = iTrial;
            error_table.error_type{error_counter} = 'No "Stopped" line. Took "End"-15 as timestamp';
            
            error_counter = error_counter + 1;
            
            if ~isempty(has_end)
                stopped_timestampe = tbl.sync_onset(has_end(1)) - 15;
                
                iDuration = stopped_timestamp - begin_timestamp;
            else
                % Theres no "End" line and no "Stopped" line. Skip this
                % trial
                skip_trial = 1;
            end
        end
        
        %% Get trial type, cued or hidden. And write in the file
        trial_names = tbl.trial_Name(iTrial_idx);
        is_cued = ~isempty(strfind(trial_names{1},'cue'));
                
        if iDuration < 2000 % so sometimes it was too short, that must be a bug.
            disp('Duration too short');
            % Update error table
            error_table.sub_ID    {error_counter} = sub_ID;
            error_table.condition {error_counter} = condition;
            error_table.stage     {error_counter} = stage;
            error_table.filepath  {error_counter} = filepaths{iLog};
            error_table.trial_ID  {error_counter} = iTrial;
            error_table.error_type{error_counter} = 'Duration too short. Must be a bug';
            
            error_counter = error_counter + 1;
            
            skip_trial = 1;
        end
        
        if ~skip_trial
            % Duration is good 
            
            if is_cued
                % Update durations 
                durations{1,1} = [durations{1,1}; iDuration/1000];
                onsets{1,1}    = [onsets{1,1}; begin_timestamp/1000];
            else % then its the hidden condition
                % Update durations
                durations{1,2} = [durations{1,2}; iDuration/1000];
                onsets{1,2}    = [onsets{1,2}; begin_timestamp/1000];
            end
        end % skip_trial
    end % iTrial

%% Do some checks 

% sizes of durations and onsets are equal
    
%% Save data

% save real durations     
save(fullfile(home,'new_onsets',file_save_name),   'onsets','durations','names');

% Now create and save 30 second durations
durations{1,1} = repmat(30,length(durations{1,1}),1);
durations{1,2} = repmat(30,length(durations{1,2}),1);

save(fullfile(home,'new_onsets',file_save_name_30),'onsets','durations','names');

end % iLog

% Save error table
save(fullfile(home,'error_table_new.mat'),'error_table');