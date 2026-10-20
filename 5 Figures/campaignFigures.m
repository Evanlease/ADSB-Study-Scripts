% First we switch to the campaign data, make the folder the figures go in, and
% load every table the figures need.

setenv('PAPERA_MODE', 'campaign');
cfg = expConfig();

figDir = fullfile(cfg.outDir, 'fig');
if ~exist(figDir, 'dir'), mkdir(figDir); end

rd = @(f) readCampaign(fullfile(cfg.outDir, f));
R = rd('minutes_flagged.csv');  S = rd('sessions.csv');  D = rd('floor_by_session.csv');
B = rd('blocks.csv');

% Then we set up colors that color-blind readers can tell apart (the Okabe-Ito
% colors), and keep the headline sessions.

ink  = [0.15 0.15 0.15];  blue = [0 0.447 0.698];  orng = [0.902 0.624 0];
verm = [0.835 0.369 0];   grn  = [0 0.620 0.451];  sky  = [0.337 0.706 0.914];
purp = [0.8 0.475 0.655]; grey = [0.6 0.6 0.6];
H = S(S.inSet, :);

% For figure 1, we draw one session as a row of labeled boxes, the way the
% plate layout was drawn in my AMR paper: the warm-up, then the five 60 s
% recordings in order.

fig = newFig(900, 260);
ax = axes(fig, 'Position', [0.02 0.12 0.96 0.78]);  hold(ax, 'on');  axis(ax, 'off');

x0 = [0 5 6 7 8 9];  w = [5 1 1 1 1 1];
lab = {'warm-up at 1090 MHz\newline300 s, not kept', '1090 MHz\newline60 s', ...
       'control\newline1082 or 1098', '1090 MHz\newline60 s', 'other control\newline1098 or 1082', ...
       '1090 MHz\newline60 s'};
col = {[0.92 0.92 0.92], sky, orng, sky, orng, sky};

% Then we start two for loops: one draws each box with its label, and one
% numbers the five recordings above them.

for j = 1:6
    rectangle(ax, 'Position', [x0(j) 0 w(j) 1], 'FaceColor', col{j}, 'EdgeColor', ink, 'LineWidth', 1);
    text(ax, x0(j) + w(j) / 2, 0.5, lab{j}, 'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', ink);
end

