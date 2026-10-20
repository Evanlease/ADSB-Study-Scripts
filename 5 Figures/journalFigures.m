% First we switch to the campaign data, make the folder the journal figures go
% in, and load every table the figures need. These figures show the same
% numbers as campaignFigures, combined into panels sized for a printed page.

setenv('PAPERA_MODE', 'campaign');
cfg = expConfig();

figDir = fullfile(cfg.root, 'paper', 'journal', 'figures');
if ~exist(figDir, 'dir'), mkdir(figDir); end

rd = @(f) readCampaign(fullfile(cfg.outDir, f));
R = rd('minutes_flagged.csv');  S = rd('sessions.csv');  D = rd('floor_by_session.csv');
B = rd('blocks.csv');  P = rd('preambles.csv');  J = rd('injection_campaign_summary.csv');
Tw = readtable(fullfile(cfg.outDir, 'twins.csv'));

% Then we set up the colors color-blind readers can tell apart (Okabe-Ito),
% the printed width and font size every figure uses (the paper's text column
% is 4.8 inches), and the headline sessions.

ink  = [0.15 0.15 0.15];  blue = [0 0.447 0.698];  orng = [0.902 0.624 0];
verm = [0.835 0.369 0];   grn  = [0 0.620 0.451];  purp = [0.8 0.475 0.655];
grey = [0.6 0.6 0.6];     fs = 7;  W = 4.8;
H = S(S.inSet, :);

% Figure 1, panel (a): each session's control floor over the week, marking
% session 2 (the phone) and the day 6 sessions with overloaded recordings.

fig = newFig(W, 4.0);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl);  hold(ax, 'on');  box(ax, 'on');

ok = D.session ~= 2 & D.nOverMin == 0;
hN = plot(ax, D.session(ok), D.F(ok), 'o', 'MarkerSize', 4.5, 'MarkerFaceColor', blue, 'MarkerEdgeColor', blue);
hP = plot(ax, D.session(D.session == 2), D.F(D.session == 2), 's', 'MarkerSize', 5, ...
          'MarkerFaceColor', purp, 'MarkerEdgeColor', purp);
hO = plot(ax, D.session(D.nOverMin > 0), D.F(D.nOverMin > 0), '^', 'MarkerSize', 5, ...
          'MarkerFaceColor', verm, 'MarkerEdgeColor', verm);

% Then we start a for loop that draws a light line between days and labels
% each day.

for d = 1:7
    xline(ax, (d - 1) * 4 + 0.5, '-', 'Color', [0.85 0.85 0.85], 'HandleVisibility', 'off');
    text(ax, (d - 1) * 4 + 2.5, 17.2, sprintf('day %d', d), 'HorizontalAlignment', 'center', 'FontSize', fs);
end

% Lastly for panel (a), we add the axes and the legend.

set(ax, 'XLim', [0.5 28.5], 'YLim', [-0.8 18.4], 'XTick', 1:28, 'FontSize', fs);
ylabel(ax, 'control floor F (dB)');
legend(ax, [hN hP hO], {'ordinary session', 'session 2 (phone at about 1 foot)', ...
       'day 6 (overloaded recordings)'}, 'Location', 'northoutside', 'NumColumns', 3, 'Box', 'off', 'FontSize', fs);
panelLabel(ax, '(a)', fs);

% Figure 1, panel (b): we join each headline session's gap on 1090 MHz to the
% same gap on its controls with a grey line, then plot both as dots.

ax = nexttile(tl);  hold(ax, 'on');  box(ax, 'on');

for k = 1:height(H)
    plot(ax, [H.session(k) H.session(k)], [H.Z(k) H.G(k)], '-', 'Color', grey, 'LineWidth', 1, 'HandleVisibility', 'off');
end

hG = plot(ax, H.session, H.G, 'o', 'MarkerSize', 4.5, 'MarkerFaceColor', verm, 'MarkerEdgeColor', verm);
hZ = plot(ax, H.session, H.Z, 'o', 'MarkerSize', 4.5, 'MarkerEdgeColor', blue, 'LineWidth', 1);
yline(ax, 0, ':', 'Color', ink, 'HandleVisibility', 'off');

% Lastly for figure 1, we add the axes and legend and save it.

set(ax, 'XLim', [0.5 28.5], 'XTick', 1:28, 'FontSize', fs);
xlabel(ax, 'session (four a day, October 12 to 18, 2026)');
ylabel(ax, 'gap (dB)');
legend(ax, [hG hZ], {'G: 1090 MHz (median of traffic recordings)', ...
       'Z: controls (mean of control recordings)'}, 'Location', 'northoutside', 'NumColumns', 2, 'Box', 'off', 'FontSize', fs);
