# SpinalAdapt

Measures spinal-level H-reflex adaptation to split-belt treadmill
walking alongside prefrontal cortex oxygenation (fNIRS). H-reflex
responses are elicited by Arduino-triggered Digitimer DS8R
stimulators at a fixed phase of the gait cycle.

## Status

**Rebooting.** Data collection is planned to resume approximately
July 2026. Protocol software updates may be required to ensure
precise H-reflex stimulation timing before collection resumes.

## Experimenters

| Role | Name |
|---|---|
| Lead | Chase Rock (post-doctoral fellow) |
| Key | Shuqi Liu |
| Key | Nate Brantly |

## Subject IDs

| Format | Population |
|---|---|
| `SABH##` | Healthy controls |
| `SAS##V##` | Participants with stroke (two visits) |

## Protocol Notes

**Fast speed** is computed from the N-Minute Walk Test comfortable
overground walking speed via `utils.extractSpeedsNMWT()`. Slow speed
= fast × 0.5 for the current protocol design (`speedProportion` in
`RunProtocol_SpinalAdaptBouts.m`); Pilot Study 2 used 0.7, changed from
0.5 after participant SABH16 (July 2024) — see Study History below.

**Current protocol design (revised 2026-08-13, subject to further
revision):**

| Condition | # | Strides (excl. rest pads) |
|---|---|---|
| Familiarization Slow / Fast (tied, 5 bouts × 3 ramp + 10 SS) | 2 | 65 each |
| Control Bouts (tied, 10 bouts × 3 ramp + 10 SS) | 6 | 130 each |
| Split Bouts (10 bouts × 3 ramp + 10 SS per trial) | 5 | 130 each |

Total: 2×65 + 6×130 + 5×130 = **1,560 strides**. Profile files:
`FamBoutsSlow.mat`, `FamBoutsFast.mat`, `CtrlBouts.mat`,
`SplitBouts.mat`. H-reflex walking calibration
(`CalibrationFast.mat`, `CalibrationSlow.mat`, 400 strides each) runs
separately before and after the main protocol via
`runWalkingCalibrations`, not as a numbered condition. There are no
TM/OG baseline or post-adapt conditions or profiles in the current
design — the previous protocol version used the TM baseline step
length asymmetry to determine each stroke participant's fast/slow leg
assignment; the current design takes `fastLeg` as a direct
experimenter input instead (`RunProtocol_SpinalAdaptBouts.m`), so
those profiles were removed from `generateProfiles_SpinalAdaptBouts`.

- Calibration trials: `NirsHreflexArduinoOpenLoopWithAudio` (slot 14).
- Bout timing and cues (`NirsHreflexArduinoOpenLoopWithAudio`, revised
  2026-08-13): the inter-bout rest is a fixed ~10 s SILENT window
  (`restSilentSec`, belts stopped, timer padded by the `stopAndRest`
  cue's own length so it excludes the cue), applied to every run of
  this controller including fNIRS/H-reflex sessions. Every bout start
  (tied ramp = `AccRamp`, split ramp = `DccRamp2Split`) announces
  "Walk" exactly once, with no 3-2-1 countdown; bout 1 gets the same
  "Walk" cue from the pre-loop block, and the ramp-event cue is
  suppressed only for that first bout to avoid a duplicate. Every
  belt stop (each inter-bout rest and the trial end) plays
  `stopAndRest.mp3`, also with no countdown. The speed ramp at each
  bout start is 3 strides (`rampStrides` in
  `generateProfiles_SpinalAdaptBouts.m`, reduced from 10). The "which
  bout to start from" dialog range and default are derived from the
  loaded profile's bout count (5 for familiarization, 10 for
  Control/Split), not hard-coded. The break between trials
  (`pauseBetweenTrials` in `RunProtocol_SpinalAdaptBouts.m`) targets
  ~90 s wall clock, reduced from ~150 s.