for j = 2:6
    text(ax, x0(j) + 0.5, 1.12, sprintf('r%d', j - 1), 'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end

% Lastly for figure 1, we add the note underneath and save it.

text(ax, 7, -0.22, 'The two controls swap places from one session to the next, so neither always comes first.', ...
     'HorizontalAlignment', 'center', 'FontSize', 9.5, 'Color', ink);
xlim(ax, [-0.1 10.1]);  ylim(ax, [-0.35 1.25]);
exportgraphics(fig, fullfile(figDir, 'fig01_session.png'), 'Resolution', 200);  close(fig);

% For figure 2, we plot each session's control floor over the week, marking
% session 2 (the phone) and the day 6 sessions with overloaded recordings.

fig = newFig(980, 420);
ax = axes(fig);  hold(ax, 'on');  box(ax, 'on');

ok = D.session ~= 2 & D.nOverMin == 0;
hN = plot(ax, D.session(ok), D.F(ok), 'o', 'MarkerSize', 7, 'MarkerFaceColor', blue, 'MarkerEdgeColor', blue);
hP = plot(ax, D.session(D.session == 2), D.F(D.session == 2), 's', 'MarkerSize', 8, ...
          'MarkerFaceColor', purp, 'MarkerEdgeColor', purp);
hO = plot(ax, D.session(D.nOverMin > 0), D.F(D.nOverMin > 0), '^', 'MarkerSize', 8, ...
          'MarkerFaceColor', verm, 'MarkerEdgeColor', verm);

% Then we start a for loop that draws a light line between days and labels
% each day.

for d = 1:7
    xline(ax, (d - 1) * 4 + 0.5, '-', 'Color', [0.85 0.85 0.85], 'HandleVisibility', 'off');
    text(ax, (d - 1) * 4 + 2.5, 17.3, sprintf('day %d', d), 'HorizontalAlignment', 'center', 'FontSize', 9);
end

% Lastly for figure 2, we add the axes, legend and title, and save it.

set(ax, 'XLim', [0.5 28.5], 'YLim', [-0.8 18.2], 'XTick', 1:28, 'FontSize', 9);
xlabel(ax, 'session (four a day, Oct 12 to 18, 2026)');
ylabel(ax, 'control floor above the quietest session (dB)');

lg = legend(ax, [hN hP hO], {'ordinary session', 'session 2 (phone about 1 foot away)', ...
       'session with overloaded minutes (day 6)'}, 'Box', 'off');
lg.Position = [0.33 0.56 0.3 0.14];

title(ax, sprintf('The background moved up to %.1f dB between ordinary sessions, and %.0f dB on day 6', ...
      max(D.F(ok)), max(D.F)), 'FontWeight', 'normal');
exportgraphics(fig, fullfile(figDir, 'fig02_floor.png'), 'Resolution', 200);  close(fig);

% For figure 3, we start a for loop that joins each headline session's gap on
% 1090 MHz to the same gap on its controls with a grey line.

fig = newFig(980, 420);
ax = axes(fig);  hold(ax, 'on');  box(ax, 'on');

for k = 1:height(H)
    plot(ax, [H.session(k) H.session(k)], [H.Z(k) H.G(k)], '-', 'Color', grey, 'LineWidth', 1.2, 'HandleVisibility', 'off');
end

% Then we plot the two gaps as dots, add the labels, and save it.

hG = plot(ax, H.session, H.G, 'o', 'MarkerSize', 7, 'MarkerFaceColor', verm, 'MarkerEdgeColor', verm);
hZ = plot(ax, H.session, H.Z, 'o', 'MarkerSize', 7, 'MarkerEdgeColor', blue, 'LineWidth', 1.3);
yline(ax, 0, ':', 'Color', ink, 'HandleVisibility', 'off');

set(ax, 'XLim', [0.5 28.5], 'XTick', 1:28, 'FontSize', 9);
xlabel(ax, 'session');  ylabel(ax, 'reported noise minus background (dB)');
legend(ax, [hG hZ], {'1090 MHz (median of the session''s traffic minutes)', 'controls (mean of the session''s controls)'}, ...
       'Location', 'northwest', 'Box', 'off');

title(ax, sprintf('The reported noise sat %.1f to %.1f dB above the background on 1090 MHz', min(H.G), max(H.G)), ...
      'FontWeight', 'normal');
exportgraphics(fig, fullfile(figDir, 'fig03_gap.png'), 'Resolution', 200);  close(fig);

% For figure 4, the declared test, we plot each session's gap against its
% message rate. Open dots are sessions that rule R3 flagged.

rho = spearmanRho(H.G, H.rate);
fig = newFig(640, 460);
ax = axes(fig);  hold(ax, 'on');  box(ax, 'on');

flag = H.r3Flag;
plot(ax, H.rate(~flag), H.G(~flag), 'o', 'MarkerSize', 8, 'MarkerFaceColor', verm, 'MarkerEdgeColor', verm);
plot(ax, H.rate(flag), H.G(flag), 'o', 'MarkerSize', 8, 'MarkerEdgeColor', verm, 'LineWidth', 1.3);

% Then we start a for loop that writes each session's number beside its dot.

for k = 1:height(H)
    text(ax, H.rate(k) + 2, H.G(k), sprintf('%d', H.session(k)), 'FontSize', 7.5, 'Color', grey);
end

% Lastly for figure 4, we add the labels and save it.

xlabel(ax, 'Mode S messages decoded per second');
ylabel(ax, 'reported noise minus background (dB)');
legend(ax, {'session', 'session flagged by R3 (moving control floor)'}, 'Location', 'northwest', 'Box', 'off');

title(ax, sprintf('The gap grew with traffic (Spearman \\rho = %.2f, n = %d)', rho, height(H)), 'FontWeight', 'normal');
set(ax, 'FontSize', 10, 'XLim', [100 292]);
exportgraphics(fig, fullfile(figDir, 'fig04_rate.png'), 'Resolution', 200);  close(fig);

% For figure 5, we show how far each estimator moved when the decoded messages
% were taken out: all four on the left, and the three small ones up close on
% the right.

names = {'meanPower', 'cellDC', 'centralFit', 'quietest window'};
cols = {verm, blue, grn, purp};
vals = {H.bMP, H.bDC, H.bCF, H.bQW};

fig = newFig(980, 420);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% Then we start a for loop over the two panels. Inside it, another for loop
% spreads each estimator's sessions sideways a little so the dots don't hide
% each other, and draws a bar at the middle value.

for panel = 1:2
    ax = nexttile(tl);  hold(ax, 'on');  box(ax, 'on');
    if panel == 1, js = 1:4; else, js = 2:4; end

    for q = 1:numel(js)
        j = js(q);
        rng(j, 'twister');
        xs = q + 0.18 * (rand(size(vals{j})) - 0.5);
        plot(ax, xs, vals{j}, 'o', 'MarkerSize', 5, 'MarkerFaceColor', cols{j}, 'MarkerEdgeColor', cols{j});
        plot(ax, q + [-0.25 0.25], median(vals{j}) * [1 1], '-', 'Color', ink, 'LineWidth', 1.5);
    end

    set(ax, 'XTick', 1:numel(js), 'XTickLabel', names(js), 'XLim', [0.5 numel(js) + 0.5], 'FontSize', 10);
    yline(ax, 0, ':', 'Color', ink);

    % Here we start an if statement that adds the 0.1 dB line and title to the
    % right panel, and the axis label and title to the left one.

    if panel == 2
        yline(ax, 0.1, '--', '0.1 dB', 'Color', grey, 'LabelHorizontalAlignment', 'left');
        title(ax, 'The three that read the background', 'FontWeight', 'normal');
    else
        ylabel(ax, 'change when decoded messages are removed (dB)');
        title(ax, 'All four estimators', 'FontWeight', 'normal');
    end

end

exportgraphics(fig, fullfile(figDir, 'fig05_estimators.png'), 'Resolution', 200);  close(fig);

% For figure 6, we start an if statement that, once the twins exist, plots the
% preamble count against the background, real recordings beside the twins.

if exist(fullfile(cfg.outDir, 'twins.csv'), 'file')
    Tw = readtable(fullfile(cfg.outDir, 'twins.csv'));
    P = rd('preambles.csv');

    fig = newFig(760, 460);
    ax = axes(fig);  hold(ax, 'on');  box(ax, 'on');

    hT = plot(ax, Tw.sigma, Tw.twinPreambles / 1e6, '-', 'Color', blue, 'LineWidth', 1.6);
    c = P.role ~= "1090";
    hC = plot(ax, P.sigDCr1(c), P.preambles(c) / 1e6, 'o', 'MarkerSize', 6, 'MarkerFaceColor', orng, 'MarkerEdgeColor', orng);
    hX = plot(ax, P.sigDCr1(~c), P.preambles(~c) / 1e6, 'x', 'MarkerSize', 7, 'Color', verm, 'LineWidth', 1.2);

    xlabel(ax, 'background \sigma (LSB, cell fraction)');
    ylabel(ax, 'preamble candidates per 60 s (millions)');
    legend(ax, [hT hC hX], {'twin: colored Gaussian noise, no aircraft', 'control minutes', '1090 MHz minutes'}, ...
           'Location', 'southeast', 'Box', 'off');

    % Here we put the controls' result in the title, using only the controls
    % inside the twins' range.

    inGrid = c & P.sigDCr1 <= max(Tw.sigma);
    r = 100 * (P.ratio(inGrid) - 1);
    title(ax, sprintf('Control minutes followed the twin curve (median %+.1f %%, all %d within %.1f %%)', ...
          median(r), numel(r), max(abs(r))), 'FontWeight', 'normal');

    set(ax, 'FontSize', 10);
    exportgraphics(fig, fullfile(figDir, 'fig06_preambles.png'), 'Resolution', 200);  close(fig);

end

% For figure 7, we start an if statement that, once the test-message run is
% done, plots the SNR each control needed for half its messages to decode
% against its background, beside the decode curve from made-up noise.

if exist(fullfile(cfg.outDir, 'injection_campaign_summary.csv'), 'file')
    J = readCampaign(fullfile(cfg.outDir, 'injection_campaign_summary.csv'));
    Ps = readtable(fullfile(cfg.root, 'results', 'pilot', 'injection_summary.csv'), 'TextType', 'string');
    syn = Ps(Ps.source == "synthetic", :);
    an = Ps(Ps.source == "real 006", :);

    fig = newFig(760, 460);
    ax = axes(fig);  hold(ax, 'on');  box(ax, 'on');

    hS = plot(ax, syn.sigma, syn.snr50, '-s', 'Color', blue, 'MarkerFaceColor', blue, 'LineWidth', 1.4);
    hJ = plot(ax, J.sigma, J.snr50, 'o', 'MarkerSize', 7, 'MarkerFaceColor', orng, 'MarkerEdgeColor', orng);
    hA = plot(ax, an.sigma, an.snr50, 'd', 'MarkerSize', 8, 'MarkerFaceColor', purp, 'MarkerEdgeColor', purp);

    set(ax, 'XScale', 'log', 'XLim', [0.45 6.5], 'XTick', [0.5 0.7 1 1.5 2 3 4 6], 'FontSize', 10);
    xlabel(ax, 'background \sigma (LSB, log scale)');
    ylabel(ax, 'SNR needed for 50 % of test messages to decode (dB)');
    legend(ax, [hS hJ hA], {'pilot: synthetic backgrounds', 'campaign: one real control minute per session', ...
           'pilot: real control 006'}, 'Location', 'northeast', 'Box', 'off');

    title(ax, 'Real control minutes needed more SNR when the background was small', 'FontWeight', 'normal');
    exportgraphics(fig, fullfile(figDir, 'fig07_injection.png'), 'Resolution', 200);  close(fig);

end

% For figure 8, the left panel follows the background second by second through
% day 6's third session (session 23), where a strong source came on and went
% off.

fig = newFig(980, 440);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl);  hold(ax, 'on');  box(ax, 'on');
m23 = R(R.session == 23, :);

