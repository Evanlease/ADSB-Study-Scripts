#!/usr/bin/env python3
"""Index every decoded message in a Paper A capture by sample position.

    .venv/bin/python3 analysis/decode_index.py --outdir results/campaign/decoded "data/Paper A folder"/Day*/*.iq
    .venv/bin/python3 analysis/decode_index.py --verify "data/Paper A folder"/Day*/NAME.iq

Runs dump1090 offline on the .iq file with --mlat, converts each message's
12 MHz timestamp to a sample index, and writes decoded/NAME.csv beside the iq folder:

    kind,df,ts12,sample_start,sample_end,n_samples,hex

sample_end is exclusive. Byte offset in the .iq file is 2 * sample index.

This is plumbing. It says where the decoder found messages; it says nothing
about what the samples in between are.

--verify re-measures, from the IQ itself, where messages sit relative to their
timestamp, so the constants below can be checked instead of trusted.
"""

import argparse
import csv
import os
import subprocess
import sys

# First we set where dump1090 lives, the sample rate of the recordings (2.4
# million per second), and the rate of dump1090's timestamp clock (12 MHz).

DUMP1090 = "/opt/homebrew/bin/dump1090"
FS_HZ = 2_400_000
MLAT_HZ = 12_000_000

# Then we list the three kinds of message by their length in bytes. For each
# one, "lead" is how many samples the first pulse starts before the timestamp,
# and "span" is the whole message's length in samples, preamble included
# (a Mode A/C reply is about 21 us, a short Mode S message 64 us and a long one
# 120 us). dump1090 doesn't document the lead, so we measured it with --verify
# on 500 messages of each kind from a recording made before the campaign, and
# checked it again on the campaign. The Mode A/C entry is a few samples wider than measured, so a
# soft edge isn't left out.

KINDS = {
    2:  ("modeac", 378, 55),
    7:  ("short",  480, 155),
    14: ("long",   480, 289),
}


def run_dump1090(path, binary):

    # Here we run dump1090 on one recording and keep every message line it
    # prints, with its timestamp.

    cmd = [binary, "--ifile", path, "--iformat", "UC8",
           "--modeac", "--raw", "--mlat"]
    proc = subprocess.run(cmd, capture_output=True, text=True)

    if proc.returncode != 0 and not proc.stdout:
        sys.exit("dump1090 failed on %s:\n%s" % (path, proc.stderr[-2000:]))

    return proc.stdout.splitlines()


def parse(lines, lead_modes, lead_modeac, guard):
    """Turn @<12 hex ts><hex payload>; lines into rows sorted by sample."""

    # First we start a for loop that skips any line that isn't a message, then
    # splits each message into its timestamp and its contents.

    rows = []
    for line in lines:
        line = line.strip()
        if not line.startswith("@") or not line.endswith(";"):
            continue

        body = line[1:-1]
        if len(body) < 16:
            continue

        try:
            ts = int(body[:12], 16)
        except ValueError:
            continue

        # Then we look up what kind of message it is from its length.

        payload = body[12:]
        nbytes = len(payload) // 2
        if nbytes not in KINDS:
            continue

        kind, lead, span = KINDS[nbytes]
        if kind == "modeac":
            lead = lead_modeac
            df = ""
        else:
            lead = lead_modes
            df = int(payload[:2], 16) >> 3

        # Lastly, we turn the timestamp into the sample where the message
        # starts and ends, and save it as a row.

        anchor = ts * FS_HZ // MLAT_HZ
        start = max(0, anchor - lead - guard)
        end = anchor - lead + span + guard

        rows.append({"kind": kind, "df": df, "ts12": ts,
                     "sample_start": start, "sample_end": end,
                     "n_samples": end - start, "hex": payload,
                     "anchor": anchor})

    rows.sort(key=lambda r: r["sample_start"])
    return rows


