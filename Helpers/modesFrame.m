function [bits, hex] = modesFrame(icao, callsign)

% First we start a for loop that turns the 8 callsign characters into 6 bits
% each.

cs = upper(sprintf('%-8s', callsign));
me = [false true false false false, false false false];

for k = 1:8
    ch = cs(k);

    if ch >= 'A' && ch <= 'Z', code = ch - 'A' + 1;
    elseif ch >= '0' && ch <= '9', code = ch - '0' + 48;
    else, code = 32;
    end

    me = [me, bitget(code, 6:-1:1) == 1];

end

% Lastly, we put the message together and add its 24 check bits.

me(1:5) = [false false true false false];
data = [true false false false true, true false true, bitget(icao, 24:-1:1) == 1, me];
bits = [data, crc24(data)];
hex = bits2hex(bits);

end

function p = crc24(data)

% Here we work out the 24 check bits by long division.

g = [1, dec2bin(hex2dec('FFF409'), 24) - '0'] == 1;
r = [data, false(1, 24)];

for i = 1:numel(data)
    if r(i), r(i:i+24) = xor(r(i:i+24), g); end
end

p = r(end-23:end);

end

function hex = bits2hex(bits)

% Here we turn every 4 bits into one hex digit.

nib = reshape(bits, 4, []);
hex = string(dec2hex([8 4 2 1] * nib, 1)');

end