panelLabel(ax, '(b)', fs);
exportgraphics(fig, fullfile(figDir, 'fig1_floor_gap.png'), 'Resolution', 300);  close(fig);

% Figure 2, panel (a): the declared test, each session's gap against its
% message rate. Open dots are sessions that rule R3 flagged.

fig = newFig(W, 2.55);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl);  hold(ax, 'on');  box(ax, 'on');

flag = H.r3Flag;
plot(ax, H.rate(~flag), H.G(~flag), 'o', 'MarkerSize', 5, 'MarkerFaceColor', verm, 'MarkerEdgeColor', verm);
plot(ax, H.rate(flag), H.G(flag), 'o', 'MarkerSize', 5, 'MarkerEdgeColor', verm, 'LineWidth', 1);

% Then we start a for loop that writes each session's number beside its dot.
% A few dots are crowded on the right, so their numbers go on the left, and
% session 20's goes above its dot.

leftSide = [3 4 7 8 17 25];

for k = 1:height(H)
    lab = sprintf('%d', H.session(k));

    if H.session(k) == 20
        text(ax, H.rate(k), H.G(k) + 0.09, lab, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
             'FontSize', fs - 2, 'Color', grey);
    elseif ismember(H.session(k), leftSide)
        text(ax, H.rate(k) - 5.5, H.G(k), lab, 'HorizontalAlignment', 'right', 'FontSize', fs - 2, 'Color', grey);
    else
        text(ax, H.rate(k) + 5.5, H.G(k), lab, 'FontSize', fs - 2, 'Color', grey);
    end
end

% Here we add the labels.

xlabel(ax, 'Mode S messages decoded per second');
ylabel(ax, 'gap G (dB)');
legend(ax, {'session', 'session flagged by R3'}, 'Location', 'northwest', 'Box', 'off', 'FontSize', fs);
set(ax, 'FontSize', fs, 'XLim', [100 292]);
panelLabel(ax, '(a)', fs);

% Figure 2, panel (b): we start a for loop that shows how far the three
% center-reading estimators moved when the decoded messages were taken out,
% one dot per session, spread sideways a little, with a bar at the median.

ax = nexttile(tl);  hold(ax, 'on');  box(ax, 'on');
names = {'cell fraction', 'central fit', 'quietest window'};
cols = {blue, grn, purp};
vals = {H.bDC, H.bCF, H.bQW};

for q = 1:3
    rng(q + 1, 'twister');
    xs = q + 0.18 * (rand(size(vals{q})) - 0.5);
    plot(ax, xs, vals{q}, 'o', 'MarkerSize', 3.5, 'MarkerFaceColor', cols{q}, 'MarkerEdgeColor', cols{q});
    plot(ax, q + [-0.25 0.25], median(vals{q}) * [1 1], '-', 'Color', ink, 'LineWidth', 1.3);
end

% Lastly for figure 2, we mark zero and the plan's 0.1 dB bar, note where mean
% power sits (off this scale), and save it.

yline(ax, 0, ':', 'Color', ink);
yline(ax, 0.1, '--', '0.1 dB', 'Color', grey, 'LabelHorizontalAlignment', 'right', 'FontSize', fs);
set(ax, 'XTick', 1:3, 'XTickLabel', names, 'XLim', [0.5 3.5], 'FontSize', fs);
ylabel(ax, 'change when messages are cut out (dB)');
text(ax, 3.45, 0.165, sprintf('mean power: median %+.2f dB,\noff this scale', median(H.bMP)), ...
     'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', fs, 'Color', verm);
panelLabel(ax, '(b)', fs);
exportgraphics(fig, fullfile(figDir, 'fig2_rate_estimators.png'), 'Resolution', 300);  close(fig);

% Figure 3, panel (a): the preamble count against the background, real
% recordings beside the twins.

fig = newFig(W, 2.55);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl);  hold(ax, 'on');  box(ax, 'on');

hT = plot(ax, Tw.sigma, Tw.twinPreambles / 1e6, '-', 'Color', blue, 'LineWidth', 1.3);
c = P.role ~= "1090";
hC = plot(ax, P.sigDCr1(c), P.preambles(c) / 1e6, 'o', 'MarkerSize', 3.5, 'MarkerFaceColor', orng, 'MarkerEdgeColor', orng);
hX = plot(ax, P.sigDCr1(~c), P.preambles(~c) / 1e6, 'x', 'MarkerSize', 4, 'Color', verm, 'LineWidth', 0.9);

