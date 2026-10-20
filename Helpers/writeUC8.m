function writeUC8(path, bI, bQ)

% First we make sure I and Q are the same length.

if numel(bI) ~= numel(bQ), error('writeUC8:size', 'I and Q lengths differ'); end

% Then we put the bytes in the order I, Q, I, Q, ... and write them to the file.

raw = [uint8(bI(:))'; uint8(bQ(:))'];

fid = fopen(path, 'w');
if fid < 0, error('writeUC8:open', 'Cannot open %s', path); end
cleaner = onCleanup(@() fclose(fid));

fwrite(fid, raw(:), 'uint8');

end
