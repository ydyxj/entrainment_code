clear all; close all;clc 

savename = '-10Hz'; %sub1-3hz/10hz
behaname = '_10Hz';
%% change format
% Import Data 
% Subj= {'1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24', '25', '26', '27', '28', '29', '31', '32', '33', '34', '35', '36', '37', '38', '39', '40'};	
Subj= {'1','2', '3', '4', '5', '6', '7','8', '9', '10', '11','12', '13','14','15','16','17', '18',  '19', '20', '21'};	

for i = 1:length(Subj)
    %subject name
    rawname = strcat('sub',num2str(i),savename,'.vhdr'); 
    setname = strcat('s',num2str(i),savename,'.set'); %s1_3hz

    %Open EEGLAB and ERPLAB Toolboxes  
    [ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
    
    %import data, don't forget to change the datapath\
    EEG = pop_loadbv('/home/experiment/Documents/EEG_data/gabor_detection/Rawdata', rawname, [], []);
    
    %save data to disc
    EEG = pop_saveset( EEG, 'filename',setname,'filepath','/home/experiment/Documents/EEG_data/gabor_detection/Predata');
end

%% adding behaviroal info
for i = 1:length(Subj)
    % i = str2double(Subj{k}); 
   %set name
    setname = strcat('s',num2str(i),savename,'.set');  
    
    %Open EEGLAB and ERPLAB Toolboxes  
    [ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

    % import .set data
    EEG = pop_loadset('filename',setname,'filepath','/home/experiment/Documents/EEG_data/gabor_detection/Predata');

% find all S1 trigger
    s1Trig = find(strcmp({EEG.event.type}, 'S  1'));
    nPhoton = numel(s1Trig);
   
% each two trigger in one trial
    nTrialsEEG = floor((nPhoton)/2); 

    soundLatency  = nan(nTrialsEEG,1);
    visualLatency = nan(nTrialsEEG,1);
    soundUrevent  = nan(nTrialsEEG,1);
    visualUrevent = nan(nTrialsEEG,1);

    photonEvents = EEG.event(s1Trig);  

    for tr = 1:nTrialsEEG
        soundLatency(tr)  = photonEvents(2*tr-1).latency;
        visualLatency(tr) = photonEvents(2*tr).latency;
        soundUrevent(tr)  = photonEvents(2*tr-1).urevent;
        visualUrevent(tr) = photonEvents(2*tr).urevent;

        idxSound  = find([EEG.event.urevent]==soundUrevent(tr),1,'first');
        idxVisual = find([EEG.event.urevent]==visualUrevent(tr),1,'first');
        if ~isempty(idxSound),  EEG.event(idxSound).type  = 'sound';  end
        if ~isempty(idxVisual), EEG.event(idxVisual).type = 'visual'; end
    end

    EEG = eeg_checkset(EEG, 'eventconsistency');
    
% transfer to second
    soundTimeSec  = soundLatency  / EEG.srate;
    visualTimeSec = visualLatency / EEG.srate;

% add to eegdata
    trialsEEG = table((1:nTrialsEEG)', soundLatency, visualLatency, ...
                  soundTimeSec, visualTimeSec, ...
                  soundUrevent, visualUrevent, ...
                  'VariableNames', {'Trial','SoundLat','VisualLat','SoundSec','VisualSec','SoundUrev','VisualUrev'});

    disp(trialsEEG(1:5,:)); % check first 5 trials

% load behavioral data
behavname = fullfile('/home/experiment/Documents/toolbox/Bauer/results/', ['s' Subj{i}, behaname, '_allBlocks.mat']);
load(behavname, 'allLog');

if height(allLog) ~= nTrialsEEG
    warning('please check, the number of EEG trials and behavior trials！');
end

allTrials = [trialsEEG allLog];  % behavior phaseDeg, targetTime, initPhase, acc, rt

% add to EEG.event ======
for tr = 1:height(allTrials)
    % --- sound trigger ---
    evIdxSound = find([EEG.event.latency]==allTrials.SoundLat(tr), 1, 'first');

    if ~isempty(evIdxSound)
        EEG.event(evIdxSound).trial      = tr;
        EEG.event(evIdxSound).type   = 'sound';
        EEG.event(evIdxSound).phaseDeg   = allTrials.phaseDeg(tr);
        EEG.event(evIdxSound).targetTime = allTrials.targetTime(tr);
        EEG.event(evIdxSound).initPhase  = allTrials.initPhase(tr);
        EEG.event(evIdxSound).acc        = allTrials.acc(tr);
        EEG.event(evIdxSound).rt         = allTrials.rt(tr);
        EEG.event(evIdxSound).Correction         = allTrials.Correction(tr);
        EEG.event(evIdxSound).actualtime         = allTrials.actualtime(tr);
        EEG.event(evIdxSound).orientationDeg         = allTrials.orientationDeg(tr);
        EEG.event(evIdxSound).f0         = allTrials.f0(tr);
        EEG.event(evIdxSound).phaseIdx         = allTrials.phaseIdx(tr);
        EEG.event(evIdxSound).block         = allTrials.block(tr);
    end
    
    % --- visual trigger ---
     evIdxVisual = find([EEG.event.urevent]==allTrials.VisualUrev(tr), 1, 'first');
    if ~isempty(evIdxVisual)
        EEG.event(evIdxVisual).trial      = tr;
        EEG.event(evIdxVisual).type   = 'visual';
        EEG.event(evIdxVisual).phaseDeg   = allTrials.phaseDeg(tr);
        EEG.event(evIdxVisual).targetTime = allTrials.targetTime(tr);
        EEG.event(evIdxVisual).initPhase  = allTrials.initPhase(tr);
        EEG.event(evIdxVisual).acc        = allTrials.acc(tr);
        EEG.event(evIdxVisual).rt         = allTrials.rt(tr);
    end
end

% delay between trigger and stimulus
delayLatency = 13/1000;
for h = 1:length(EEG.event)
    if isfield(EEG.event, 'type') && strcmp(EEG.event(h).type, 'sound')
        EEG.event(h).latency = EEG.event(h).latency + (EEG.event(h).Correction - delayLatency) * EEG.srate;
    end
end

% check the whether visual presents in the target time
soundLatency  = [EEG.event(strcmp({EEG.event.type}, 'sound')).latency];
visualLatency = [EEG.event(strcmp({EEG.event.type}, 'visual')).latency];
diffSec= (visualLatency - soundLatency) / EEG.srate;

% % compared with actualtime
% % isClose = abs(diffSec - EEG.event(evIdxSound).actualtime) < 1e-3;
actualtime = [EEG.event(strcmp({EEG.event.type}, 'sound')).actualtime]; % 1xN 或 Nx1
actualtime = actualtime(:)';  
delay = diffSec - actualtime;  

%save data to disc
    EEG = pop_saveset( EEG, 'filename',strcat('s',num2str(i),savename,'_bh','.set'),'filepath','/home/experiment/Documents/EEG_data/gabor_detection/behavior');

end

%% preprocessing

% Import Data
for i = 1:length(Subj)

    %set name
    setname = strcat('s',num2str(i),savename,'_bh','.set');  
    
    %Open EEGLAB and ERPLAB Toolboxes  
    [ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

    % import .set data
    EEG = pop_loadset('filename',setname,'filepath','/home/experiment/Documents/EEG_data/gabor_detection/behavior');
    
    %Channels location
    EEG=pop_chanedit(EEG, 'lookup','/home/experiment/Documents/eeglab14_1_2b/plugins/dipfit2.3/standard_BEM/elec/standard_1005.elc');

    %  %add the initial reference electrode back
    % [EEG.chanlocs.ref] = deal('POz');
    % 
    % EEG = pop_chanedit(EEG, 'append',31,'changefield',{32 'labels' 'POz'},'lookup','/home/experiment/Documents/eeglab14_1_2b/plugins/dipfit2.3/standard_BEM/elec/standard_1005.elc',...
    %                'eval','chans = pop_chancenter( chans, [],[]);','changefield',{32 'type' 'REF'});
    % EEG = pop_reref( EEG, [],'refloc',struct('labels',{'POz'},'type',{'REF'},'theta',{180},'radius',{0.37994},'X',{-79.0255},'Y',{-9.6778e-15},'Z',{31.3044},...
    %                 'sph_theta',{-180},'sph_phi',{21.61},'sph_radius',{85},'urchan',{32},'ref',{''},'datachan',{0}));
  
    %filter
   EEG = pop_eegfiltnew(EEG, 1,40);  %keep alpha 

    %down sampling rate to 500Hz
    EEG = pop_resample(EEG, 500);
    [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 4, 'setname', [strcat('s',num2str(i),savename,'_fil_resamp')], 'savenew', [strcat('s',num2str(i),savename, '_fil_resamp','.set')], 'gui', 'off'); 
      
%save data to disc
    EEG = pop_saveset( EEG, 'filename',strcat('s',num2str(i),savename,'_fil_resamp','.set'),'filepath','/home/experiment/Documents/EEG_data/gabor_detection/fildata');
    
end

%% epoch
for i = 1:length(Subj)
   subj_id = Subj{i};  
    icadata = strcat('s',num2str(i),savename, '_fil_resamp','.set');  %s1EN_fil_resamp_ica.set

%Open EEGLAB and ERPLAB Toolboxes  
    [ALLEEG EEG CURRENTSET ALLCOM] = eeglab; 

% Import Data 
    EEG = pop_loadset('filename',icadata,'filepath','/home/experiment/Documents/EEG_data/gabor_detection/fildata');

    if ~isfield(EEG.event, 'initPhase')
        error('⚠️ cannot find  initPhase in EEG.event, please check! ');
    end

    % find sound event
    sound_idx = find(strcmp({EEG.event.type}, 'sound'));
    nTrials = numel(sound_idx);
    fprintf('find %d sound event \n', nTrials);

    soundLat  = [EEG.event(sound_idx).latency];  % samples
    
    % export initial phase for each trial
    initPhase = [EEG.event(sound_idx).initPhase];

    % calculate shift time range
    % shiftSec = mod(-initPhase ./ (2*pi*fmHz), 1/fmHz); 
    shiftSec = -initPhase ./ (2*pi*fmHz); 
    fs = EEG.srate;
    fprintf('shift range: %.3f ~ %.3f s\n', min(shiftSec), max(shiftSec));
  
    if ~isfield(EEG.event, 'phaseShiftSec')
    [EEG.event.phaseShiftSec] = deal(nan);  
    end
    if ~isfield(EEG.event, 'fmHz')
    [EEG.event.fmHz] = deal(nan);
    end

    T  = 1/fmHz;  % period (sec)
    
    % add phase0 event
    for tr = 1:nTrials
        ev = EEG.event(sound_idx(tr));  
        new_event = ev;  
        evLat   = ev.latency;

        % calculate the latency for phase0
        new_event.latency = evLat + shiftSec(tr) * fs;
        newLat = new_event.latency;
    if tr > 1
        prevLat = soundLat(tr-1);
        if newLat <= prevLat
            newLat = round(evLat - T*fs);  
        end
    end

    % make sure the relationship between sound and phase0
    if newLat >= evLat
        newLat = evLat - 1;
    end

    newLat = max(newLat, 1);

        % add phase 0
        new_event.type = 'phase0';
        new_event.latency       = newLat;
        new_event.duration      = 0;
        % export shift info
        new_event.phaseShiftSec = shiftSec(tr);
        new_event.fmHz = fmHz;

        % add to event
        EEG.event(end+1) = new_event;

    end

    %check consistency
    EEG = eeg_checkset(EEG, 'eventconsistency');
    fprintf('✅ add phase0。\n');

    epochWin = [-2 4];  
    EEG = pop_epoch(EEG, {'sound'}, epochWin);

    fprintf('✅ all epoch were finished. \n');

 %   epoch
    EEG = eeg_checkset(EEG);

    [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 4, 'setname', [strcat('s',num2str(i),savename, '_fil_resamp_epoch')], 'savenew', [strcat('s',num2str(i),savename, '_fil_resamp_epoch','.set')], 'gui', 'off'); 

 %save to disc
 EEG = pop_saveset( EEG, 'filename',strcat('s',num2str(i),savename,'_fil_resamp_epoch','.set'),'filepath','/home/experiment/Documents/EEG_data/gabor_detection/epochdata');

end

%% manually remove artifact epoches
eeglab

%check signal
pop_eegplot( EEG);

%run Ica
EEG = pop_runica(EEG, 'extended',1,'interupt','on');
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, 'overwrite', 'on', 'gui', 'off');

% % IC label
EEG = pop_chanedit(EEG, 'lookup','standard-10-5-cap385.elp');
EEG = pop_iclabel(EEG, 'default');

%flag bad component
EEG = pop_icflag(EEG, [NaN NaN;0.9 1;0.9 1;NaN NaN;NaN NaN;NaN NaN;NaN NaN]);

%see flag component
pop_selectcomps(EEG, [1:30] );

%remove flag according to flaged result
EEG = pop_subcomp( EEG, [3], 0);

%interpolate
pop_eegplot( EEG);
EEG = pop_interp(EEG, [1 2], 'spherical');

%reject artifact trials
EEG = pop_eegthresh(EEG, 1, 1:EEG.nbchan, -70, 70, EEG.xmin, EEG.xmax, 1, 0);
EEG.reject.rejmanual = EEG.reject.rejthresh;
EEG.reject.rejmanualE = EEG.reject.rejthreshE;
pop_eegplot(EEG, 1, 1, 1);  

%% made fieldtrip file for analysis 
addpath('CSDtoolbox');   

% Import Data
for i = 1:length(Subj)
    subj_id = Subj{i};  
    epochdata = strcat('s',subj_id,savename,'_fil_resamp_ica epochs','.set');  

% Import Data    
    EEG = pop_loadset('filename',epochdata,'filepath','/home/experiment/Documents/EEG_data/gabor_detection/rejdata');

    label_list = cellstr(char({EEG.chanlocs.labels}));
    montage = ExtractMontage('10-5-System_Mastoids_EGI129.csd', label_list);

    [G,H] = GetGH(montage);

  %baseline correction
    EEG = pop_rmbase( EEG, [-200 0]);

    % EEG = pop_eegfiltnew(EEG,[],25);  %keep alpha
    
    % re-reference
    EEG = pop_reref(EEG,  [1:30] , 'keepref', 'on', 'exclude', []); % re-reference, keeping ref channels in the data set

    % surface Laplacian transform
    EEG.data = CSD(EEG.data, G, H);

    %save to disc
    EEG = pop_saveset( EEG, 'filename',strcat('s',subj_id,savename, '_tfpre','.set'),'filepath','/home/experiment/Documents/EEG_data/gabor_detection/trpre');
end

%% ===== Transfer EEGlab dataset to FieldTrip =====
[filelist, filepath] = uigetfile({'*.set','EEG Files (*.set)'}, ...
    'Select EEG Files', 'MultiSelect', 'on');

if isequal(filelist, 0)
    error('No files selected.');
end

if ischar(filelist)
    filelist = {filelist};
end

save_path = '/home/experiment/Documents/EEG_data/gabor_detection/trasfer2fieldtrip';
if ~exist(save_path, 'dir')
    mkdir(save_path);
end

for j = 1:length(filelist)
    filename = filelist{j};
    [~, name_noext, ~] = fileparts(filename); 
    
    % --- Load EEG (EEGLAB) ---
    EEG = pop_loadset('filename', filename, 'filepath', filepath);

    % --- Convert to FieldTrip format ---
    data_input = eeglab2fieldtrip(EEG, 'preprocessing', 'none');
    
    % --- Transfer events (trigger info) ---
    events = EEG.event;
    
 
    data_input.cfg.event = events;

    % --- Save ---
    save_filename = fullfile(save_path, [name_noext '_fieldtrip_target.mat']);
    save(save_filename, 'data_input');
    fprintf('[%d/%d] Saved FieldTrip data to: %s\n', j, length(filelist), save_filename);
end

fprintf('✅ All files converted. Events aligned to visual triggers (if EEG.event.type are visual onset codes).\n');