- H-reflex stimulation timing: `NirsHreflexArduinoOpenLoopWithAudio`
  paired with firmware `triggerStimWithGaitStateMachine_SpeedIndependent`
  is the authoritative, Arduino-timed path. The Arduino owns the
  precise 50%-single-stance pulse timing; `NirsHreflexArduinoOpenLoopWithAudio`
  sends command `0` once before the main loop to start the Arduino's
  state machine, a per-stride gate byte (`1`/`2`) during the double
  support phase immediately preceding single-stance onset, and command
  `3` in the closing routine to stop the state machine. Earlier code
  waited until mid-stance to send the gate, which left too little margin
  before the Arduino's 50% trigger and caused missed or mistimed stims
  under control-loop jitter; later code moved the send to single-stance
  onset, and it was moved earlier still, to the preceding double
  support, to further widen the margin — all MATLAB-only, no firmware
  change. Display work was also moved off the control loop's hot path
  (`drawnow limitrate`, reusable `animatedline` markers, throttled
  textbox updates). Both sides estimate single-stance duration via an
  EWMA (`alpha = 0.70`), with each candidate duration clamped to
  100-1000 ms before the update to reject doubled/missed detections
  and standing rests; MATLAB mirrors the firmware's alpha/clamp in its
  own diagnostics EWMA. The firmware also echoes each delivered
  pulse's actual fire time back over serial (`echoStimRecord`), which
  MATLAB logs to the additive `datlog.stim.deviceEcho` field as a lab
  ground-truth check (informational only — it does not feed the firing
  decision). The deprecated `NirsHreflexOpenLoopWithAudio` (now in
  `controllers/Deprecated/`) pairs with the alternative
  `Dual_Stim_Matlab.ino` firmware (fully MATLAB-timed, no on-board gait
  detection) and is a frozen bench/emergency fallback only — do not
  extend it or treat it as a starting point.
- **Missed / wrong-stride stim bug, root cause and fix (2026-08-06):**
  the 2026-08-05 pilot (`CalibrationSlow`, `CtrlBouts`) delivered some
  gates as missed pulses and some one stride late, both still correctly
  timed to 50% of single stance when they did fire. Root cause:
  `NirsHreflexArduinoOpenLoopWithAudio.m` sent every Arduino command
  with `write(portArduino,X,'int16')` — two bytes, command + a
  trailing `0x00` — but the firmware's `processSerialCommands()` reads
  one byte per `loop()` pass and dispatches `case 0` to
  `resetStateMachine()`. Every gate byte was therefore immediately
  followed by a spurious full state-machine reset a few hundred ms
  before the single stance it was meant to gate, which (via the
  cross-leg debounce in `updateGaitEventStateMachine()`) could erase
  the real contralateral toe-off event and stall `phase`, carrying the
  gate into a later stride. Confirmed from the pilot datlogs: the
  echoed `ardStep` column (`numStepsL/R` on the Arduino) only ever took
  values `{0, 1}` across both trials — the signature of a counter that
  keeps getting zeroed mid-trial. Fix: all four `write(...)` calls now
  use `'uint8'` (one byte, matching what the firmware actually reads),
  with the command bytes as named constants
  (`cmdArduinoStart`/`Stop`/`StimL`/`StimR`). No firmware re-flash is
  required for this half of the fix; the serial protocol values
  (`0`/`1`/`2`/`3`) are unchanged. Paired with it, the firmware gained
  a lateness guard and a gate-expiry guard in `triggerStimulation()`
  (see `HreflexStimArduino/README.md`) so that any gate that is still
  late or unconsumed is dropped — echoed as a `D` record — rather than
  fired off-target or carried forward; this **does** require a
  re-flash. The `ardStep`-decreased regression sentinel added to the
  controller (warns once per leg, logs to `datlog.errormsgs`) is the
  direct guard against this bug class recurring. See the dry-run
  checklist below before the next pilot.
- **Date/time modernization (2026-07):** `now`/`datestr`/`clock`/`etime`
  calls in `NirsHreflexArduinoOpenLoopWithAudio.m` were replaced with
  `datetime`/`char`/`tic`-`toc` equivalents to clear MATLAB Code
  Analyzer warnings, with no change to trial behavior, timing, or the
  saved datlog. Two categories are deliberately left as-is with a
  `%#ok` suppression rather than converted: (1) the hot-path fields
  that store a raw serial date number consumed by in-loop datenum
  arithmetic (`RTOTime`/`LTOTime`/`RHSTime`/`LHSTime`, `stim.{L,R}`
  GateSendTime, `commSendTime`, `messages`, `framenumbers`/`forces`/
  `stepdata`/`TreadmillCommands` "U Time" columns, and `buildtime`) —
  converting the call would either change the stored type or add a
  per-frame `datetime` construction cost to the stim control loop; and
  (2) the teardown `etime(datevec(...))` relative-time columns that
  labTools' `SyncDatalog` reads in seconds, where a `datetime`-based
  replacement was measured to differ by up to ~5e-5 s from the
  original — small, but not the bit-identical match those columns
  need. Genuine storage-format modernization for both is deferred to a
  coordinated ExperimentalGUI + labTools change.

