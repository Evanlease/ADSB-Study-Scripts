function out = runDump1090(iqPath, mode, extraFlags)

% First we start a switch statement that picks dump1090's options, for either
% its summary counts or every message.

cfg = expConfig();
if nargin < 3, extraFlags = ''; end

switch mode
    case 'stats'
        flags = '--modeac --stats --quiet';
    case 'raw'
        flags = '--modeac --raw --mlat';
    otherwise
        error('runDump1090:mode', 'mode must be stats or raw');
end

% Then we run it, send its output to a log file, and read the log.

cmd = sprintf('"%s" --ifile "%s" --iformat UC8 %s %s > "%s" 2>&1', ...
              cfg.dump1090, iqPath, flags, extraFlags, cfg.dumpLog);
system(cmd);
txt = fileread(cfg.dumpLog);

% Lastly, we start an if statement that pulls out the counts, or else each
% message's timestamp and hex.

if strcmp(mode, 'stats')
    out.samples     = grabInt(txt, '(\d+) samples processed');
    out.modeac      = grabInt(txt, '(\d+) Mode A/C messages received');
    out.preambles   = grabInt(txt, '(\d+) Mode-S message preambles received');

    out.badFormat   = grabInt(txt, '(\d+) with bad message format or invalid CRC');
    out.unknownIcao = grabInt(txt, '(\d+) with unrecognized ICAO address');

    out.accepted    = grabInt(txt, '(\d+) accepted with correct CRC');
    out.repaired    = grabInt(txt, '(\d+) accepted with 1-bit error repaired');
    if isnan(out.repaired), out.repaired = 0; end

    out.strong      = grabInt(txt, '(\d+) messages with signal power above');
    out.usable      = grabInt(txt, '(\d+) total usable messages');
    out.airbornePos = grabInt(txt, '(\d+) airborne position messages received');

    out.noiseDbfs   = grabDb(txt, 'dBFS noise power');
    out.signalDbfs  = grabDb(txt, 'dBFS mean signal power');
    out.peakDbfs    = grabDb(txt, 'dBFS peak signal power');

    if isnan(out.samples)
        error('runDump1090:parse', 'No stats found for %s:\n%s', iqPath, txt);
    end

else
    tok = regexp(txt, '@([0-9A-Fa-f]{12})([0-9A-Fa-f]+);', 'tokens');
    M = numel(tok);

    out.ts  = zeros(M, 1);
    out.hex = strings(M, 1);

    for k = 1:M
        out.ts(k)  = hex2dec(tok{k}{1});
        out.hex(k) = string(upper(tok{k}{2}));
    end
end

end

function v = grabInt(txt, pat)

% Here we grab the whole number that matches the pattern, or NaN if it isn't
% there.

t = regexp(txt, pat, 'tokens', 'once');
if isempty(t), v = NaN; else, v = str2double(t{1}); end

end

function v = grabDb(txt, label)

% Here we grab the dB value in front of the label, or NaN if there isn't one.

t = regexp(txt, ['(-?[\d.]+|-----)\s+' label], 'tokens', 'once');
if isempty(t) || strcmp(t{1}, '-----'), v = NaN; else, v = str2double(t{1}); end

end
