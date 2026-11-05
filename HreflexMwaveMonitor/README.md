# H-Reflex M-Wave Monitor

A near-real-time tool that shows the experimenter the most recent
H-reflex M-wave amplitude per leg during a walking H-reflex session,
so DS8R stimulation current can be adjusted to hold the M-wave within
±10% of its calibration baseline. Built for **SpinalAdapt** (the only
study currently using H-reflex measurements), but deliberately kept
study-agnostic — living here, outside `studies/SpinalAdapt/`, rather
than inside it — since other studies may adopt H-reflex measurement in
the future.

It is designed to run in a **separate MATLAB instance** from the
control/stimulation instance (its own Vicon DataStream client, device
data only), so it cannot perturb `NirsHreflexArduinoOpenLoopWithAudio`'s
control-loop timing; it never opens the Arduino serial port and never
writes to the controller's `datlog`. See the H-reflex timing contract
in the repository root `CLAUDE.md` for the control-loop side this tool
must not interfere with.

## Namespace

All monitor logic lives in the `+hreflexMonitor` package
(`HreflexMwaveMonitor/+hreflexMonitor/`), called as
`hreflexMonitor.functionName(...)` — e.g.
`hreflexMonitor.runHreflexMwaveMonitor(...)`. This mirrors the
repository root's existing `+utils` package convention
(`utils.transferData`, etc.) and keeps the tool's public surface
grouped and collision-free as it grows. Test files are plain
(non-namespaced) siblings in this folder, calling into the package
with the qualified name.