## Validation Before Resuming Collection

The controller logs per-iteration loop timing and gate lead time to the
additive `datlog.diagnostics` field. Before participant collection,
confirm:

- **0 missed stims** — intended stims (count of `1`s in the `stimL` /
  `stimR` profile columns) equal delivered pulses (Vicon-recorded
  Arduino trigger count).
- **Tight stim timing** — stimulus fires near 50% of single stance;
  check the distribution from labTools `computeHreflexParameters`
  (`stimTimeFromSingleStanceSlow/Fast`).
- **Loop timing** — review `datlog.diagnostics.loopSegMs` (median, p95,
  max) and `gateLeadMs*` (positive = gate arrived that many ms *before*
  single-stance onset; expect roughly a double-support duration of lead).
- **Bench check** — run `HreflexStimArduino/LogForcesArduinoSerial.m`
  with a short dummy profile at low treadmill speed and confirm every
  intended stride fires once near mid-single-stance.

### Dummy-Profile Dry Run (treadmill only, no participant)

Run this after any change to the serial encoding or firmware timing
guards (e.g., the 2026-08-06 fix above), before the next pilot or
participant session. **Re-flash the Arduino first** if the firmware
changed — see `HreflexStimArduino/README.md`'s upload workflow (COM4).

**Setup**

- [ ] Upload the current firmware; bench-check per
      `HreflexStimArduino/README.md`'s "Validating Stim Timing" step 2,
      including the outlier-clamp and drop-guard checks.
- [ ] DS8R output disconnected or intensity at zero. The Vicon sync
      pins stay live regardless, so echoes and sync pulses are still
      produced — full end-to-end timing validation with nothing
      delivered to a person.
- [ ] Dummy profile: ~40 tied strides at the slow calibration speed,
      stim on every 2nd stride; then repeat with stim on **every**
      stride (the `CtrlBouts` pattern that exposed the original 35%
      loss on the left leg, and the harder test).
- [ ] Experimenter walks on the treadmill for each run.

**Acceptance** (load the saved `datlogs/*.mat` after each run). Checks 2-3
reference `stim.deviceDrop`, which exists only in datlogs collected with
this fix (2026-08-06 or later) — guard with
`isfield(datlog.stim,'deviceDrop')` if comparing against an older log
(e.g., the 2026-08-05 pilot files), which predate the field entirely.

1. **`ardStep` climbs monotonically per leg into the tens.** The
   load-bearing check: the direct regression test for the encoding bug,
   and proof that exactly one byte went out per command. Any `{0, 1}`
   pattern means the fix did not take.
2. **Full accounting:** `size(stim.L,1) + size(stim.R,1)` equals
   `size(stim.deviceEcho.data,1) + size(stim.deviceDrop.data,1)` — no
   gate unexplained.
3. **`stim.deviceDrop` is empty.** If not, the firmware's lateness or
   gate-expiry guard fired — read the dropped rows' `dtStimMs` for how
   late. Empty here isolates the encoding fix (check 1) from the
   firmware guards (this check).
4. **Zero missed pulses:** `size(deviceEcho.data,1)` equals the number
   of `1`s in the profile's `stimL`/`stimR` columns for strides walked.
5. **On-target timing:** `abs(dtStimMs - estSSms/2) <= 5` for every
   delivered row, and `pctSS` within 50 ± 5%.
6. **`gateLeadMs*` all positive**, roughly a double-support duration.
   Negative or near-zero means the gate is arriving at onset rather
   than during the preceding double support.
7. **Loop timing unchanged:** `diagnostics.loopSegMs` median and p95
   comparable to prior pilots (median ~10-11 ms, p95 ~70-90 ms). The
   added logging must not touch the hot path's cost.
8. **Stop actually stops** (new behavior — command `3` previously
   self-cancelled via the same encoding bug): after STOP, confirm no
   further echoes arrive and the Arduino's stim/Vicon pins read LOW.

**Still unvalidated after this dry run**, to be run once stim testing
on a person is scheduled: the Vicon-sync acceptance test
(`100 × (stimVsync − RTO) / (RHS − RTO)` on the Vicon clock, target
50 ± 5%) per `HreflexStimArduino/README.md`'s acceptance test steps
4-5, and a live lab dry-run of the H-Reflex M-Wave Monitor tool
(below) — it is replay-validated against real prior calibration data
but not yet run live in the lab.

