function cfg = expConfig()

% First we set up where everything lives: the code in analysis, the pilot
% recordings and their decoded message tables in data/pilot, and the result
% tables in results/pilot.

here = fileparts(mfilename('fullpath'));
cfg.root     = fileparts(here);
cfg.expDir   = here;

cfg.iqDir    = fullfile(cfg.root, 'data', 'pilot', 'iq');
cfg.decDir   = fullfile(cfg.root, 'data', 'pilot', 'decoded');
cfg.work     = fullfile(cfg.root, 'data', 'scratch', 'work.iq');
cfg.outDir   = fullfile(cfg.root, 'results', 'pilot');

cfg.dumpLog  = fullfile(cfg.outDir, 'dump1090_last.txt');
cfg.dump1090 = '/opt/homebrew/bin/dump1090';

% Then we set the sample rate, dump1090's 12 MHz timestamp clock, and the
% number of samples in one 30 s pilot recording.

cfg.fs       = 2.4e6;
cfg.mlatHz   = 12e6;
cfg.nSamples = 72e6;

% Here we use dump1090's own center and scale for turning bytes into signal
% strength, which we measured by feeding it files of one constant byte.

cfg.dcDump   = 127.4;
cfg.fsDump   = 128;

% A preamble is 8 us (19 samples) long, so a message's data starts 19 samples
% after its first pulse.

cfg.preambleSamples = 19;

% Next we list the seven pilot recordings, their short labels, and which ones
% were on 1090 MHz.

cfg.names = {'20260921T132539Z_morning', '20260921T171320Z_midday', ...
             '20260921T202723Z_afternoon', '20260921T205711Z_control', ...
             '20260922T020220Z_late', '20260922T020320Z_control', ...
             '20260922T020354Z_late2'};
cfg.labels = {'001 morning', '002 midday', '003 afternoon', '004 control', ...
              '005 late', '006 control', '007 late2'};
cfg.is1090 = logical([1 1 1 0 1 0 1]);

% Then we start an if statement that swaps in the October campaign's 140
% recordings when a script asks for them with setenv('PAPERA_MODE', 'campaign').

cfg.mode = getenv('PAPERA_MODE');
if isempty(cfg.mode), cfg.mode = 'pilot'; end

if strcmp(cfg.mode, 'campaign')
    cfg = campaignFiles(cfg);
end

% Here we let PAPERA_OUTDIR send the results to another folder, which we only
% used to rerun the pilot and check that it still gave the same tables.

alt = getenv('PAPERA_OUTDIR');

if ~isempty(alt)
    cfg.outDir  = alt;
    cfg.dumpLog = fullfile(alt, 'dump1090_last.txt');
end

% Lastly, we make the output and scratch folders if they don't exist yet.

if ~exist(cfg.outDir, 'dir'), mkdir(cfg.outDir); end
if ~exist(fileparts(cfg.work), 'dir'), mkdir(fileparts(cfg.work)); end

end

function cfg = campaignFiles(cfg)

% First we point everything at the campaign: its data folder and manifest, a
% results folder of its own, and a scratch file the pilot never uses.

cfg.dataDir  = fullfile(cfg.root, 'data', 'Paper A folder');
cfg.manifest = fullfile(cfg.dataDir, 'manifest.csv');

cfg.outDir   = fullfile(cfg.root, 'results', 'campaign');
cfg.decDir   = fullfile(cfg.outDir, 'decoded');
cfg.dumpLog  = fullfile(cfg.outDir, 'dump1090_last.txt');

cfg.work     = fullfile(cfg.root, 'data', 'scratch', 'work_campaign.iq');
cfg.nSamples = 144e6;

% Then we read the manifest, the list of recordings the session runner wrote,
% and keep only the full-length ones (all 140 were).

opts = detectImportOptions(cfg.manifest, 'Delimiter', ',', 'TextType', 'string');
opts = setvartype(opts, {'date_local', 'session_utc', 'role', 'file', 'start_utc', 'note'}, 'string');
M = readtable(cfg.manifest, opts);
M = M(M.size_ok == 1 & M.bytes == 2 * cfg.nSamples, :);

% Lastly, we give each recording its file path, its day, its session number
% from 1 to 28, its role (1090 or one of the controls) and a short label.

cfg.files   = cellstr(fullfile(cfg.dataDir, compose("Day %d (%s)", M.day_n, M.date_local), M.file))';
cfg.names   = cellstr(erase(M.file, ".iq"))';

cfg.day     = M.day_n';
cfg.slot    = M.slot';
cfg.session = (M.day_n' - 1) * 4 + M.slot';
cfg.rec     = M.rec';

cfg.role    = M.role';
cfg.freqHz  = M.freq_hz';
cfg.startUtc = M.start_utc';

cfg.is1090  = M.role' == "1090";
cfg.labels  = cellstr(compose("s%02d r%d %s", cfg.session', cfg.rec', cfg.role'))';

end