**Put `HreflexMwaveMonitor/` (not `+hreflexMonitor/` itself) on the
MATLAB path** — same rule as every other folder in this repository.
This repository does not ship a `startup.m` or persisted `pathdef.m`,
so path setup is manual (e.g. MATLAB's "Set Path > Add with
Subfolders" from the repo root, run once and saved); confirm
`HreflexMwaveMonitor` is included wherever this tool will run.

## File Table

| File | Phase | Purpose |
|---|---|---|
| `+hreflexMonitor/probeViconDataStreamDevices.m` | 0 | Read-only DataStream device/output/component enumeration, with per-channel subsample counts and signal statistics — run this first in the lab (Nexus in Live mode, `HreflexEMGDataCollection` profile selected, firing stimuli) to confirm EMG + `Stimulator_Trigger_Sync_*` are exposed live (not just in the C3D) before relying on a live source in a later phase. |
| `+hreflexMonitor/detectStimArtifactOnline.m` | 1 | Causal, streaming re-implementation of `Hreflex.extractStimArtifactIndsFromTrigger`'s onset/artifact-peak detection (largest absolute deflection in the window; see Artifact Localization Rule below). |
| `+hreflexMonitor/stepHreflexMonitor.m` | 1-2 | Per-chunk pipeline step: buffers EMG, calls the detector, and — once each stim's full snippet window has arrived — recomputes M-/H-wave/noise amplitudes over the *entire accumulated snippet set* via `Hreflex.computeAmplitudes` (required for exact parity with the offline batch statistic), and re-derives which peak/trough sample indices that computation used (`state.mWaveInds`) so a caller's marker matches the displayed, possibly outlier-corrected, amplitude. |
| `+hreflexMonitor/hreflexSourceReplayC3D.m` | 1 | Loads a prior H-reflex trial C3D (via BTK) for replay validation. |
| `+hreflexMonitor/mapHreflexAnalogChannels.m` | 1 | BTK-independent channel-mapping logic used by the loader above: EMG channels are named by sensor number in the C3D. The real field naming (confirmed on SABH02 `Trial03.c3d`) has TWO fields per sensor, `Sensor_<n>_EMG<n>` and `Sensor_<n>_IM_EMG<n>`; for every sensor checked in that file the plain `EMG<n>` field was completely flat (`std(Sensor_7_EMG7) = 0`) while `IM_EMG<n>` carried the real signal (`std(Sensor_7_IM_EMG7) ≈ 6e-5 V`) — the plain field appears to be an unpopulated placeholder in this export configuration, not real EMG. Both this mapping and `GenerateHreflexRecruitmentCurves.m` resolve a sensor's channel via the same `strfind(...,'EMG')` + trailing-digit parse and, because `IM_EMG<n>` iterates after `EMG<n>` in this file's field order, both end up selecting the live `IM_EMG<n>` field here (`relData(:,idxList) = relDataTemp`'s last-write-wins behavior in the offline script — inferred by reading that code, not executed, since it is external/out-of-repo and not something to run changes against). This has only been confirmed for this one file; it is not proven as a structural invariant across all SpinalAdapt sessions — see Real-Data Validation below. — the muscle assignment is session-specific placement metadata, not derivable from the file, so this mirrors `GenerateHreflexRecruitmentCurves`'s own sensor-order mapping (`emgSensorMap`, same default). Factored out so this mapping is unit-testable without BTK. |
| `+hreflexMonitor/promptHreflexMuscle.m` | 1 | Shared "which muscle is the H-reflex channel" prompt (SOL default, MG/LG allowed) — used by the replay source now and, in a later phase, by the live source too. |
| `+hreflexMonitor/promptHreflexBaseline.m` | 2 | Prompts for a leg's baseline M-wave amplitude (mV), read off that leg's walking-calibration recruitment curve, since no baseline is currently persisted by `GenerateHreflexRecruitmentCurves.m` for this tool to load automatically (see Flagged Upstream Item below). |
| `+hreflexMonitor/computeMwaveTolerance.m` | 2 | Pure ±10% (default) tolerance-bound arithmetic around a baseline M-wave value. |
| `+hreflexMonitor/generateSyntheticHreflexTrial.m` | 1 (test) | Hardware/BTK-free synthetic trial fixture for CI. |
| `+hreflexMonitor/runHreflexMwaveMonitor.m` | 1-3 | Replay entry point: runs a recorded trial through the pipeline and the shared figure, one leg per call. |
| `+hreflexMonitor/runHreflexMwaveMonitorLive.m` | 3 | Live entry point, one leg per MATLAB instance. Reads the stream, updates the figure, shows lost frames and delay, and saves its own log file when stopped. |
| `+hreflexMonitor/hreflexSourceDataStream.m` | 3 | Live Vicon source: device-data-only `ServerPush` client that reads one leg's TA, H-muscle, and trigger channels per frame. |
| `+hreflexMonitor/assembleLiveChunk.m` | 3 | Turns a live frame into a contiguous chunk: NaN-pads lost frames and repeats the trigger to the EMG length. No SDK calls, so it is unit-tested. |
| `+hreflexMonitor/trimMonitorBuffers.m` | 3 | Drops raw samples no pending stimulus needs, so per-frame buffer copies stay small on long live runs. |
| `+hreflexMonitor/computeMwaveAlert.m` | 3 | Consecutive out-of-window rule (3 by default), with HIGH/LOW/MIXED direction. |
| `+hreflexMonitor/createMonitorFigure.m`, `updateMonitorFigure.m` | 3 | Figure shared by replay and live: latest snippet with M-wave markers (top); M- and H-wave trends, baseline and ±10% bounds, alert, and status line (bottom). |
| `testDetectStimArtifactOnline.m` | 1 (test) | Unit + online-vs-offline parity tests for the causal detector, including the negative-dominant artifact regression fixture (see Artifact Localization Rule below). |
| `testHreflexMwaveMonitorReplay.m` | 1-2 (test) | Integration parity between the online pipeline and the offline `+Hreflex` batch pipeline, including the marker-index fix and a lab-only real-C3D replay test. |
| `testMapHreflexAnalogChannels.m` | 1 (test) | BTK-free unit tests for the channel-mapping logic. |
| `testComputeMwaveTolerance.m` | 2 (test) | Unit tests for the tolerance-bound arithmetic. |
| `testAssembleLiveChunk.m` | 3 (test) | Vicon-free tests for lost-frame padding, trigger repetition, repeats, and restarts. |
| `testComputeMwaveAlert.m` | 3 (test) | Unit tests for the consecutive out-of-window rule. |

## Real-Data Validation (2026-08-14)

Phase 1's real-data gap (previously open — no BTK-for-Windows binary on
the development machine) is now closed. Using BTK for Windows at
`Z:\Nathan\btk` (**a local testing copy — not confirmed to be what the
lab PC has installed**; re-verify BTK's location/version there) and a
copy of pilot participant SABH02's `Trial03.c3d` (real SpinalAdapt
walking H-reflex calibration data, from
`Z:\SpinalAdaptStudy\Data\SABH02\Vicon\`):

- **Exact stim-count parity, right leg**: the online causal detector
  (`detectStimArtifactOnline`) and the offline whole-trial helper
  (`Hreflex.extractStimArtifactIndsFromTrigger`) both find **60**
  stimuli — a direct, non-synthetic confirmation of the parity
  guarantee `testDetectStimArtifactOnline`/`testHreflexMwaveMonitorReplay`
  establish on synthetic data.
- **M-wave magnitudes match production output**: computed M-wave
  amplitudes ranged ~0.02–3.5 mV (mean 1.66, std 1.45) across the
  trial's ascending-current stimuli, closely tracking the real
  recruitment-curve plateau (~3.4–3.5 mV) in
  `Z:\SpinalAdaptStudy\Data\SABH02\Vicon\HreflexCalFigs\SABH02_HreflexRecruitmentCurve_Trial03_RightLeg.png`
  (and the corresponding left-leg figure) — confirming the channel
  mapping resolves the correct, live physiological EMG signal
  (`IM_EMG<n>`), not the flat placeholder (`EMG<n>`, `std = 0`) or
  some other mismatched channel that happens not to error. Verify
  `std(...) > 0` on the resolved H-muscle channel for a new
  participant/export before trusting this same field selection.
- **Growing-set recompute cost, real stimulus counts**: at N=60 stimuli
  (chunk size 10), per-stimulus recompute time was median 5.3 ms, p95
  29.8 ms, max 754 ms (one-off, consistent with first-call JIT
  warm-up). The recompute is O(numStimSoFar) by design (see
  `stepHreflexMonitor.m`). SpinalAdapt's profiles stimulate 72 times per
  leg in a calibration trial and 100 in a bout trial, close to the
  tested N. Still worth a live timing check (see Running Live below).
- The gated real-C3D integration test now passes:
  `runtests('testHreflexMwaveMonitorReplay')` with
  `HREFLEX_REPLAY_TEST_C3D` pointed at a real calibration C3D exercises
  this exact comparison (stim count + amplitude parity, `AbsTol` 1e-6)
  end to end.
- The full driver (`runHreflexMwaveMonitor`, Phase 1-3) was also
  smoke-tested against this real trial (right leg, explicit baseline to
  skip the interactive prompt) and produces the expected two-axes
  figure: a clean sigmoid-shaped M-wave-vs-stimulus trend matching the
  real recruitment curve's shape, correct peak/trough marker placement,
  and a working tolerance indicator/counter.

## Artifact Localization Rule (2026-08-26)

`Hreflex.extractStimArtifactIndsFromTrigger`'s private
`findStimArtifactInds` and this tool's causal mirror,
`detectStimArtifactOnline`, both take the artifact as the sample of
largest **absolute** deflection from the search window median. The
stimulation artifact is commonly negative-dominant — its initial
deflection is downward, with a smaller positive rebound ~1.5 ms later —
so the previous signed-positive `findpeaks` search with a
`minArtifactPeak` height gate either locked onto the rebound or, when
the artifact was small, found nothing and fell back to the raw maximum
over the whole 200 ms window. Absolute deflection is polarity agnostic
and needs no threshold, because the window is already anchored to a
known trigger pulse; `findpeaks` (and its
`findpeaks:largeMinPeakHeight` warning, previously suppressed here) is
gone from both implementations.

Measured on SABH02 `Trial03.c3d`, the rule change moves every one of
the 120 stimuli 1.5 ms earlier (max 2.0 ms) and shifts mean M-wave
amplitude by less than 0.6%. `minArtifactPeak` survives only in the
offline helper, repurposed from a detection gate into a quality
control floor reported through its new second output,
`isWeakArtifact`; `detectStimArtifactOnline` no longer takes it.
`testDetectStimArtifactOnline` pins the shared rule with a
negative-dominant fixture whose artifact sits below the old 1 mV gate.

## Running Live

Run one instance per leg, each in its **own MATLAB**, with Nexus in Live
mode and the `HreflexEMGDataCollection` profile selected. Arguments are
leg, proximal TA sensor, and H-muscle sensor:

```matlab
hreflexMonitor.runHreflexMwaveMonitorLive('R', 1, 7);
hreflexMonitor.runHreflexMwaveMonitorLive('L', 8, 13);
```

Sensor numbers are session-specific. It prompts for the baseline M-wave
unless `'baselineMwaveMv'` is passed. Close the figure or press Ctrl+C to
stop; either way it disconnects, prints a summary, and saves
`HreflexMonitorLive_<leg>_<timestamp>.mat` (variable `monitorLog`).

- **Alert:** the figure turns pale red and the title reports the
  direction when the M-wave is out of window for 3 stimuli in a row.
- **Invalid stimuli:** a stimulus touching a lost frame is counted, never
  plotted, and neither adds to nor resets the alert count. A pulse lost
  entirely inside a gap cannot be seen, so also compare lost frames in the
  summary with the controller's stimulus count.
- **Status line:** invalid stimuli, lost frames, and seconds behind the
  stream. A growing "Behind" value means reads are not keeping up.

### Read-Speed Tests (2026-11-05, Lab PC, Seated, No Controller)

Each subsample takes one SDK call of about 134 µs, and this SDK has no bulk
read. All runs below read each listed leg's TA, H-muscle, and trigger.

| Setup | Median read | Frames lost |
|---|---|---|
| Both legs, one client, `ClientPull`, buffer 1 | 13.8 ms | 37% |
| One leg, `ClientPull`, buffers 1 / 10 / 100 | ~6 ms | 4.6% / 2.9% / 8.7% |
| One leg, `ClientPullPreFetch`, buffer 100 | 6.1 ms | 4.8% |
| One leg, `ServerPush`, buffer 100 (30 s) | 6.0 ms | 0 |
| Two MATLABs at once, `ServerPush`, buffer 100 (60 s) | 7.4 and 6.0 ms | 0 and 0 |

The busier two-instance run averaged 8.7 ms per 10 ms frame, so the margin
is thin. These tests did not include the controller, the figure, amplitude
calculation, or real stimuli.

The live trigger device is `Stimulator Trigger Signal` / `Electric
Potential` / `Right Stimulator` or `Left  Stimulator` (two spaces), while
`testing01.c3d` labels the same channels `Stimulator Trigger Sync.<...>`.
Offline code keeps the C3D names. The trigger streams at 1 kHz and is
stored at 2 kHz in the C3D by repeating samples.

## Known Gaps Before This Is Lab-Ready

- **The live path has not been run.** `runHreflexMwaveMonitorLive.m` and
  `hreflexSourceDataStream.m` were written without MATLAB or Vicon access.
  Run the Validate With suites, then a live test, starting without the
  controller.
- **Not yet checked with real stimuli:** live trigger pulses reaching the
  2.5 V threshold, live vs. offline amplitude agreement, and the delay and
  lost-frame figures alongside the controller. Confirm the controller's
  stimulation timing is unchanged with
  `diagnostics/auditHreflexStimTiming.m`.
- **Trigger timing differs slightly from offline:** live onsets are
  quantized to 10 ms frames. This only anchors the ±100 ms artifact search,
  but live amplitudes must be compared against the offline pipeline on the
  same trial.
- `promptHreflexMuscle.m` and `promptHreflexBaseline.m`'s interactive
  dialogs (`listdlg`, `inputdlg`) are untested interactively (every
  automated test passes `muscle`/`baselineMwaveMv` explicitly to
  bypass them).

## Validate With

```matlab
runtests('testDetectStimArtifactOnline')
runtests('testMapHreflexAnalogChannels')
runtests('testComputeMwaveTolerance')
runtests('testComputeMwaveAlert')
runtests('testAssembleLiveChunk')
runtests('testHreflexMwaveMonitorReplay')
```

The last suite's `testReplayAgainstRealCalibrationC3D` is lab-only,
skipped (not failed) unless the `HREFLEX_REPLAY_TEST_C3D` environment
variable points at a real calibration trial C3D — see Real-Data
Validation above for a worked example.

## Flagged Upstream Item (Not Built Here)

`GenerateHreflexRecruitmentCurves.m` (labTools) does not currently
persist a per-leg baseline M-wave value anywhere a downstream tool
could load automatically — `promptHreflexBaseline.m` above asks the
experimenter to type it in instead. Having that script (or a small new
`+Hreflex` function) persist an `<id>HreflexBaseline.mat` upstream in
labTools would let this tool load the baseline instead of prompting;
this is a separate, coordinated labTools change, not built as part of
this tool.

## See Also

[Repository root `CLAUDE.md`](../CLAUDE.md) (H-reflex timing contract,
active studies), [`studies/SpinalAdapt/README.md`](../studies/SpinalAdapt/README.md)
(the study this tool was built for), `labTools/fun/+Hreflex/` (the
offline batch pipeline this tool mirrors).
