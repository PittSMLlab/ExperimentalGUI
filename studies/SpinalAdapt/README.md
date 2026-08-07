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
= fast × 0.7 (changed from 0.5 after participant SABH16, July 2024).

**Initial new-protocol design (subject to revision):**

| Condition | # | Strides (excl. rest pads) |
|---|---|---|
| TM Baseline Fast / Slow (tied) | 2 | 100 each |
| OG Baseline Fast / Slow (optional, skipped for SABH) | 2 | 100 each |
| Control Bouts (tied, 10 bouts × 10 ramp + 10 SS) | 1 | 200 |
| Split Bouts (10 bouts × 10 ramp + 10 SS per trial) | 8 | 200 each |
| Control Bouts repeat | 1 | 200 |
| Post-Adapt (tied fast, 100 strides per trial) | 2 | 100 each |

Total (without OG): 200 + 200 + 8×200 + 200 + 200 = **2,400 strides**.
With OG baselines: 2,600 strides. Profile files: `CtrlBouts.mat`,
`SplitBouts.mat`, `PostAdapt.mat`.

- Overground baseline trials: `HreflexOGWithAudio` (GUI menu slot 16).
  The speed feedback range must be adjusted manually between
  participants based on comfortable overground walking speed.
- Calibration trials: `NirsHreflexArduinoOpenLoopWithAudio` (slot 14).
- Bout timing and cues (`NirsHreflexArduinoOpenLoopWithAudio`, fixed
  2026-07): the inter-bout rest is a fixed ~10 s SILENT window
  (`restSilentSec`, belts stopped, timer padded by the rest cue's own
  length so it excludes the cue), applied to every run of this
  controller including fNIRS/H-reflex sessions. Every bout start
  (tied ramp = `AccRamp`, split ramp = `DccRamp2Split`) announces "TM
  will start now" exactly once; bout 1 is announced by the pre-loop
  3-2-1 countdown, and the ramp-event cue is suppressed only for that
  first bout to avoid a duplicate. The "which bout to start from"
  dialog range and default are derived from the loaded profile's bout
  count (5 for familiarization, 10 for Control/Split), not
  hard-coded.
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
4-5, and the M-wave monitor MVP below.

## Study History

| Archive folder | Description |
|---|---|
| `History-PilotStudy1/` | Original pilot — simpler tied/split structure; no fNIRS bout design. Scripts: `SpinalAdaptProtocol.m`, `GenerateProfileSpinalStudy.m`. |
| `History-PilotStudy2/` | Bout-based protocol — participants SABH01 through at least SABH16+ (July 2023–2025). Speed ratio changed from 0.5 to 0.7 after SABH16 (July 2024); ramp-to-split option added then later removed. Scripts reformatted to CLAUDE.md style (June 2026). |

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

## H-Reflex M-Wave Monitor (In Development)

A near-real-time M-wave monitor is being built to help the
experimenter hold each leg's H-reflex M-wave within ~±10% of its
calibration baseline during a session by watching a live snippet plot
and adjusting DS8R current accordingly. It is designed to run in a
**separate MATLAB instance** (its own Vicon DataStream client, device
data only) so it cannot perturb `NirsHreflexArduinoOpenLoopWithAudio`'s
control-loop timing; it never opens the Arduino serial port and never
writes to the controller's `datlog`.

**Status: Phase 0 (device probe) + Phase 1 (single-leg MVP) complete,
validated against a synthetic fixture; not yet run against a real
calibration C3D or live data (see Known Gaps below).**