## Study History

| Archive folder | Description |
|---|---|
| `History-PilotStudy1/` | Original pilot — simpler tied/split structure; no fNIRS bout design. Scripts: `SpinalAdaptProtocol.m`, `GenerateProfileSpinalStudy.m`. |
| `History-PilotStudy2/` | Bout-based protocol — participants SABH01 through at least SABH16+ (July 2023–2025). Speed ratio changed from 0.5 to 0.7 after SABH16 (July 2024); ramp-to-split option added then later removed. Scripts reformatted to CLAUDE.md style (June 2026). |

2026-08-13 redesign of the active files (this folder's current templates,
not yet archived): ramp strides per bout reduced 10 → 3; bout-start cue
simplified from a 3-2-1 countdown to a single "Walk"; belt-stop cue
simplified to `stopAndRest.mp3` only, no countdown; inter-trial break
reduced from ~150 s to ~90 s wall clock; `TMBaselineFast/Slow` and
`OGBaselineFast/Slow` profiles and the `baseOnly` generator mode removed
(the fast/slow leg assignment they supported is now a direct
`fastLeg` input rather than derived from a TM baseline trial).

The active files in this folder are templates for the next protocol version.
Initial protocol design is incorporated (bout structure described below);
verify all parameters against the final approved protocol before collection.

## Key Scripts

| Script | Status | Purpose |
|---|---|---|
| `RunProtocol_SpinalAdaptBouts.m` | Template | Main protocol runner |
| `generateProfiles_SpinalAdaptBouts.m` | Template | Speed and stim profile generator |
| `runWalkingCalibrations.m` | Active | H-reflex walking calibration helper |
| `transferData_SpinalAdaptBouts.m` | Active | Data transfer and archival |

## H-Reflex M-Wave Monitor

A near-real-time M-wave monitor helps the experimenter hold each leg's
H-reflex M-wave within ~±10% of its calibration baseline during a
session by watching a live plot and adjusting DS8R current
accordingly. It runs in a **separate MATLAB instance** from this
study's control/stimulation instance, so it cannot perturb
`NirsHreflexArduinoOpenLoopWithAudio`'s control-loop timing.

Built for SpinalAdapt, the tool now lives outside this folder, at
[`HreflexMwaveMonitor/`](../../HreflexMwaveMonitor/README.md) (repo
root), since H-reflex measurement may not stay unique to this study —
see that folder's README for the full file list, phase status,
real-data validation results, and known gaps.

## H-Reflex Calibration Processing

After each walking dynamic H-reflex calibration trial, a Vicon Nexus
2.12 processing pipeline automatically runs
`labTools/fun/misc/generateHreflexRecruitmentCurves.m`. This script
is **not** called by ExperimentalGUI — it is triggered by Nexus after
each calibration C3D is saved.

The script accesses the current open trial via `ViconNexus()` (Vicon
Nexus MATLAB SDK), loads analog EMG and force-plate data via BTK
(`btkReadAcquisition`, `btkGetAnalogs`), and calls the `+Hreflex`
namespace in labTools to produce recruitment curves. Output figures
are saved to a `HreflexCalFigs/` subfolder of the trial directory.
The experimenter inspects the curves to select the stimulation
current for the walking adaptation trials (target: ≈ 10–20% of
maximum M-wave).

**`+Hreflex` functions called by this pipeline** (all in
`labTools/fun/+Hreflex/`):

| Function | Role |
|---|---|
| `extractStimArtifactIndsFromTrigger` | Locate the artifact peak in a window anchored to each trigger pulse |
| `plotStimArtifactPeaks` | Plot detected peaks for QC |
| `extractSnippets` | Extract per-pulse EMG windows |
| `plotSnippets` | Plot per-pulse snippets for QC |
| `extractBackgroundEMG` | Compute pre-stimulus background level |
| `computeAmplitudes` | Peak-to-peak M- and H-wave amplitudes |
| `fitCal` | Fit recruitment curves to amplitude vs. current |
| `plotNoiseHistogram` | Plot background EMG noise distribution |
| `plotCal` | Plot fitted recruitment curves |

### Collection-Side Prerequisite: Trigger Sync Channels

