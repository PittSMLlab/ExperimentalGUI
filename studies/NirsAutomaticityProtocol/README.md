# NirsAutomaticityProtocol

fNIRS-based study of gait automaticity during treadmill walking with
concurrent H-reflex stimulation. This was the primary thesis study
for Shuqi Liu.

## Status

**Completed.** Data collection and processing are finished.

## Experimenters

| Role | Name |
|---|---|
| Lead | Shuqi Liu |

## Paradigm

Participants complete treadmill walking trials at varying speeds while
prefrontal cortex oxygenation is recorded with an fNIRS headband and
H-reflex responses are elicited via Arduino-triggered Digitimer DS8R
stimulators.

**Instrumentation:** Bertec split-belt treadmill, Vicon motion
capture, Artenis fNIRS headband, Arduino Uno + Digitimer DS8R
stimulators.

## Key Scripts

| Script | Purpose |
|---|---|
| `NirsAutomaticityStudyTMProtocol.m` | Main protocol runner |
| `transferDataAndSaveC3D_AutoStudy.m` | Data archival |

## See Also

[EXPERIMENT_SETUP.md](../../EXPERIMENT_SETUP.md),
[HreflexStimArduino/README.md](../../HreflexStimArduino/README.md).
