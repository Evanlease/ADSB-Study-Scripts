function lut = dumpLUT()

% First we reuse the table if we already built it.

persistent cached
if ~isempty(cached), lut = cached; return; end

% Then we start two for loops that build dump1090's signal strength for every
% pair of I and Q bytes.

cfg = expConfig();
lut = zeros(256, 256);

for i = 0:255
    for q = 0:255
        fI = (i - cfg.dcDump) / cfg.fsDump;
        fQ = (q - cfg.dcDump) / cfg.fsDump;
        magsq = min(fI^2 + fQ^2, 1);
        lut(i+1, q+1) = floor(sqrt(magsq) * 65535 + 0.5);
    end
end

% Lastly, we save the table for next time.

cached = lut;

end
