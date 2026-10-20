% First we switch to the campaign data and make a folder to save each
% recording's results in, so a crash halfway through doesn't mean starting over.

setenv('PAPERA_MODE', 'campaign');
cfg = expConfig();

cacheDir = fullfile(cfg.outDir, 'cache');
if ~exist(cacheDir, 'dir'), mkdir(cacheDir); end

% Then we start a for loop that measures every recording, skips the ones that
% are already saved, and prints how long each one took.

for k = 1:numel(cfg.files)
    f = fullfile(cacheDir, [cfg.names{k} '.mat']);
    if exist(f, 'file'), continue; end

    t0 = tic;
    [row, blk] = minuteMetrics(cfg, k);
    save(f, 'row', 'blk');
    fprintf('%3d/%d  %-14s %6.1f s\n', k, numel(cfg.files), cfg.labels{k}, toc(t0));

end

% Lastly, we stack every recording into one table and every one-second block
% into another, and save both.

R = table();  B = table();

for k = 1:numel(cfg.files)
    S = load(fullfile(cacheDir, [cfg.names{k} '.mat']));
    R = [R; S.row];  B = [B; S.blk];
end

writetable(R, fullfile(cfg.outDir, 'minutes.csv'));
writetable(B, fullfile(cfg.outDir, 'blocks.csv'));
fprintf('minutes.csv: %d rows, blocks.csv: %d rows\n', height(R), height(B));