% Then we start a for loop that draws each of the session's five recordings in
% its own place on a 300 s time line, blue for 1090 and orange for controls.

for j = 1:height(m23)
    b = B(B.name == m23.name(j), :);
    t = (m23.rec(j) - 1) * 60 + b.block - 0.5;
    if m23.role(j) == "1090", c = blue; else, c = orng; end

    plot(ax, t, b.sigDC, '-', 'Color', c, 'LineWidth', 1.4);
    text(ax, (m23.rec(j) - 1) * 60 + 30, 3.9, m23.role(j), 'HorizontalAlignment', 'center', 'FontSize', 8.5, ...
         'Interpreter', 'none');
end

% Here we mark the R5 limit and label the left panel.

yline(ax, 0.9857 * 10^(10/20), '--', 'R5 limit', 'Color', grey, 'LabelHorizontalAlignment', 'left');
xlabel(ax, 'seconds into session 23 (Oct 17, 16:54 EDT)');  ylabel(ax, 'background \sigma per second (LSB)');
set(ax, 'XLim', [0 300], 'YLim', [0 4.2], 'FontSize', 10);
title(ax, 'A strong source came on and went off', 'FontWeight', 'normal');

% Next, the right panel counts the decodes in every day 6 traffic recording,
% beside the median of clean recordings within an hour of the same clock time
% on the other days.

