function [gI, gQ] = injectFrames(gI, gQ, starts, bits, A, phi, frac, h)

% First we set up the sample rate, the preamble pulse times, and the length of
% one message.

fs = 2.4;
pre = [0 1.0 3.5 4.5];
L = ceil(120 * fs) + 2 + numel(h);
N = numel(gI);

% Then we start a for loop where, for each message, we build its pulses, filter
% them, and add them to the noise.

for f = 1:numel(starts)
    t0 = [pre, 8 + (0:111) + 0.5 * ~bits(f, :)];
    a = t0 * fs + frac(f);  b = a + 0.5 * fs;
    w = zeros(L, 1);

    for n = 0:L-1
        w(n + 1) = sum(max(0, min(n + 1, b) - max(n, a)));
    end

    w = filter(h, 1, w) * A(f);

    idx = starts(f) + (1:L)';
    keep = idx <= N;

    gI(idx(keep)) = gI(idx(keep)) + w(keep) * cos(phi(f));
    gQ(idx(keep)) = gQ(idx(keep)) + w(keep) * sin(phi(f));

end

end
