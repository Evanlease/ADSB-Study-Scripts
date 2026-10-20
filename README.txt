NOISE FLOOR OF AN 8-BIT ADS-B RECEIVER
Analysis code

Adrian Iugan
Recordings made October 12 to 18, 2026


READ THIS FIRST

This folder holds the code behind my paper "Measuring the Noise Floor of an
8-bit ADS-B Receiver: What the Reported Number Gets Wrong, Which Estimators
Resist Traffic, and What the Background Costs in Detections". It holds only
the scripts that produced the paper's numbers and figures, and this file
explains the order they ran in.

The recordings aren't in this folder. They're on Zenodo, with the decoded
messages and every result table the scripts made:

  https://doi.org/10.5281/zenodo.23489397

"What you'd need to run it" at the bottom says what else the code needs.


THE STUDY IN BRIEF

ADS-B is the system where aircraft broadcast their own position on 1090 MHz.
Many people receive it with a cheap USB radio (an RTL-SDR) and a decoder
program called dump1090-fa, which reports a "noise" number that people use to
judge how well their station is working.

I recorded with one RTL-SDR Blog V3 at a fixed gain (44.5 dB) on a rooftop,
four sessions a day for seven days. Each session was five one-minute
recordings in this order: 1090 MHz, a control frequency, 1090 MHz, the other
control, 1090 MHz. The controls, 1082 and 1098 MHz, lie outside the ADS-B
channel and serve as rough references for the background. That's 28 sessions
and 140 recordings of raw 8-bit I and Q at 2.4 million samples per second.

The code asks three things:

  1. Does the decoder's noise number measure the receiver's background, or
     does aircraft traffic move it?
  2. Which ways of measuring the background does traffic leave alone?
  3. What does a small background cost in decoded messages?

