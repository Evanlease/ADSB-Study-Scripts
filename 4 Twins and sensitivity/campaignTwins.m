% First we switch to the campaign data and load the flagged recordings.

setenv('PAPERA_MODE', 'campaign');
cfg = expConfig();
R = readCampaign(fullfile(cfg.outDir, 'minutes_flagged.csv'));

% Then we average how alike neighboring bytes are on the headline controls,
% which is what every twin has to copy.

ctl = R.role ~= "1090" & R.headline;
target = mean([R.acf1(ctl), R.acf2(ctl), R.acf3(ctl)], 1);
fprintf('target byte ACF lags 1-3 from %d control minutes: %.4f %.4f %.4f\n', sum(ctl), target);

% Next we start an if statement that reuses the twins if they're already saved,
% since they take a few minutes to make.

twinFile = fullfile(cfg.outDir, 'twins.csv');

if exist(twinFile, 'file')
    Tw = readtable(twinFile);
    grid = Tw.sigma;  pre = Tw.twinPreambles;

% Otherwise we start a for loop that builds a 60 s twin at every sigma from 0.65
% to 2.5 LSB, runs dump1090 on it, and keeps its preamble count.

else
    grid = (0.65:0.05:2.5)';
    pre = nan(size(grid));  noise = nan(size(grid));  modeac = nan(size(grid));

    for g = 1:numel(grid)
        [bI, bQ] = colorTwin(grid(g), cfg.nSamples, round(grid(g) * 1e4), target);
        writeUC8(cfg.work, bI, bQ);

        st = runDump1090(cfg.work, 'stats');
        pre(g) = st.preambles;  noise(g) = st.noiseDbfs;  modeac(g) = st.modeac;
        fprintf('sigma %.2f  preambles %d\n', grid(g), pre(g));
    end

    Tw = table(grid, pre, noise, modeac, 'VariableNames', {'sigma', 'twinPreambles', 'twinNoise', 'twinModeac'});
    writetable(Tw, twinFile);

end

% Then for every headline recording we read off the twin's count at that
% recording's sigma and compare the two.

H = R(R.headline, :);
H.twinPre = interp1(grid, pre, H.sigDCr1, 'pchip');
H.ratio = H.preambles ./ H.twinPre;

writetable(H(:, {'name', 'session', 'role', 'sigDCr1', 'preambles', 'twinPre', 'ratio'}), ...
           fullfile(cfg.outDir, 'preambles.csv'));

% Lastly, we start a for loop that summarizes real over twin, on the controls
% and on the 1090 recordings. It keeps only recordings inside the twins' range,
% since we read between the twins but never past them.

for grp = ["controls", "1090"]
    if grp == "controls", m = H.role ~= "1090"; else, m = H.role == "1090"; end
    m = m & H.sigDCr1 <= max(grid);
    r = 100 * (H.ratio(m) - 1);

    fprintf('C3a %-8s real/twin - 1: median %+.2f %%, range %+.2f to %+.2f %%, n = %d minutes, sigma %.3f to %.3f LSB\n', ...
            grp, median(r), min(r), max(r), sum(m), min(H.sigDCr1(m)), max(H.sigDCr1(m)));
end
