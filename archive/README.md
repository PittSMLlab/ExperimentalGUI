# Archive — AdaptationGUI Historical Variants

These files are historical snapshots and experimental branches of
`AdaptationGUI.m` that have been superseded by the current production
version in the repository root. None are called or referenced by any
active code. They are kept for reference only.

## Files

| File | Approximate date | Purpose |
|---|---|---|
| `AdaptationGUI_selfControl.m/.fig` | ~2015 | Self-paced speed experiment variant |
| `AdaptationGUI_Backup9_13_2019.m` | Sep 2019 | Snapshot before audio feedback was added |
| `AdaptationGUI_BackUp_PreQuarantine_03_10_2020.m` | Mar 2020 | Snapshot just before COVID lab shutdown |
| `AdaptationGUI_EMGWorksChanges.m` | ~2020–2021 | Experimental EMGWorks serial-comms branch |
| `AdaptationGUI_06222022WorkingCopyUsingEMGWorks.m` | Jun 2022 | Working copy with refined Nexus + EMGWorks dialogs |

---

## Variant Details

### `AdaptationGUI_selfControl` (~2015)

The oldest variant. A complete standalone MATLAB GUIDE GUI (with its own
`OpeningFcn`/`OutputFcn` and companion `.fig` file) built for self-paced
speed experiments.

Key differences from current `AdaptationGUI.m`:
- Hardware control via WScript.Shell and the Java Robot API — hardcoded
  window titles such as `"EMGworks 4.0.13"` — rather than serial ports
- Vicon Nexus trigger via COM1 serial; EMGWorks via XServer API calls
- Only 8 Execute button cases (vs. 16+ in the current version)
- No audio feedback system (no `RightClick.mp3`, `LeftClick.mp3`,
  `FastBeep.mp3`)
- No perception study, NIRS, or N-Back support

---

### `AdaptationGUI_Backup9_13_2019` (Sep 2019)

A dated backup snapshot taken before the audio-feedback system was
introduced.

Key differences from current `AdaptationGUI.m`:
- No audio files loaded in `OpeningFcn` — no `audioplayer` objects for
  click/beep cues
- No Marcela or Shuqi audio features
- 20 Execute cases
- Serial-port-based Nexus and EMGWorks control (pre-confirmation-dialog)

---

### `AdaptationGUI_BackUp_PreQuarantine_03_10_2020` (Mar 2020)

The state of the GUI just before the lab shut down for COVID-19 in March
2020.

Key differences from current `AdaptationGUI.m`:
- Marcela's audio feedback features present (`RightClick`, `LeftClick`,
  `FastBeep` `audioplayer` objects initialized in `OpeningFcn`)
- No Shuqi countdown features (`numAudioCountDown`, `isCalibration`
  globals were added in January 2022)
- 23 Execute cases
- No NIRS, perception study, or OG H-reflex support

---

### `AdaptationGUI_EMGWorksChanges` (~2020–2021)

An experimental branch focused on refining EMGWorks serial communication.
Nearly identical to the `_PreQuarantine_03_10_2020` backup; the filename
suggests it was a working branch rather than a point-in-time snapshot.

Key differences from current `AdaptationGUI.m`:
- Same feature set as the 2020 backup (Marcela audio, 23 Execute cases)
- EMGWorks integration is present but without the confirmation dialogs
  (`questdlg`) added in the 2022 working copy
- No `.fig` file — relies on the shared `AdaptationGUI.fig` or was run
  from a copy of the root `.fig`

---

### `AdaptationGUI_06222022WorkingCopyUsingEMGWorks` (Jun 2022)

A working copy snapshot taken on 22 June 2022, capturing the state of
the GUI after the Nexus + EMGWorks confirmation-dialog workflow was
stabilized.

Key differences from current `AdaptationGUI.m`:
- Refined Nexus (COM1) and EMGWorks (COM14) confirmation dialogs:
  `questdlg('Please confirm that EMGworks is in trigger mode')` and
  `questdlg('Please confirm that Nexus & EMGworks has started capture')`
- 19 Execute cases — a smaller set than the current version
- `feedbackFlag` read from the UI (`handles.feedbackBox.Value`)
- `RFBClicker` / `LFBClicker` globals for Carly/Marcela feedback clickers
- Predates Shuqi's `numAudioCountDown` and `isCalibration` globals
  (added later in 2022)
- No NIRS H-reflex open-loop (case 14), timed perceptual trials
  (case 15), or OG H-reflex with audio feedback (case 16)
