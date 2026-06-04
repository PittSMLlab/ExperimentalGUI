# BrainWalk

Multi-year longitudinal study of gait automaticity and cognitive
function in older adults with and without mild cognitive impairment
(MCI).

## Status

**Active — longitudinal.** Participants return for visits one year
apart. All procedures must be identical across visits and across all
participants.

> **Do not make functional changes** to `BrainWalkProtocol.m` or to
> the controllers it calls: `OGNBackTask`, `NirsAutomaticityAssessment`,
> `controlSpeedWithSteps_edit1_AudioCountDown`, `HreflexOGWithAudio`.
> Style/formatting edits are acceptable; logic changes are not.

## Experimenters

| Role | Name |
|---|---|
| Lead | Shuqi Liu |
| Lead | Jiwon Choi |

## Paradigm

Participants complete split-belt treadmill walking trials interleaved
with overground N-back cognitive dual-task trials. Prefrontal cortex
oxygenation is measured with a functional near-infrared spectroscopy
(fNIRS) headband. N-back responses are collected via Wii remote.

**Instrumentation:** Bertec split-belt treadmill, Vicon motion
capture, Artenis fNIRS headband, Wii remote.

## Key Scripts

| Script | Purpose |
|---|---|
| `BrainWalkProtocol.m` | Main protocol runner — do not modify |
| `GenerateNBackCondOrders.m` | Generate condition orderings for N-back blocks |
| `GenerateNBackSequence.m` | Generate stimulus sequences for N-back task |
| `transferDataAndSaveC3D_BrainWalk.m` | Archive data and save C3D files |

## See Also

[EXPERIMENT_SETUP.md](../../EXPERIMENT_SETUP.md) — controller
reference and hardware setup.
