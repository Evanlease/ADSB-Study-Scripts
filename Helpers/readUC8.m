function [bI, bQ] = readUC8(path, firstSample, nSamples)

% First we default to reading the whole file.

if nargin < 2, firstSample = 1; end
if nargin < 3, nSamples = Inf; end

% Then we open the file and skip ahead to the first sample we want.

fid = fopen(path, 'r');
if fid < 0, error('readUC8:open', 'Cannot open %s', path); end
cleaner = onCleanup(@() fclose(fid));

if firstSample > 1
    fseek(fid, 2 * (firstSample - 1), 'bof');
end

% Lastly, we read the bytes and split them into I and Q.

raw = fread(fid, 2 * nSamples, '*uint8');
if mod(numel(raw), 2), raw(end) = []; end

bI = raw(1:2:end);
bQ = raw(2:2:end);

end