xlabel(ax, 'background \sigma (LSB)');
ylabel(ax, 'preamble candidates per 60 s (millions)');
legend(ax, [hT hC hX], {'twin (noise only)', 'control recordings', '1090 MHz recordings'}, ...
       'Location', 'southeast', 'Box', 'off', 'FontSize', fs);
set(ax, 'FontSize', fs);
panelLabel(ax, '(a)', fs);

% Figure 3, panel (b): the SNR each control needed for half its test messages
% to decode, against its background.

ax = nexttile(tl);  hold(ax, 'on');  box(ax, 'on');
plot(ax, J.sigma, J.snr50, 'o', 'MarkerSize', 4, 'MarkerFaceColor', orng, 'MarkerEdgeColor', orng);

% Lastly for figure 3, we set the log axis and the labels, and save it.

set(ax, 'XScale', 'log', 'XLim', [0.65 3.2], 'XTick', [0.7 1 1.5 2 3], 'FontSize', fs);
xlabel(ax, 'background \sigma (LSB, log scale)');
ylabel(ax, 'SNR50 (dB)');
panelLabel(ax, '(b)', fs);
exportgraphics(fig, fullfile(figDir, 'fig3_preambles_snr.png'), 'Resolution', 300);  close(fig);

% Figure 4, panel (a): the background second by second through session 23,
% where a strong source came on and went off.

fig = newFig(W, 2.45);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl);  hold(ax, 'on');  box(ax, 'on');
m23 = R(R.session == 23, :);

% Then we start a for loop that draws each of the session's five recordings
% in its own place on a 300 s time line, blue for 1090 and orange for
% controls.

for j = 1:height(m23)
    b = B(B.name == m23.name(j), :);
    t = (m23.rec(j) - 1) * 60 + b.block - 0.5;
    if m23.role(j) == "1090", c = blue; else, c = orng; end

    plot(ax, t, b.sigDC, '-', 'Color', c, 'LineWidth', 1.1);
    text(ax, (m23.rec(j) - 1) * 60 + 30, 5.0, m23.role(j), 'HorizontalAlignment', 'center', 'FontSize', fs - 1, ...
         'Interpreter', 'none');
end

% Here we mark the R5 limit and label panel (a).

yline(ax, 0.9857 * 10^(10/20), '--', 'R5 limit', 'Color', grey, 'LabelHorizontalAlignment', 'left', 'FontSize', fs);
xlabel(ax, 'seconds into session 23 (October 17, 16:54 EDT)');  ylabel(ax, 'background \sigma per second (LSB)');
set(ax, 'XLim', [0 300], 'YLim', [0 5.3], 'FontSize', fs);
panelLabel(ax, '(a)', fs);

% Figure 4, panel (b): the decodes in every day 6 traffic recording, beside
% the median of clean recordings within an hour of the same clock time on the
% other days.

ax = nexttile(tl);  hold(ax, 'on');  box(ax, 'on');
d6 = R(R.day == 6 & R.role == "1090", :);
clean = R(R.headline & R.role == "1090" & R.day ~= 6, :);
ref = arrayfun(@(j) median(clean.accepted(abs(clean.localMin - d6.localMin(j)) <= 60)), (1:height(d6))');

xs = (d6.session - 21) * 4 + d6.rec / 2;
bar(ax, xs, ref / 60, 0.35, 'FaceColor', [0.85 0.85 0.85], 'EdgeColor', 'none');
bar(ax, xs, d6.accepted / 60, 0.2, 'FaceColor', verm, 'EdgeColor', 'none');

% Lastly for figure 4, we add the labels and save it.

set(ax, 'XTick', (0:3) * 4 + 1.5, 'XTickLabel', {'session 21', 'session 22', 'session 23', 'session 24'}, ...
    'YLim', [0 290], 'FontSize', fs);
ylabel(ax, 'Mode S decodes per second');
legend(ax, {'other days, same time (median)', 'day 6 recording'}, 'Location', 'northwest', 'Box', 'off', 'FontSize', fs);
panelLabel(ax, '(b)', fs);
exportgraphics(fig, fullfile(figDir, 'fig4_overload.png'), 'Resolution', 300);  close(fig);

fprintf('journal figures written to %s\n', figDir);

function fig = newFig(w, h)

% Here we make a hidden figure of the printed size in inches that always uses
% the light theme.

fig = figure('Visible', 'off', 'Units', 'inches', 'Position', [0 0 w h]);

try
    theme(fig, 'light');
catch
    set(fig, 'Color', 'w');
end

end

function panelLabel(ax, s, fs)

% Here we put the panel letter in a title above the axes, lined up with its
% left edge, so it never sits on top of a label.

title(ax, s, 'FontSize', fs + 1, 'FontWeight', 'bold');
ax.TitleHorizontalAlignment = 'left';

end
