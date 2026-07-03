% ----------- add function-----------
% addpath(genpath('/home/experiment/Documents/EEG_analysis/function'));

[filelist, filepath] = uigetfile({'*.mat','Matlab data Files (*.mat)'}, ...
    'Select EEG Files', 'MultiSelect', 'on');

if isequal(filelist, 0)
    error('No files selected.');
end

if ischar(filelist)
    filelist = {filelist};  %transfer to cell array
end

% ====== set  ITC structure ======
ITC_all = struct();
save_dir = fullfile(filepath, 'ITC_results');  
if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

savename = '-10Hz';  % change stimulation frequency
% fmHz      = 3;  % sound frequency

% ========== main loop ==========
for j = 1:length(filelist)
    file_name = filelist{j};
    file_path = fullfile(filepath, file_name);
    fprintf('Processing %s\n', file_name);

    tmp = load(file_path);
    var_names = fieldnames(tmp);

    data_ep = [];

    % export subj_id（if filename subjID_xxx.mat）
    [~, base, ~] = fileparts(file_name);
    parts   = split(base, '_');
    subj_id_raw = parts{1};
    subj_id = matlab.lang.makeValidName(subj_id_raw);  % transfer to 's1_3Hz'

    for k = 1:length(var_names)
        candidate = tmp.(var_names{k});
        if isfield(candidate, 'trialinfo')
            data_ep = candidate;
            break;
        end
    end

    if isempty(data_ep)
        warning('No valid data found in %s, skipping.', file_name);
        continue;
    end

      % ================== add actualPhase to trialinfo ===================
fprintf('Computing actualPhase for %s ...\n', subj_id);

TI = data_ep.trialinfo;   % table
nTrials = height(TI);

% 
if ~ismember('initPhase', TI.Properties.VariableNames)
    error('trialinfo lack initPhase');
end
if ~ismember('phaseDeg', TI.Properties.VariableNames)
    error('trialinfo lack phaseDeg');
end

    % 
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

    % add data_ft & phase_data 
    data_ep.trialinfo   = TI;


% ----------- Time-Frequency （Fourier）-----------
        cfg_tfr = [];
        cfg_tfr.method     = 'mtmconvol'; % 'wavelet'
        cfg_tfr.taper        = 'hanning';
        cfg_tfr.output     = 'fourier';
        cfg_tfr.foi        = 5:0.1:20;
        cfg_tfr.toi        = -2:0.1:4;
        % cfg_tfr.width      = linspace(3,5,length(cfg_tfr.foi));
        cfg_tfr.t_ftimwin    = 12 ./ cfg_tfr.foi;
        cfg_tfr.keeptrials = 'yes';
        cfg_tfr.pad        = 'nextpow2';
        cfg_tfr.channel    = 'all';

        freq_fourier = ft_freqanalysis(cfg_tfr, data_ep);

        % ----------- ITPC & ITLC -----------
        F = freq_fourier.fourierspctrm;  % dim: trials x channels x freqs x times
        N = size(F,1);

        itc = [];
        itc.label    = freq_fourier.label;
        itc.freq     = freq_fourier.freq;
        itc.time     = freq_fourier.time;
        itc.dimord   = 'chan_freq_time';

        % ITPC: Inter-trial phase coherence
        F_phase = F ./ abs(F);                      
        itpc = abs(squeeze(sum(F_phase,1)) / N);    
        itc.itpc = itpc;

        % ITLC: Inter-trial linear coherence
        F_amp = abs(F).^2;
        numer = abs(squeeze(sum(F,1)));
        denom = sqrt(N * squeeze(sum(F_amp,1)));
        itc.itlc = numer ./ denom;
        data_ep.trialinfo

       % save
        itc.trialinfo = data_ep.trialinfo; 
        ITC_all.(subj_id) = itc;
    
        fprintf('✅ Saved ITC for %s\n', subj_id);
end


% save
savefile = '/home/experiment/Documents/EEG_data/gabor_detection/trasfer2fieldtrip/ITC_results/';
save_filename = fullfile(savefile, ['ITC_all' savename '.mat']);  % 例如 ITC_all-3Hz.mat

% save
save(save_filename, 'ITC_all');
fprintf('✅ All ITC results saved to %s\n', save_filename);