The trial **must** record the two stimulator trigger sync channels
(`Stimulator_Trigger_Sync_Right_Stimulator` and
`Stimulator_Trigger_Sync_Left__Stimulator`, 0 → ~4.3 V). They anchor a
±100 ms search window around each pulse — wide enough to span the
~50 ms Delsys wireless EMG transmission delay — and that anchoring is
what makes artifact localization reliable. Without them the script has
to search the whole trial blind. **Confirm the channels appear in the
Vicon Nexus analog device configuration before collection.** The
2026-08-21 dry run's C3D had neither, and the script silently degraded;
it now stops and asks (Abort / Continue with threshold detection)
instead.

### 2026-08-21 Dry Run: Findings and Fixes (2026-08-26)

That calibration trial produced no recruitment curves. Four
independent causes, all now fixed:

1. **`Hreflex.plotStimArtifactPeaks` crashed at both call sites** — the
   one `+Hreflex` function never migrated to an `arguments` block, so
   it parsed the script's name-value pairs positionally. Converted; it
   now also accepts `labels` (the artifact muscle per leg) and
   `isWeak`, which draws flagged stimuli as red circles.
2. **The artifact is negative-dominant** — a sharp downward deflection
   with a smaller positive rebound ~1.5 ms later. Both localization
   paths searched for a signed-positive peak above a 1 mV height gate,
   so they either locked onto the rebound or, when the artifact was
   small, found nothing and fell back to the raw maximum over a 200 ms
   window. Both now take the largest **absolute** deflection from the
   window median. This was never dry-run-specific: SABH02 `Trial03`
   is negative-dominant too (|min|/max ≈ 2.0 on both TAP channels) and
   worked only because a larger artifact made the rebound clear 1 mV.
3. **No trigger sync channels** (see the prerequisite above).
4. **Only the left leg was stimulated**, but the script required
   RTAP/LTAP/RSOL/LSOL and assumed two legs throughout. A leg is now
   analyzed only if stimulation amplitudes were entered for it —
   **leave a leg's amplitude field blank when it was not stimulated**
   — and every figure, fit, and curve is per leg.

Also changed in that pass:

- **Muscle selection.** Two new dialog fields (appended, so older
  config files are padded with defaults rather than rejected): the
  H-reflex muscle (default `SOL`) and the artifact localization muscle
  (default `TAP`, falling back to the H-reflex muscle when that leg
  has no such channel).
- **Artifact threshold is now a quality control floor, not a gate**,
  in both paths: a stimulus below it is flagged and drawn in red, not
  discarded. On the dry run a 0.3 mV gate excluded 3 of 60 real
  artifacts. Without a trigger pulse the script instead ranks
  candidate deflections by size and keeps the number of stimuli
  entered, which located all 60.
- **Per-leg QC summary** printed to the console: stimuli located vs.
  expected, median peak artifact, and flagged count. This is how a
  dead leg reads at a glance — the dry run's right SOL peaked at
  0.047 mV against the left leg's 3.5 mV.
- **Config files shrank from ~200 MB to <1 KB** — the analog data and
  the BTK handle are no longer saved alongside `answer`, which is all
  that is ever loaded back (SABH02 had ≈1.4 GB of them).
- Default minimum time between stimulation pulses lowered from 5 s to
  1 s: at most one stimulus per stride per leg, and a stride is ≳1 s.
  At 5 s the fallback could not resolve the dry run's ~3.5 s per-leg
  interval.

**Verified.** On SABH02 `Trial03` (known-good reference) the new
localization keeps all 60 stimuli per leg, shifts every index 1.5 ms
earlier (max 2.0 ms) onto the artifact's initial deflection, and moves
mean M-wave amplitude by −0.23% (right) and +0.57% (left). On the dry
run trial the script now runs to completion: 60/60 left-leg stimuli
located, 3 flagged weak, M-wave fit R² = 0.98, plateau ≈3.3 mV.

**Still open, not addressed:** on that trial the left M-wave trough
lands at ~18.5 ms, close to the 20 ms edge of `computeAmplitudes`'
M-wave window, and the 20–25 ms "noise" window rides the M-wave tail
so noise amplitude tracks M amplitude (up to ~1.7 mV). The window
definitions were left alone; revisit them separately.

## Hardware

H-reflex stimulation requires an Arduino Uno running the firmware in
`HreflexStimArduino/`. See
[HreflexStimArduino/README.md](../../HreflexStimArduino/README.md)
for the upload procedure, wiring diagram, and pre-experiment
checklist.

## See Also

[EXPERIMENT_SETUP.md](../../EXPERIMENT_SETUP.md).
