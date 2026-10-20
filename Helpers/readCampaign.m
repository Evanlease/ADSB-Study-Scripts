function T = readCampaign(file)

% First we read a campaign table and keep the text columns as text, since a
% role of "1090" would otherwise be read as a number and turn ctl_lo and ctl_hi
% into NaN.

opts = detectImportOptions(file, 'Delimiter', ',');
txt = intersect(opts.VariableNames, {'name', 'role', 'startUtc'});
opts = setvartype(opts, txt, 'string');
T = readtable(file, opts);

% Then we start a for loop that turns the yes/no columns back into true and
% false, since they come back as 1 and 0.

for v = intersect(T.Properties.VariableNames, {'headline', 'overload', 'inSet', 'r3Flag'})
    T.(v{1}) = logical(T.(v{1}));
end

end