ax = nexttile(tl);  hold(ax, 'on');  box(ax, 'on');
d6 = R(R.day == 6 & R.role == "1090", :);
clean = R(R.headline & R.role == "1090" & R.day ~= 6, :);
ref = arrayfun(@(j) median(clean.accepted(abs(clean.localMin - d6.localMin(j)) <= 60)), (1:height(d6))');

xs = (d6.session - 21) * 4 + d6.rec / 2;
bar(ax, xs, ref / 60, 0.35, 'FaceColor', [0.85 0.85 0.85], 'EdgeColor', 'none');
bar(ax, xs, d6.accepted / 60, 0.2, 'FaceColor', verm, 'EdgeColor', 'none');

set(ax, 'XTick', (0:3) * 4 + 1.5, 'XTickLabel', {'session 21', 'session 22', 'session 23', 'session 24'}, 'FontSize', 10);
ylabel(ax, 'Mode S messages decoded per second');
legend(ax, {'same clock time, other days (median)', 'day 6 traffic minute'}, 'Location', 'northwest', 'Box', 'off');
title(ax, 'Decodes collapsed while it was on', 'FontWeight', 'normal');
exportgraphics(fig, fullfile(figDir, 'fig08_overload.png'), 'Resolution', 200);  close(fig);

% Lastly, we copy the figures into the paper's folder.

copyfile(fullfile(figDir, '*.png'), fullfile(cfg.root, 'paper', 'campaign', 'figures'));
fprintf('figures written to %s and copied to paper/campaign/figures\n', figDir);

function fig = newFig(w, h)

% Here we make a hidden figure that always uses the light theme, even when
% MATLAB is set to dark.

fig = figure('Visible', 'off', 'Position', [0 0 w h]);

try
    theme(fig, 'light');
catch
    set(fig, 'Color', 'w');
end

end
