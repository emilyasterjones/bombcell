%% info
% data
ephysPath = '/home/netshare/zaru/JF082/2022-07-25/ephys/kilosort2/site1';%pathToFolderYourEphysDataIsIn; % eg /home/netshare/zinu/JF067/2022-02-17/ephys/kilosort2/site1, whre this path contains 

% channels to plot
channelsToPlot = 1:20;
timeToPlot = [1,2]; % in seconds 

[spikeTimes_samples, spikeTemplates, ...
    templateWaveforms, templateAmplitudes, pcFeatures, pcFeatureIdx, channelPositions] = bc_loadEphysData(ephysPath);
ephysData = struct;
ephysData.spike_times = spikeTimes_samples;
ephysData.ephys_sample_rate = 30000;
ephysData.spike_times_timeline = spikeTimes_samples ./ ephysData.ephys_sample_rate;
ephysData.spike_templates = spikeTemplates;
ephysData.templates = templateWaveforms;
ephysData.template_amplitudes = templateAmplitudes;
ephysData.channel_positions = channelPositions;

ephysData.waveform_t = 1e3*((0:size(templateWaveforms, 2) - 1) / 30000);


%% get memmap
param.tmpFolder = ephysPath;
param.nChannels = 385;
bc_getRawMemMap;

%% plot raw data
bc_rawDataGUI(memMapData, ephysData)