def write_csv(rows, out_path):

    # Here we write the rows to a CSV file, one message per line.

    cols = ["kind", "df", "ts12", "sample_start", "sample_end", "n_samples", "hex"]
    with open(out_path, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def summarise(name, rows, n_samples):

    # Here we count each kind of message and how much of the recording they
    # cover, and print one line.

    counts = {}
    covered = 0
    for r in rows:
        counts[r["kind"]] = counts.get(r["kind"], 0) + 1
        covered += r["n_samples"]

    parts = " ".join("%s=%d" % (k, counts.get(k, 0))
                     for k in ("long", "short", "modeac"))
    print("%-34s %s  total=%d  span-samples=%d (%.3f%% of file, overlaps not merged)"
          % (name, parts, len(rows), covered, 100.0 * covered / n_samples))


def verify(path, rows, limit):
    """Average |z| around each kind's anchor and report the leading edge."""

    # First we read the recording and find each sample's signal strength and
    # the recording's average level.

    import numpy as np
    x = np.fromfile(path, dtype=np.uint8)
    i = x[0::2].astype(np.float32) - 127.5
    q = x[1::2].astype(np.float32) - 127.5

    mag = np.sqrt(i * i + q * q)
    rms = float(np.sqrt((i * i + q * q).mean()))

    w0, w1 = -700, 300
    print("%s  rms=%.3f  window %d..%d around ts*FS/MLAT" % (path, rms, w0, w1))

    # Then we start a for loop over the three kinds of message. For each kind,
    # we average the signal strength around up to 500 timestamps and find where
    # the average first and last rises above 1.5 times the average level.

    for kind in ("long", "short", "modeac"):
        anchors = [r["anchor"] for r in rows if r["kind"] == kind][:limit]
        acc = np.zeros(w1 - w0)
        n = 0
        for a in anchors:
            if a + w0 > 0 and a + w1 < len(mag):
                acc += mag[a + w0:a + w1]
                n += 1

        if n == 0:
            print("  %-7s no messages" % kind)
            continue

        prof = acc / (n * rms)
        on = np.where(prof > 1.5)[0]
        if len(on) == 0:
            print("  %-7s n=%d  nothing above 1.5x rms in window" % (kind, n))
            continue

        first, last = w0 + int(on[0]), w0 + int(on[-1])
        print("  %-7s n=%-5d edge %+d..%+d  lead=%d span=%d (%.1f us)  peak %.2fx rms"
              % (kind, n, first, last, -first, last - first + 1,
                 (last - first + 1) / (FS_HZ / 1e6), prof.max()))


def main():

    # First we read the options typed after the script's name.

    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="+")
    ap.add_argument("--outdir", default=None,
                    help="default: <capture dir>/../decoded")
    ap.add_argument("--dump1090", default=DUMP1090)
    ap.add_argument("--guard", type=int, default=0,
                    help="extra samples added to each side of every span")
    ap.add_argument("--lead-modes", type=int, default=KINDS[7][1])
    ap.add_argument("--lead-modeac", type=int, default=KINDS[2][1])
    ap.add_argument("--verify", action="store_true",
                    help="measure the lead from the IQ instead of writing CSVs")
    ap.add_argument("--verify-limit", type=int, default=500)
    args = ap.parse_args()

    # Then we start a for loop that decodes each recording and either checks
    # the lead or saves the table of messages.

    for path in args.files:
        name = os.path.splitext(os.path.basename(path))[0]
        rows = parse(run_dump1090(path, args.dump1090),
                     args.lead_modes, args.lead_modeac, args.guard)
        if args.verify:
            verify(path, rows, args.verify_limit)
            continue

        outdir = args.outdir or os.path.join(os.path.dirname(os.path.abspath(path)),
                                             os.pardir, "decoded")
        outdir = os.path.abspath(outdir)
        os.makedirs(outdir, exist_ok=True)

        out_path = os.path.join(outdir, name + ".csv")
        write_csv(rows, out_path)
        summarise(name, rows, os.path.getsize(path) // 2)


if __name__ == "__main__":
    main()
