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

- Speed ratio: slow = 0.7 × fast belt speed (abrupt split, no ramp).
  This ratio was changed from 0.5 after participant SABH16 (July 2024).
- Overground baseline trials: `HreflexOGWithAudio` (GUI menu slot 16).
  The speed feedback range must be adjusted manually between
  participants based on comfortable overground walking speed.
- Calibration trials: `NirsHreflexOpenLoopWithAudio` (slot 14).

## Key Scripts

| Script | Purpose |
|---|---|
| `RunProtocol_SpinalAdaptBouts.m` | Main protocol runner |
| `generateProfiles_SpinalAdaptBouts.m` | Speed profile generator |
| `runWalkingCalibrations.m` | Pre-experiment stimulus calibration |
| `transferData_SpinalAdaptBouts.m` | Data transfer and archival |

## Hardware

H-reflex stimulation requires an Arduino Uno running the firmware in
`HreflexStimArduino/`. See
[HreflexStimArduino/README.md](../../HreflexStimArduino/README.md)
for the upload procedure, wiring diagram, and pre-experiment
checklist.

## See Also

[EXPERIMENT_SETUP.md](../../EXPERIMENT_SETUP.md).
