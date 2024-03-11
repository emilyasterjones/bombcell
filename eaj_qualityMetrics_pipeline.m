%% ~~ EAJ bombcell pipeline ~~
% Adjust the paths in the 'set paths' section and the parameters in bc_qualityParamValues
% This pipeline will run bombcell on your data and save the output

addpath(genpath("C:\Users\Niflheim\Documents\GitHub\External\bombcell"))
addpath(genpath("C:\Users\Niflheim\Documents\GitHub\External\npy-matlab"))
addpath(genpath("C:\Users\Niflheim\Documents\GitHub\External\prettify_matlab"))

%% set paths
clearvars
probe = 0;
sessions = readtable('Z:\WT_Sequences\2024_winter\Preprocessed_Data\Provenance\all_sessions.csv');
for s = 1:height(sessions)
    epoch = string(sessions{s,'Epoch'});
    rec_error = string(sessions{s,'Recording_Error'});
    if strcmp(epoch, 'g0') && strcmp(rec_error, 'FALSE')
        % generate the path to the directory containing the ap.bin file
        base_dir = string(sessions{s,'Base_Directory'});
        base_dir = strrep(base_dir, '/', '\');
        ecephys_path = strcat(base_dir, '\Preprocessed_Data\Spikes');

        rec_file_stem = split(string(sessions{s,'File'}),'/');
        rec_file_stem = convertStringsToChars(rec_file_stem(2));
        rec_file_path = sprintf('%s\\%s\\Ecephys\\%s\\catgt_%s\\%s_imec%d',...
            ecephys_path, string(sessions{s,'Animal'}),...
            rec_file_stem(1:end-3), rec_file_stem,...
            rec_file_stem, probe);

        % set variables for BombCell
        mainDir = rec_file_path;
        ephysKilosortPath = sprintf('%s/imec%d_ks',rec_file_path,probe);
        rec_file_base = sprintf('%s/%s_tcat.imec%d.ap',rec_file_path,rec_file_stem, probe);
        rawFile = [rec_file_base,'.bin'];
        ephysMetaFile = [rec_file_base,'.meta'];

        saveLocation = mainDir;
        savePath = fullfile(saveLocation, 'qMetrics');

        % load data
        [spikeTimes_samples, spikeTemplates, templateWaveforms, templateAmplitudes, pcFeatures, ...
            pcFeatureIdx, channelPositions] = bc_loadEphysData(ephysKilosortPath);

        % which quality metric parameters to extract and thresholds
        param = eaj_qualityParamValues(ephysMetaFile, rawFile, ephysKilosortPath);
        % param = bc_qualityParamValuesForUnitMatch(ephysMetaDir, rawFile) % Run this if you want to use UnitMatch after

        %% compute quality metrics
        [qMetric, unitType] = bc_runAllQualityMetrics(param, spikeTimes_samples, spikeTemplates, ...
            templateWaveforms, templateAmplitudes,pcFeatures,pcFeatureIdx,channelPositions, savePath);

        %% save to cluster_group.tsv
        % overwrite ecephys cluster labels if any units were found to be noise
        cluster_group_file = [ephysKilosortPath filesep 'cluster_group.tsv'];
        cluster_group = readtable(cluster_group_file, 'FileType', 'text', 'Delimiter', '\t');
        cluster_group(unitType==0,'group') = {'noise'};
        writetable(cluster_group, cluster_group_file, 'FileType', 'text', 'Delimiter', '\t');

    end
    %end
end