| Script | Phase | Purpose |
|---|---|---|
| `probeViconDataStreamDevices.m` | 0 | Read-only DataStream device/output enumeration — run this first in the lab to confirm EMG + `Stimulator_Trigger_Sync_*` are exposed live (not just in the C3D) before relying on the live source in a later phase. |
| `detectStimArtifactOnline.m` | 1 | Causal, streaming re-implementation of `Hreflex.extractStimArtifactIndsFromTrigger`'s onset/artifact-peak detection. |
| `stepHreflexMonitor.m` | 1 | Per-chunk pipeline step: buffers EMG, calls the detector, and — once each stim's full snippet window has arrived — recomputes M-/H-wave/noise amplitudes over the *entire accumulated snippet set* via `Hreflex.computeAmplitudes` (required for exact parity with the offline batch statistic; see its header comment). |
| `hreflexSourceReplayC3D.m` | 1 | Loads a prior H-reflex trial C3D (via BTK) for replay validation. |
| `mapHreflexAnalogChannels.m` | 1 | BTK-independent channel-mapping logic used by the loader above: EMG channels are `EMG<sensorNumber>` fields in the C3D — the muscle assignment is session-specific placement metadata, not derivable from the file, so this mirrors `generateHreflexRecruitmentCurves`'s own sensor-order mapping (`emgSensorMap`, same default). Factored out so this mapping — the exact logic an earlier version of this tool got wrong — is unit-testable without BTK. |
| `promptHreflexMuscle.m` | 1 | Shared "which muscle is the H-reflex channel" prompt (SOL default, MG/LG allowed) — used by the replay source now and, in a later phase, by the live source too. |
| `generateSyntheticHreflexTrial.m` | 1 (test) | Hardware/BTK-free synthetic trial fixture for CI. |
| `runHreflexMwaveMonitor.m` | 1 | Entry point: replays a trial through the pipeline, updating one persistent per-leg figure (snippet + M-wave highlighted) in place per stim. Single-leg only for now (`leg` argument); a later phase removes it and monitors both legs at once. |

Validate with `runtests('testDetectStimArtifactOnline')`,
`runtests('testHreflexMwaveMonitorReplay')`, and
`runtests('testMapHreflexAnalogChannels')`. The first two include an
online-vs-offline parity check against the real `+Hreflex` batch
functions, including a dedicated test that hand-crafts a signal to
confirm `Hreflex.computeAmplitudes`' outlier-duration correction
actually engages (proving the growing-set recompute is necessary, not
just equivalent by luck to a simpler per-stimulus approach). The
`testHreflexMwaveMonitorReplay` suite also has a lab-only real-C3D
replay test, skipped unless the `HREFLEX_REPLAY_TEST_C3D` environment
variable points at a prior calibration trial C3D.

**Known gaps before this is lab-ready:**
- `hreflexSourceReplayC3D.m`'s BTK read (`btkReadAcquisition`,
  `btkGetAnalogs`) has zero execution coverage in this environment (no
  BTK Windows MEX binary available here) and its real-C3D path needs
  to be run against a real prior calibration trial C3D (via
  `HREFLEX_REPLAY_TEST_C3D`) before Phase 1 can be considered done; its
  post-BTK channel-mapping logic is unit-tested BTK-free via
  `mapHreflexAnalogChannels.m`.
- `promptHreflexMuscle.m` and `hreflexSourceReplayC3D.m`'s interactive
  dialogs are untested (every automated test passes `muscle` explicitly
  to bypass them).
- The M-wave marker plotted in `runHreflexMwaveMonitor.m` shows the raw
  in-window max/min, which will visually disagree with the displayed
  number for a stimulus `Hreflex.computeAmplitudes` outlier-corrects
  (see that file's comment).
- `stepHreflexMonitor.m`'s growing-set recompute is O(numStimSoFar) per
  new stimulus by design (see its header); the "bounded per-update
  work" isolation requirement has not yet been measured against real
  session-length stimulus counts in the lab.

Later phases add the ±10% tolerance bounds (prompt-entered per-leg
baseline, since no baseline is currently persisted by
`generateHreflexRecruitmentCurves.m`), an out-of-tolerance indicator
and last-N counter, a second leg, the live Vicon DataStream source,
and a lab dry-run alongside the control instance.

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
| `extractStimArtifactIndsFromTrigger` | Locate pulse times from trigger channel |
| `plotStimArtifactPeaks` | Plot detected peaks for QC |
| `extractSnippets` | Extract per-pulse EMG windows |
| `plotSnippets` | Plot per-pulse snippets for QC |
| `extractBackgroundEMG` | Compute pre-stimulus background level |
| `computeAmplitudes` | Peak-to-peak M- and H-wave amplitudes |
| `fitCal` | Fit recruitment curves to amplitude vs. current |
| `plotNoiseHistogram` | Plot background EMG noise distribution |
| `plotCal` | Plot fitted recruitment curves |

## Hardware

H-reflex stimulation requires an Arduino Uno running the firmware in
`HreflexStimArduino/`. See
[HreflexStimArduino/README.md](../../HreflexStimArduino/README.md)
for the upload procedure, wiring diagram, and pre-experiment
checklist.

## See Also

[EXPERIMENT_SETUP.md](../../EXPERIMENT_SETUP.md).
