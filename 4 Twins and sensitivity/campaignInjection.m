% First we switch to the campaign data and load the flagged recordings.

setenv('PAPERA_MODE', 'campaign');
cfg = expConfig();
R = readCampaign(fullfile(cfg.outDir, 'minutes_flagged.csv'));

% Then we build the receiver's filter from how alike neighboring bytes are on
% the headline controls, the same way the pilot did.

ctl = R.role ~= "1090" & R.headline;
target = mean([R.acf1(ctl), R.acf2(ctl), R.acf3(ctl)], 1);
[~, ~, h] = colorTwin(median(R.sigDCr1(ctl)), 10, 1, target);

N = cfg.nSamples;  mu = 127.397;  icaoBase = hex2dec('AB0000');

% Next we lay out the pilot's exact test messages: 23 SNR levels with 900
% messages each, in random order, 3,400 samples apart.

snrDb = 0:22;  nL = numel(snrDb);  nPer = 900;  spacing = 3400;
rng(12345, 'twister');

lev = repmat(1:nL, 1, nPer);  lev = lev(randperm(numel(lev)))';
F = numel(lev);
starts = 5000 + (0:F-1)' * spacing;

frac = rand(F, 1);  phi = 2 * pi * rand(F, 1);
bits = false(F, 112);  hexes = strings(F, 1);

% Then we start a for loop that builds each message, with its level written
% into its test aircraft address, so every decode can be traced back to one
% message.

for f = 1:F
    [bits(f, :), hexes(f)] = modesFrame(icaoBase + lev(f), sprintf('%02d%06d', lev(f), f));
end

% Next we start a for loop that checks that no test address shows up anywhere
% in the campaign's own decodes.

D = dir(fullfile(cfg.decDir, '*.csv'));
clash = 0;

for j = 1:numel(D)
    txt = fileread(fullfile(D(j).folder, D(j).name));
    clash = clash + numel(regexp(txt, '8[CD]AB00', 'match'));
end

fprintf('Gate: test ICAO found in the 140 campaign decodes: %d (%s)\n', clash, passFail(clash == 0));

% Here we build all the messages once, for a background of 1, since the signal
% added to a recording is just its sigma times this. Every recording gets the
% same timing and phase.

a = sqrt(2 * 10 .^ (snrDb(lev)' / 10));
[sI, sQ] = injectFrames(zeros(N, 1), zeros(N, 1), starts, bits, a, phi, frac, h);

% Then we start a for loop over the headline sessions. Each takes its 1098
% control (or 1082 if 1098 is out), adds the messages at that recording's
% background, rounds back to bytes, and sees what dump1090 decodes at each
% level.

P = table();  S = table();

for s = unique(R.session(R.headline))'
    c = R(R.session == s & R.headline & R.role ~= "1090", :);
    if isempty(c), continue; end

    pick = find(c.role == "ctl_hi", 1);
    if isempty(pick), pick = 1; end
    c = c(pick, :);
    k = find(strcmp(cfg.names, c.name));

    [rI, rQ] = readUC8(cfg.files{k}, 1, N);
    sig = c.sigDCr1;
    bI = uint8(min(max(round(double(rI) + sig * sI), 0), 255));
    bQ = uint8(min(max(round(double(rQ) + sig * sQ), 0), 255));
    clear rI rQ

    writeUC8(cfg.work, bI, bQ);
    p = levelRates(runDump1090(cfg.work, 'raw', '--fix'), hexes, lev, nL, nPer);

    P = [P; table(repmat(s, nL, 1), repmat(c.name, nL, 1), repmat(sig, nL, 1), snrDb', p, ...
                  'VariableNames', {'session', 'name', 'sigma', 'snrDb', 'pDecode'})];
    S = [S; table(s, c.name, c.role, sig, crossing(snrDb', p, 0.5), crossing(snrDb', p, 0.9), p(end), ...
                  'VariableNames', {'session', 'name', 'role', 'sigma', 'snr50', 'snr90', 'pTop'})];

    fprintf('session %2d  %s  sigma %.3f  SNR50 %.2f  SNR90 %.2f  P(22 dB) %.3f\n', s, c.role, sig, ...
            S.snr50(end), S.snr90(end), p(end));

end

% Next we read the pilot's curve from made-up noise and find how far each
% recording sits from it at its own sigma. (The pilot also measured that a real
% recording, rounded twice, sits about 0.26 dB above it.)

Ps = readtable(fullfile(cfg.root, 'results', 'pilot', 'injection_summary.csv'), 'TextType', 'string');
Ps = Ps(Ps.source == "synthetic", :);

S.pilot50 = interp1(log(Ps.sigma), Ps.snr50, log(S.sigma), 'pchip');
S.pilot90 = interp1(log(Ps.sigma), Ps.snr90, log(S.sigma), 'pchip');
S.resid50 = S.snr50 - S.pilot50;  S.resid90 = S.snr90 - S.pilot90;

writetable(P, fullfile(cfg.outDir, 'injection_campaign.csv'));
writetable(S, fullfile(cfg.outDir, 'injection_campaign_summary.csv'));

% Lastly, we summarize how far the recordings sat from the pilot's curve, and
% how SNR50 moves with the background across sessions.

fprintf('C3b n = %d sessions, sigma %.3f to %.3f LSB\n', height(S), min(S.sigma), max(S.sigma));
fprintf('    SNR50 residual vs pilot synthetic: median %+.2f dB, range %+.2f to %+.2f\n', median(S.resid50), min(S.resid50), max(S.resid50));
fprintf('    SNR90 residual vs pilot synthetic: median %+.2f dB, range %+.2f to %+.2f\n', median(S.resid90), min(S.resid90), max(S.resid90));
fprintf('    Spearman rho(sigma, SNR50) = %+.3f; lowest P(decode) at 22 dB = %.3f\n', spearmanRho(S.sigma, S.snr50), min(S.pTop));

function p = levelRates(msg, hexes, lev, nL, nPer)

% Here we match the decodes to the messages we sent and find the share decoded
% at each level.

[tf, loc] = ismember(msg.hex, hexes);
got = unique(loc(tf));
p = accumarray(lev(got), 1, [nL 1]) / nPer;

end

function x = crossing(snr, p, level)

% Here we find where the decode curve first reaches the level, reading between
% the SNR steps.

k = find(p >= level, 1);
if isempty(k), x = NaN; elseif k == 1, x = snr(1);
else, x = snr(k-1) + (level - p(k-1)) / (p(k) - p(k-1)) * (snr(k) - snr(k-1));
end

end

function s = passFail(ok)

% Here we turn true or false into PASS or FAIL.

if ok, s = 'PASS'; else, s = 'FAIL'; end

end
