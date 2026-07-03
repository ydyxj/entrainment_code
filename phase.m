%% ----------- add function -----------
% addpath(genpath('/home/experiment/Documents/EEG_analysis/function'));
savename = '-10Hz';  
fm =10;      % stimulation frequency in Hz

[filelist, filepath] = uigetfile({'*.mat','Matlab data Files (*.mat)'}, ...
    'Select EEG Files', 'MultiSelect', 'on');

if isequal(filelist, 0)
    error('No files selected.');
end

if ischar(filelist)
    filelist = {filelist};  
end

% ====== set structure ======
Phase_all = struct(); % save phase vector
ERP_HitMiss = struct();   % save avg_hit / avg_miss
ERP_all   = struct();     % save trial-level ERPs

save_dir = fullfile(filepath, 'Phase_results');  
if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

% ========== main loop ==========
for j = 1:length(filelist)
    file_name = filelist{j};
    file_path = fullfile(filepath, file_name);
    fprintf('Processing %s\n', file_name);

    tmp = load(file_path);
    var_names = fieldnames(tmp);

    data_ft = [];

    % extract subj_id
    [~, base, ~] = fileparts(file_name);
    parts   = split(base, '_');
    subj_id_raw = parts{1};
    subj_id = matlab.lang.makeValidName(subj_id_raw);  % transfer to 's1_3Hz'

    for k = 1:length(var_names)
        candidate = tmp.(var_names{k});
        if isfield(candidate, 'trialinfo')
            data_ft = candidate;
            break;
        end
    end

    if isempty(data_ft)
        warning('No valid data found in %s, skipping.', file_name);
        continue;
    end

    events = data_ft.cfg.event;
    nTrials_event = numel(events);
    nTrials_data  = numel(data_ft.trial);

    nUse = min(nTrials_event, nTrials_data);
 
    % === obtain acc（0/1）===
    acc = nan(nUse, 1);
    for t = 1:nUse
        if isfield(events(t), 'acc')
            acc(t) = events(t).acc;     % 1 = hit, 0 = miss
        else
            error('lack acc');
        end
    end

    % === define hit / miss index ===
    isCorrect = (acc == 1);
    isError   = (acc == 0);
    
    % ================== calculate actualPhase to add trialinfo ===================
fprintf('Computing actualPhase for %s ...\n', subj_id);

TI = data_ft.trialinfo;   % table
nTrials = height(TI);

% check
if ~ismember('initPhase', TI.Properties.VariableNames)
    error('trialinfo lack initPhase');
end
if ~ismember('phaseDeg', TI.Properties.VariableNames)
    error('trialinfo lack phaseDeg');
end

% add new info
if ~ismember('phaseRad', TI.Properties.VariableNames)
    TI.phaseRad = nan(nTrials,1);
end
if ~ismember('actualPhase', TI.Properties.VariableNames)
    TI.actualPhase = nan(nTrials,1);
end

for t = 1:nTrials
    initPhase = TI.initPhase(t);
    phaseDeg  = TI.phaseDeg(t);
    phaseRad  = deg2rad(mod(phaseDeg, 360));
    actualPhase = mod(initPhase + phaseRad, 2*pi);

    TI.phaseRad(t)    = phaseRad;
    TI.actualPhase(t) = actualPhase;
end

% add to data_ft & phase_data 
    data_ft.trialinfo   = TI;
   
   erp_data = data_ft;
   
    cfg = [];
    cfg.output = 'avg';
    cfg.keeptrials = 'no';
    cfg.channel = 'all';
    cfg.baseline = [-0.2 0];   % -200 to 0 ms
    erp_bc = ft_timelockbaseline(cfg, erp_data);

    cfg.bpfreq = [1 15];     % ERP typical band

    avg_erp = ft_timelockanalysis(cfg, erp_data);
    ERP_all.(subj_id) = erp_data;

    cfg.trials = find(isCorrect);
    avg_hit = ft_timelockanalysis(cfg, erp_data);

    cfg.trials = find(isError);
    avg_miss = ft_timelockanalysis(cfg, erp_data);

    
    ERP_HitMiss.(subj_id).hit  = avg_hit;
    ERP_HitMiss.(subj_id).miss = avg_miss;
    
% hilbert transform
% filter
    cfg_ph = [];
    cfg_ph.bpfilter = 'yes';
    cfg_ph.bpfreq = [fm-0.5 fm+0.5];
    data_beta = ft_preprocessing(cfg_ph, data_ft);

% Hilbert
    cfg_ph = [];
    cfg_ph.hilbert = 'angle';
    phase_data = ft_preprocessing(cfg_ph, data_beta);

    % add to data
    phase_data.event = events;
    Phase_all.(subj_id) = phase_data; 
    fprintf('Finished subject %s\n', subj_id);

    plot_all_trials_hitmiss( ...
    subj_id, ...
    ERP_all.(subj_id), ...
    isCorrect, ...
    'Cz', ...
    [-0.5 0.6]);
end

% save
savefile = '/home/experiment/Documents/EEG_data/gabor_detection/trasfer2fieldtrip/phase_results/';
save_filename1 = fullfile(savefile, ['Phase_all' savename '.mat']);  %  FT_all-3Hz.mat

% save(save_filename1, 'Phase_all', '-v7.3');
% fprintf('✅ All Phase results saved to %s (v7.3)\n', save_filename1);


% save
save_filename2 = fullfile(savefile, ['ERP_HitMiss' savename '.mat']);  % FT_all-3Hz.mat
save(save_filename2, 'ERP_HitMiss');
fprintf('✅ All ERP results saved to %s\n', save_filename2);

save_filename3 = fullfile(savefile, ['ERP_all' savename '.mat']);  %  FT_all-3Hz.mat
save(save_filename3, 'ERP_all');
fprintf('✅ All ERP results saved to %s\n', save_filename3);