The short version, for the 25 sessions that passed the quality rules: the
reported noise sat a median of 2.08 dB above a model of the background on
1090 MHz and 0.14 dB above it on the controls, and the gap grew with traffic
(Spearman's rho = 0.62, p = 0.0014). Cutting the decoded messages out of a
recording moved the total power by 3.51 dB, the cell-fraction estimate by
0.109 dB and the central fit by 0.031 dB. A background of 0.73 LSB needed
about 0.6 dB more signal to decode half of the test messages than one of
1.2 LSB.

These are measurements of one station, at one site, over one week. Power
levels are uncalibrated dBFS, not dBm. I'm not claiming any of it is new:
forum posts had already pointed out that the noise number includes traffic,
the estimators apply old ideas, and I haven't finished my own search of
earlier work.


WORDS USED BELOW

  Background     What the receiver picks up when no aircraft signal is there.
  LSB            One step of the receiver's 8-bit converter, which stores
                 every sample as a whole number from 0 to 255.
  Sigma          The spread (standard deviation) of the background, in LSB.
                 At my station it's about 0.7 to 1.3.
  Cell fraction  The share of samples whose I and Q are both 127 or 128. It
                 turns into sigma.
  Session        One run of five recordings. The session, not the recording,
                 is the unit of analysis.
  Control        A recording at 1082 or 1098 MHz.
  Twin           A file of made-up noise built to match a real recording's
                 background.
  Table          A CSV file of results.


THE ORDER THE SCRIPTS RAN IN

There are eight steps. Each one needs the tables made by the steps above it,
so they have to run in this order.

   Step  Script                    Folder
   ----  ------------------------  ------------------------
    1    decode_index.py           1 Decode
    2    campaignMinutes           2 Measure
    3    campaignSessions          3 Statistics
    4    campaignTwins             4 Twins and sensitivity
    5    campaignInjection         4 Twins and sensitivity
    6    campaignFigures           5 Figures
    7    campaignDaySensitivity    3 Statistics
    8    journalFigures            5 Figures

Steps 4 and 5 don't depend on each other, so either can go first. Step 7
was added after all the results were in, as a later check, and it only needs
step 3. Step 8 only needs steps 2 to 5, so it can run any time after them.

Below, "Reads" is what a step takes in, "Calls" is the helpers it uses, and
"Makes" is what it saves.

   1  decode_index.py   (1 Decode)
      Runs dump1090 on each recording, turns each decoded message's timestamp
      into the sample where the message starts and ends, and saves one table
      per recording. Its --verify option measures where messages really sit
      relative to their timestamps, which I checked on a campaign recording.
      Reads:  the recordings
      Makes:  decoded/NAME.csv, one per recording

   2  campaignMinutes   (2 Measure)
      Measures every recording: the background estimators with and without
      the decoded messages, dump1090's counts and noise number, that noise
      number rebuilt from the raw samples, the quietest-window rule, clipping,
      the pulse mask on controls (rule R1), and sigma in each one-second
      block. It saves each recording as it goes, so a crash doesn't mean
      starting over.
      Reads:  the recordings, the manifest, the decoded tables
      Calls:  minuteMetrics, which calls allEstimators, dumpLUT, quantModel,
              readDecoded, readUC8, runDump1090 and sigmaFromCellDC
      Makes:  minutes.csv, blocks.csv

   3  campaignSessions   (3 Statistics)
      Applies quality rules R3 to R5, works out each session's numbers, and
      runs the paper's tests: the reported noise against the background, the
      estimators against traffic, the declared test, the five sensitivity
      runs, and how the floor moved over the week.
      Reads:  minutes.csv, blocks.csv
      Calls:  bootCI, dumpLUT, quantModel, rankAvg, readCampaign,
              signrankTest, spearmanRho
      Makes:  minutes_flagged.csv, sessions.csv, floor_by_session.csv,
              summary.txt

   4  campaignTwins   (4 Twins and sensitivity)
      Builds noise-only twins at 38 backgrounds from 0.65 to 2.5 LSB, runs
      dump1090 on each, and compares their preamble counts with the real
      recordings'.
      Reads:  minutes_flagged.csv
      Calls:  colorTwin, readCampaign, runDump1090, writeUC8
      Makes:  twins.csv, preambles.csv

   5  campaignInjection   (4 Twins and sensitivity)
      Adds test messages at 23 levels from 0 to 22 dB to one real control per
      session, and finds the SNR at which half and 90% of them decode.
      Reads:  minutes_flagged.csv, the control recordings, and
              injection_summary.csv (see below)
      Calls:  colorTwin, injectFrames, modesFrame, readCampaign, readUC8,
              runDump1090, spearmanRho, writeUC8
      Makes:  injection_campaign.csv, injection_campaign_summary.csv

   6  campaignFigures   (5 Figures)
      Draws the eight figures of the long version of the paper. Two of them,
      fig01_session.png and fig05_estimators.png, are the article's
      Supplementary Figures S1 and S2.
      Reads:  minutes_flagged.csv, sessions.csv, floor_by_session.csv,
              blocks.csv, twins.csv, preambles.csv,
              injection_campaign_summary.csv, injection_summary.csv
      Calls:  readCampaign, spearmanRho
      Makes:  fig01_session.png to fig08_overload.png

   7  campaignDaySensitivity   (3 Statistics)
      Redoes the main intervals and tests while allowing sessions recorded on
      the same day to be alike: it resamples whole days instead of sessions,
      shuffles message rates only within days, and tests the seven day
      medians.
      Reads:  sessions.csv
      Calls:  bootCI, rankAvg, readCampaign, signrankTest, spearmanRho
      Makes:  day_sensitivity.csv, day_sensitivity.txt

   8  journalFigures   (5 Figures)
      Draws Figures 1 to 4 of the article.
      Reads:  minutes_flagged.csv, sessions.csv, floor_by_session.csv,
              blocks.csv, twins.csv, preambles.csv,
              injection_campaign_summary.csv
      Calls:  readCampaign
      Makes:  fig1_floor_gap.png to fig4_overload.png

injection_summary.csv is a decode curve from made-up noise, made with earlier
code that isn't in this folder. Step 5 measures how far each control sits
from it, and step 6 draws it in one figure of the long version. The article
uses neither.


HOW THE DATA MOVES

          The 140 recordings
                  |
                  v
       decode_index.py (step 1) ------> one decoded table per recording
                  |                                  |
                  v                                  v
            campaignMinutes (step 2), which also runs dump1090
                  |
                  v
         minutes.csv, blocks.csv
                  |
                  v
          campaignSessions (step 3)
                  |
                  v
   minutes_flagged.csv, sessions.csv, floor_by_session.csv
           |                    |                    |
           v                    v                    v
   campaignTwins (4)   campaignInjection (5)   campaignDaySensitivity (7)
           |                    |
           v                    v
   twins.csv,         injection_campaign_summary.csv
   preambles.csv
           |                    |
           +---------+----------+
                     |
                     v
          campaignFigures (step 6)
                     |
                     v
               eight figures

campaignFigures also reads the tables from steps 2 and 3. journalFigures
(step 8) reads the same campaign tables and draws the article's four
figures.


HOW THE CODE IS ORGANIZED

There are 26 files: about 1,150 lines of MATLAB and 140 lines of Python. They
come in four kinds.

  Settings (1 file)
      expConfig.m is a function that returns every setting in one variable,
      cfg.

  Decoding (1 file)
      decode_index.py is the one Python script.

  Scripts (7 files)
      Each script runs one MATLAB step from start to finish.

  Helpers (17 files)
      Each helper is a function that does one small job, like reading a
      recording or making noise.

Four rules hold it together:

  1. Every MATLAB script starts by switching to the campaign data,
     setenv('PAPERA_MODE', 'campaign'), and loading the settings,
     cfg = expConfig();
  2. No script calls another script. Scripts only call helpers.
  3. Scripts pass results to each other through tables. That's why the run
     order is fixed.
  4. Helpers never save tables. One helper, readCampaign, reads a table for
     the script that calls it.

Each block of code has a short comment above it that says what the block
does.


WHAT'S IN EACH FOLDER

  (top level)              1 file     expConfig.m, the settings every script
                                      reads first
  1 Decode                 1 file     decode_index.py, step 1
  2 Measure                1 file     campaignMinutes, step 2
  3 Statistics             2 files    campaignSessions (step 3) and
                                      campaignDaySensitivity (step 7)
  4 Twins and sensitivity  2 files    campaignTwins (step 4) and
                                      campaignInjection (step 5)
  5 Figures                1 file     campaignFigures, step 6
  Helpers                  17 files   Functions the scripts call


THE HELPERS

I've grouped them here by the job they do. In the folder they're one flat
list.

  Reading and writing files

    readUC8          Reads a recording into I and Q bytes
    writeUC8         Writes I and Q bytes back out as a recording
    readDecoded      Reads the table of decoded messages for one recording
    readCampaign     Reads a result table, keeping text columns as text

  Working with dump1090

    runDump1090      Runs dump1090 on a file and pulls out its counts or its
                     messages
    dumpLUT          Rebuilds dump1090's table of signal strength for every
                     pair of bytes

  Measuring the background

    minuteMetrics    Everything measured on one recording
    allEstimators    Runs the background estimators. The paper uses three of
                     them: mean power, cell fraction and central fit
    sigmaFromCellDC  Turns the cell fraction into sigma, using the
                     recording's measured center
    quantModel       The chance of each byte when a bell curve gets rounded

  Making test signals

    colorTwin        Builds a twin whose neighboring samples are as alike as
                     the real receiver's
    modesFrame       Builds one Mode S test message and its 24 check bits
    injectFrames     Adds test messages to a file of noise

  Statistics

    rankAvg          Ranks values, giving tied values the average of their
                     ranks
    spearmanRho      Spearman's rank correlation
    signrankTest     The exact Wilcoxon signed-rank test
    bootCI           A 95% bootstrap interval

The four statistics helpers exist because I used MATLAB without its
Statistics Toolbox.


WHAT YOU'D NEED TO RUN IT

  - MATLAB. I used R2026a with no toolboxes.
  - dump1090-fa 11.1. I used the Homebrew version on a Mac. expConfig.m and
    decode_index.py both hold its path (/opt/homebrew/bin/dump1090), so
    change both for your machine.
  - Python 3 for decode_index.py. Decoding needs only the standard library;
    its --verify check also needs numpy.
  - The recordings and their manifest, from the Zenodo record above. They're
    raw 8-bit I and Q, the format rtl_sdr writes, 288,000,000 bytes each.
    The dataset's own README.txt says where each of its folders goes.

The made-up noise, the test messages, the bootstraps and the permutations all
use fixed random seeds, so they come out the same every time.


WHY IT DOESN'T RUN FROM HERE

Two reasons.

First, MATLAB only finds a function when its file is in the current folder or
on its path (the list of folders MATLAB searches). I sorted the files into
folders so they're easier to read, and nothing adds those folders to the
path. Putting every .m file back in one folder fixes this.

Second, expConfig.m finds everything relative to its own folder. It expects
to sit in a folder called analysis, with the recordings in
../data/Paper A folder/ (one "Day N (date)" folder per day, plus
manifest.csv) and results going to ../results/campaign/.

With that layout, step 1 runs from the project folder like this:

  python3 analysis/decode_index.py --outdir results/campaign/decoded
      "data/Paper A folder"/Day*/*.iq

(all on one line), and the MATLAB steps then run in the order above.
Everything was run from the flat analysis folder, never from this layout.
