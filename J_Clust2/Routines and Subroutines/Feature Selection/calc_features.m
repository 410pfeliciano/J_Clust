function features = calc_features(waveforms, num_spks, num_samples, Fs)

%Description: This .m file calculates spike features for all detected spikes in the current session
%
%Input: 'waveforms' = detected spike waveforms, 'num_spks' = total number of spikes, 'num_samples' = number of samples in spike waveform, 
%'Fs' = sampling rate
%
%Output: 'features' = a 2 column cell array where the 1st column is the spike feature calculated, and the 2nd column contains a string with the name 
%of that spike feature
%

features = cell(12,2);

num_waveforms = num_spks * 4;

%convert to 2d matrix for easier feature calculation (number_spikes X number_samples)
waveforms_2d = reshape(permute(waveforms, [1 3 2]), 4 * num_spks, num_samples);
concat_waveforms = reshape(permute(waveforms,[2,1,3]), [4 * num_samples, num_spks]);

% optional: uncomment to calculate variance between all waveforms for all channels or individual channels
% var_waveform_samples_all = var(waveforms_2d,0,1);
% 
% var_waveform_samples_ch = zeros(4, num_samples);
% for i = 1:4
%     var_waveform_samples_ch(i,:) = var(squeeze(waveforms(i,:,:)),0,2);
% end

%% Peak Amps & related features
peak_indx = floor(1/3 * num_samples - 1) + 1; %pre_peak samples + 1
peak_amps_vec = max(waveforms_2d(:,1:peak_indx),[],2);
peak_amps = reshape(peak_amps_vec,4,num_spks);

trough_vec = min(waveforms_2d(:,peak_indx:end),[],2);
crest_trough_vec = peak_amps_vec - trough_vec;
crest_trough = reshape(crest_trough_vec,4,num_spks);

%% Energy and Power

energy_vec = sum((waveforms_2d.^2),2);
energy = reshape(energy_vec,4,num_spks);

power = energy ./ 32;

% optional: uncomment to find best channels (i.e. closest i.e. channels sorted by greatest power)
% [~, best_chs] = sort(mean(power,2),'descend');
%% PCA
warning 'off'
%PC scores for entire dataset, channel by channel 

pc_coeffs = zeros(4, num_samples, num_samples);
pc_scores = zeros(4, num_spks, num_samples);
pc_variance = zeros(num_samples, 4);
pc_var_retained = zeros(num_samples, 4);
pc_mus = zeros(4, num_samples);

parfor i = 1:4
    [pc_coeffs(i,:,:), pc_scores(i,:,:), pc_variance(:,i), ~, pc_var_retained(:,i), pc_mus(i,:)] = pca2(squeeze(waveforms(i,:,:))');
end

%PC Scores for concatenated waveforms

[pc_coeffs_c, pc_scores_c, pc_variance_c, ~, pc_var_retained_c, pc_mus_c] = pca2(concat_waveforms');

warning 'on'
%% Wavelet coeffs (daub8)

% [db4_best_cs, db4_wvlet_cs, db4_wvlets_cs_f, db4_cA, db4_cD] = MyDWT1(waveforms,num_spks,4,2,'db4');
% 
% %db4 best coeff for entire dataset
% db4_2_coeffs = vertcat(squeeze(db4_wvlets_cs_f(1,db4_best_cs(1,1),:))', squeeze(db4_wvlets_cs_f(2,db4_best_cs(2,1),:))',...
%     squeeze(db4_wvlets_cs_f(3,db4_best_cs(3,1),:))', squeeze(db4_wvlets_cs_f(4,db4_best_cs(4,1),:))');
% 
% %db4 3 best coeffs for each channel
% db4_2_ch_coeffs = cell(4,1);
% for i = 1:4
%     db4_2_ch_coeffs{i} = squeeze(db4_wvlets_cs_f(i,db4_best_cs(i,:),:));
% end

%% Width

interpolated_waveforms_2d = csapi([1:1:num_samples],waveforms_2d(:,1:num_samples),[1:0.2:num_samples]); %interpolates to (5x-4) size
half_max_vec = peak_amps_vec / 2;
first_half = zeros(num_waveforms,1);
second_half = zeros(num_waveforms,1);
for i = 1:num_waveforms
    if peak_amps_vec(i) < 0 || waveforms_2d(i, peak_indx+6) > half_max_vec(i) %if waveform doesn't resemble AP
        continue
    end
    [~, first_half(i)] = find(interpolated_waveforms_2d(i,1:(peak_indx*5-4)) >= half_max_vec(i), 1, 'first');
    [~, second_half(i)] = find(interpolated_waveforms_2d(i,(peak_indx*5-4):end) <= half_max_vec(i), 1, 'first');
end
second_half = second_half + (peak_indx*5-4);
width_samples_vec = second_half - first_half;
width_samples_vec(first_half == 0) = 0;

width_ms_vec = width_samples_vec / (Fs * 5) * 1000;
width_ms = reshape(width_ms_vec,4,num_spks);

features{1,1} = peak_amps; features{2,1} = crest_trough; features{3,1} = power; 
features{4,1} = pc_scores; features{5,1} = pc_scores_c;
%features{6,1} = db_coeffs; features{7,1} = db_coeffs_c;
features{8,1} = width_ms;
features{9,1} = pc_coeffs; features{10,1} = pc_var_retained;
features{11,1} = pc_coeffs_c; features{12,1} = pc_var_retained_c;

features{1,2} = 'Peak_Amplitudes'; features{2,2} = 'Peak_to_Peak_Amplitudes';
features{3,2} = 'Power'; features{4,2} = 'PC_Scores';
features{5,2} = 'Concatenated_PC_Scores'; 
features{6,2} = 'Wavelet_Coefficients'; features{7,2} = 'Concatenated_Wavelet_Coefficients';
features{8,2} = 'Width_ms';