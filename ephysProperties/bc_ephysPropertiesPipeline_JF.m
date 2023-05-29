function ephysProperties = bc_ephysPropertiesPipeline_JF(animal, day, site, recording, experiment_num, protocol, rerun, runEP, region)

%% load ephys data 
experiments = AP_find_experimentsJF(animal, protocol, true);
experiments = experiments([experiments.ephys]);
experiment = experiments(experiment_num).experiment;

paramEP = bc_ephysPropValues;

%% compute ephys properties 
ephysDirPath = AP_cortexlab_filenameJF(animal, day, experiment, 'ephys_dir',site, recording);
savePath = fullfile(ephysDirPath, 'ephysProperties');
ephysPropertiesExist = dir(fullfile(savePath, 'templates._bc_ephysProperties.parquet'));

if (runEP && isempty(ephysPropertiesExist)) || rerun

    ephysPath = AP_cortexlab_filenameJF(animal,day,experiment,'ephys',site, recording);
    [spikeTimes_samples, spikeTemplates, templateWaveforms,~, ~, ~, ~] = bc_loadEphysData(ephysPath);
    ephysProperties = bc_computeAllEphysProperties(spikeTimes_samples, spikeTemplates, templateWaveforms, paramEP, savePath);

elseif ~isempty(ephysPropertiesExist)
    [paramEP, ephysProperties, ~] = bc_loadSavedProperties(savePath); 
end

if ~isempty(region)
    % classify cells 
end

end