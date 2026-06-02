# Experiment Setup Guide

This document is a reference for lab members running or creating experiments
with ExperimentalGUI. It covers the active study protocols, the controller
library, step-by-step instructions for building a new protocol, and expected
hardware and software configuration.

For coding conventions and contribution guidelines, see
[CONTRIBUTING.md](CONTRIBUTING.md). For a project overview and software
requirements, see [README.md](README.md).

---

## Table of Contents

1. [Active Experimental Studies](#active-experimental-studies)
2. [Controller Reference](#controller-reference)
3. [Creating a New Experimental Protocol](#creating-a-new-experimental-protocol)
4. [Hardware Setup: Bertec Treadmill](#hardware-setup-bertec-treadmill)
5. [Hardware Setup: Vicon Nexus 2.12](#hardware-setup-vicon-nexus-212)
6. [Other Instrumentation](#other-instrumentation)

---

## Active Experimental Studies

| Study Folder | Status | Study Type | Primary Protocol Script |
|---|---|---|---|
| `BrainWalk/` | **Active — longitudinal** | Cognitive dual-task walking (N-back) | `BrainWalkProtocol.m` |
| `C3/` | **Active** (~3 participants remaining) | Stroke rehabilitation split-belt | `RunProtocol_C3.m`, `RunProtocol_C3_Session2Bouts.m` |
| `NirsAutomaticityProtocol/` | Unknown — verify before any functional change | fNIRS + H-reflex + split-belt treadmill | `NirsAutomaticityStudyTMProtocol.m` |
| `Perceptual Adaptation/` | Unknown — verify before any functional change | Weber fraction perception during walking | `GeneratePartialProfile.m` |
| `SpinalAdapt/` | Unknown — verify before any functional change | H-reflex spinal adaptation to split-belt | `RunProtocol_SpinalAdaptBouts.m` |
| `Weber Perception/` | Unknown — verify before any functional change | Perceptual discrimination thresholds | `GeneratePartialProfile.m` |

### BrainWalk — Stability Notice

BrainWalk is a multi-year longitudinal study. Participants return for
visits one year apart, and all procedures must be identical across
visits and across all participants. **Do not make functional changes**
to `BrainWalkProtocol.m` or to the controllers it invokes
(`OGNBackTask`, `NirsAutomaticityAssessment`). Formatting changes are
acceptable; logic changes are not.

---

## Controller Reference

The `controllers/` folder contains ~44 `.m` files. Most are inactive
backups identifiable by suffixes such as `_Backup`, `_bak`,
`_edit1_old`, or a date (e.g., `_01082016`, `_backup3-06-24`). The
table below lists the **active controllers** that `AdaptationGUI`
actually calls.

**Recommended starting point for new treadmill protocols:**
`controlSpeedWithSteps_selfSelect.m`.

GUI menu slot numbers correspond to `case` labels in
`Execute_button_Callback` (AdaptationGUI.m lines 374–544).

| Menu Slot | Controller | Description | Used By |
|---|---|---|---|
| 2–4 | `controlSpeedWithSteps_selfSelect` | Primary split-belt treadmill controller. Stride-synchronized belt updates; establishes self-selected speed baseline. Slot 2 = signed, 3 = unsigned, 4 = closed-loop. | General treadmill adaptation protocols |
| 7 | `controlSpeedWithSteps_selfSelect_OneClick` | One-click-start variant; trial ends on single response. Used for stride-length based perceptual trials. | Perceptual Adaptation (stride-based) |
| 9 | `controlSpeedWithSteps_PercAdap` | Perceptual adaptation variant; trial ends on click response, task length is time-based. | Perceptual Adaptation |
| 11 | `controlSpeedWithSteps_edit1_AudioCountDown` | Split-belt controller with audio countdown cue at trial start. | BrainWalk (TM trials), C3 (TM trials) |
| 15 | `controlSpeedWithSteps_WeberPerceptionFaster` | Weber perception variant; faster inter-stride update for threshold estimation. | Weber Perception |
| 8 | `HreflexOGWithAudio` | Overground (no belt control) with H-reflex triggers and audio speed feedback. | BrainWalk (OG baseline), C3 (OG baseline) |
| 16 | `HreflexOGWithAudio` | Same controller, second menu entry; used for H-reflex OG trials with audio in SpinalAdapt. | SpinalAdapt |
| 14 | `NirsHreflexOpenLoopWithAudio` | Split-belt controller with fNIRS event markers, H-reflex stimulation, and audio feedback. | NirsAutomaticityProtocol, SpinalAdapt (calibration) |
| 10 | `NirsAutomaticityAssessment` | Overground alphabet dual-task assessment. Records responses and logs events. | BrainWalk, NirsAutomaticityProtocol |
| 13 | `OGNBackTask` | Overground N-back cognitive dual-task; plays audio stimuli and records Wii-remote responses. | BrainWalk |
| 5 | `SelfSelectedSpeed` | Overground controller for self-selected walking speed calibration. | General calibration |
| 6 | `SelfSelectedSpeed_NumPad` | NumPad-input variant of self-selected speed calibration. | General calibration |

---

## Creating a New Experimental Protocol

### Overview

A new protocol requires three components:

1. A `generateProfiles_<StudyName>.m` script to generate speed profiles
2. A `RunProtocol_<StudyName>.m` script to sequence trials and call the GUI
3. Optionally, a new controller in `controllers/` if none of the existing
   ones fit the experimental design

### Step-by-Step

**Step 1 — Create a study folder**

```
studies/<StudyName>/
    generateProfiles_<StudyName>.m
    RunProtocol_<StudyName>.m
```

**Step 2 — Write the profile generator**

`generateProfiles_<StudyName>.m` must produce two Nx1 vectors:
- `velL` — left belt speeds in mm/s for each stride
- `velR` — right belt speeds in mm/s for each stride

A `NaN` at position k signals a self-paced stride: the controller holds
or queries the current treadmill speed instead of commanding a preset
value. Profiles are passed directly to the controller as arguments —
there is no file-based loading at runtime.

```matlab
% Example: 50-stride baseline at 800 mm/s, then 100-stride adaptation
% with 2:1 speed ratio, then 50-stride post-adaptation
velL = [repmat(800, 50, 1);  repmat(800, 100, 1);  repmat(800, 50, 1)];
velR = [repmat(800, 50, 1);  repmat(1600, 100, 1); repmat(800, 50, 1)];
```

**Step 3 — Choose a controller**

Consult the [Controller Reference](#controller-reference) table. For a
standard split-belt adaptation paradigm, start with
`controlSpeedWithSteps_selfSelect`. If you need features not present in
any existing controller (e.g., a new peripheral, a novel feedback
signal), copy the closest existing controller, rename it following
camelCase convention, and modify it.

**Step 4 — Add a new controller to the GUI (if needed)**

If you created a new controller, register it in `AdaptationGUI`:

1. Open `AdaptationGUI.fig` in GUIDE and add the controller name to the
   `popupmenu2` string list.
2. In `AdaptationGUI.m`, locate `Execute_button_Callback` and add a
   `case` for the new controller name that calls it with the appropriate
   arguments (follow the pattern of existing cases).

**Step 5 — Write the protocol script**

`RunProtocol_<StudyName>.m` should:
1. Open `AdaptationGUI` and obtain its `handles` struct
2. For each trial block, set `handles.popupmenu1` (profile) and
   `handles.popupmenu2` (controller) to the desired values, then call
   `Execute_button_Callback` (or prompt the experimenter to click Execute)
3. Use `questdlg` calls to pace the experimenter through the session and
   confirm readiness before each trial

See `studies/SpinalAdapt/RunProtocol_SpinalAdaptBouts.m` or
`studies/C3/RunProtocol_C3.m` as reference implementations.

**Step 6 — Test before participant data collection**

Run the protocol with a short dummy profile (e.g., 5 strides) in the
lab with the treadmill at low speed to verify that belt commands,
data logging, and data transfer all work as expected before involving
participants.

---

## Hardware Setup: Bertec Treadmill

### What the Code Provides

- **Communication:** UDP connection initialized once per trial in
  `sendTreadmillPacket` (from labTools).
- **Packet format:** 64 bytes — 1 format byte, 9 int16 values
  (speedR, speedL, speedRR, speedLL, accR, accL, accRR, accLL,
  incline), 1 checksum byte (255 − sum of data bytes), 27 padding bytes.
- **Hard limits enforced by `getPayload`:** speed ±6500 mm/s,
  acceleration ≤ 3000 mm/s². Commands outside these ranges are clipped.

### Bertec Sync Software Settings

> [TODO: Document the expected Bertec Sync software settings here,
> including UDP port configuration, force-plate zeroing procedure,
> and any required startup steps before running an experiment.]

---

## Hardware Setup: Vicon Nexus 2.12

### Marker Set and Capture Settings

> [TODO: Document the marker set used (e.g., Plug-in Gait or custom),
> the expected capture frame rate (e.g., 100 Hz), and the labeling
> template name loaded in Nexus before each session.]

### EMG: Delsys Trigno Wireless System

Surface EMG is recorded using a Delsys Trigno wireless system. Data
are acquired in Nexus 2.12 across two separate, synchronized PCs
(one per leg). Both PCs must be connected to the same Nexus system
before capture begins.

> [TODO: Document the Delsys Trigno channel configuration (sensor
> mapping, muscle assignment) and the dual-PC synchronization
> procedure in Nexus.]

### C3D Output

> [TODO: Document the expected C3D output path convention and any
> naming requirements for compatibility with downstream analysis
> pipelines (e.g., labTools processing scripts).]

---

## Other Instrumentation

### Artenis fNIRS Headband

Used in the BrainWalk study to record prefrontal cortex oxygenation
during cognitive dual-task walking. The headband is synchronized with
the treadmill trial via event markers inserted by
`NirsAutomaticityAssessment` and `OGNBackTask` controllers.

> [TODO: Document headband placement, channel configuration, and
> synchronization procedure with Nexus.]

### Wii Remote

Used in perceptual studies (Perceptual Adaptation, Weber Perception)
for two-alternative forced choice responses. Participants press left or
right button to indicate perceived faster belt.

> [TODO: Document Bluetooth pairing procedure and which MATLAB
> toolbox or driver is required.]

### Arduino H-Reflex Stimulator

Used in SpinalAdapt and NirsAutomaticityProtocol. The Arduino
interface is in `HreflexStimArduino/`. Stimulation timing is triggered
by the `NirsHreflexOpenLoopWithAudio` and `HreflexOGWithAudio`
controllers.

> [TODO: Document the Arduino sketch that must be uploaded, the
> serial port settings, and the calibration procedure for stimulus
> intensity.]
