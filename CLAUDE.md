# CLAUDE.md — ExperimentalGUI Repository Instructions

## Repository Overview
ExperimentalGUI is a MATLAB framework for running real-time split-belt
treadmill experiments that study sensorimotor adaptation and biomechanics.
It interfaces with Vicon motion capture, Bertec treadmills, force plates,
and optionally Arduino-based H-reflex stimulators.

## How to Run Code
No build system. All workflows are MATLAB-based.

**Required MATLAB path additions** (see ReadMe.txt for exact paths):
- `C:\Program Files\Vicon\` — Vicon Nexus SDK
- `C:\Users\Public\Documents\MATLAB\` — shared lab utilities
- `C:\Users\cntctsml\Documents\GitHub\labTools\` — labTools package

**Running an experiment:** type `AdaptationGUI` in the MATLAB Command
Window, or open `AdaptationGUI.m` and press Run. The companion `.fig`
file must remain in the same directory.

**Running a study protocol:** open the relevant script in `studies/`
(e.g., `studies/SpinalAdapt/RunProtocol_SpinalAdaptBouts.m`) and run
it as a MATLAB script. Protocol scripts call `AdaptationGUI` and the
controller functions internally.

**MEX binary:** `mexKbhit.mexw64` (Windows) is a pre-compiled keyboard
polling utility. The C source is `mexKbhit.c`/`.h`. Recompile with
`mex mexKbhit.c` only if the binary stops working after a MATLAB
upgrade.

## Architecture

### Layer Overview
The codebase has four layers:

1. **GUI** (`AdaptationGUI.m/.fig`) — experimenter interface
2. **Controllers** (`controllers/`) — ~40 real-time speed-control
   variants for different protocol needs
3. **Studies** (`studies/`) — six experiment-specific protocol scripts
   that generate speed profiles and sequence trials
4. **Utilities** (`+utils/`, root-level helpers) — packet formatting,
   gait detection, data archival

### Entry Point & User Input
`AdaptationGUI.m` is a MATLAB GUIDE GUI (requires its companion `.fig`).
On launch it initializes global state (see Key Patterns), audio players,
and keyboard polling. The experimenter selects a speed profile and
controller type via popup menus, then clicks Execute.

`Execute_button_Callback` reads these selections, loads the corresponding
speed profile vectors (`velL`, `velR`), and calls the selected controller
function, passing the profiles as arguments.

### Data Loading Pipeline
Speed profiles (`velL`, `velR`) are Nx1 column vectors in mm/s generated
by `generateProfiles_*` scripts inside each study's folder. A NaN value
at position k means stride k is self-paced (the controller holds or
queries treadmill speed rather than applying a predetermined value).
Profiles are passed directly to controller functions as arguments — there
is no file-based loading at runtime.

### Processing Pipeline
Every controller function follows the same template:

1. **Initialize** — open Vicon (`NexusGetFrame`) and treadmill
   (`sendTreadmillPacket`) connections, allocate the `datlog` struct,
   create animated-line plots for real-time feedback.
2. **Main loop** (`while ~STOP`) — each iteration:
   - Poll Vicon: `NexusGetFrame` → extract ankle/hip/pelvis marker
     positions and velocities.
   - Detect gait events: heel strike via `FindKinHS` (local maximum of
     limb angle); toe-off via vertical marker velocity / force-plate Fz
     threshold.
   - On ipsilateral toe-off: advance the profile index, call
     `getPayload_wda` to format the 64-byte treadmill packet, send via
     `sendTreadmillPacket`.
   - Append event timestamps and kinematic parameters to log arrays.
3. **Teardown** — on STOP: save `datlog` as a timestamped `.mat` file
   to `datlogs/`, then call `utils.transferData` to archive to the
   server.

### Key Patterns

**Global control flags** — All controllers read `global STOP PAUSE`
each loop iteration. Set `STOP = true` from the GUI or keyboard to end
the trial cleanly. Other globals (`SSspeed`, `SSstdev`, `addLog`, etc.)
carry state shared between the GUI and running controllers.

**Treadmill communication** — `getPayload_wda` formats a 64-byte packet:
1 format byte, 9 int16 values (speedR, speedL, speedRR, speedLL, accR,
accL, accRR, accLL, incline), a checksum byte (255 − data), and 27
padding bytes. Hard limits: speed ±6500 mm/s, acceleration ≤ 3000 mm/s².
`sendTreadmillPacket` sends over a UDP/serial connection initialized
once at the start of each trial.

**Gait detection** — `FindKinHS` finds local maxima in a limb-angle
trace (uses `>=`/`<=` to handle plateaus). `FindKinTO` finds local
minima. Both operate on a small sliding window and are called once per
suspected event, not continuously.

**datlog structure** — each controller allocates this struct before the
loop and appends one entry per gait event. Fields include `buildtime`
(ISO 8601), `profilename`, `mode`, and per-stride event timestamps
(`RTOTime`, `LTOTime`, `RHSTime`, `LHSTime`) plus `commSendTime` for
communication diagnostics. Saved as `datlogs/<timestamp>_<profile>.mat`.

### Key Functions

| Function | Purpose |
|---|---|
| `getPayload_wda` | Format 64-byte treadmill control packet |
| `sendTreadmillPacket` | Transmit packet to Bertec treadmill |
| `FindKinHS` / `FindKinTO` | Heel-strike / toe-off detection from kinematics |
| `parseEventsFromSpeeds` | Classify stride phases from speed profile vectors |
| `utils.transferData` | Recursively archive datlogs to server |
| `smoothStop` | Ramp both belts to zero safely |
| `getkeywait` / `kbhit` | Non-blocking keyboard polling during trials |

### Full Call Chain

```
AdaptationGUI (GUI init, global state, audio setup)
  └─ Execute_button_Callback
       ├─ loads velL, velR from generateProfiles_* output
       └─ calls controllerFunction(velL, velR, ...)
            ├─ NexusGetFrame (Vicon polling)
            ├─ FindKinHS / FindKinTO (gait events)
            ├─ getPayload_wda → sendTreadmillPacket (belt update)
            ├─ append to datlog arrays (each stride)
            └─ on STOP: save datlog .mat → utils.transferData
```

---

## MATLAB Version Compatibility
All code must be compatible with MATLAB R2021a through the current
release.

## Code Style Requirements
- Wrap lines at 76 characters
- Use spaces around `=` and binary comparison operators
- No brackets around a single output: `out = func()` not `[out] = func()`
- Suffix no-argument method calls with `()`: `obj.method()` not
  `obj.method`
- Use an `arguments` block when it meaningfully constrains input type/
  size or replaces a `nargin` check with a declared default. Place it
  immediately after the documentation comment. Default values must be
  compile-time constants — compute argument-dependent defaults in the
  function body. Multiline validators indent to align with the argument:
  ```matlab
  options.Colors (:,3) double ...
      {mustBeInRange(options.Colors, 0, 1)} = []
  ```
- camelCase for function files, PascalCase for scripts. Do not rename
  existing files. Choose descriptive variable names; abbreviations are
  acceptable when unambiguous (`tbl`, `fig`, `lme`, `pval`).
- Do not use `i` or `j` as loop indices (reserved for imaginary unit).
  For stride loops use `st`; for generic enumeration use `ii`, `jj`,
  `kk`. Preferred short names: `mscl` (muscles), `mrkr` (markers),
  `lbl` (labels), `tr` (trials), `con` (conditions), `fp` (force
  plates), `ch` (channels). Never use `iMuscle`-style names.
- Do not indent the base level of code inside functions
- Align `=` within a group of closely related assignments:
  ```matlab
  minSpacing  = max(1, round(options.MinSpacing));
  optimizeFor = upper(options.OptimizeFor);
  maxEvals    = round(options.MaxEvals);
  ```
- Write `0.5` not `.5`
- Use `mean(x, 'omitnan')` not `nanmean(x)` (similarly for `median`,
  `std`, `sum`). For `min`/`max`: `min(x, [], 'omitnan')`.
- Define unexplained numeric literals as named constants with an
  end-of-line comment giving their source or rationale:
  ```matlab
  gravityAcc    = 9.81;  % gravitational acceleration (m/s^2)
  impactWinFrac = 0.15;  % first 15% of stance (protocol spec)
  ```

## Documentation Comments
Every function requires a standard doc block after the definition line.

**H1 line** — immediately after `function`, no space between `%` and
the function name; name in ALL CAPS:
```matlab
%MYFUNCTION Compute stride-by-stride parameters from GRF data.
```

**Description** — one blank comment line after H1, then paragraphs
with first line indented three spaces, continuation lines one space:
```matlab
%
%   First sentence of description.
% Continuation line uses one space after %.
```

**Inputs / Outputs**:
```matlab
% Inputs:
%   argName - description
%
% Outputs:
%   out - description
```

**Toolbox Dependencies** — list required toolboxes; `None` if only
core MATLAB.

**See Also** — ALL CAPS for clickable hyperlinks:
```matlab
% See also RELATEDFUNCTION, ANOTHERFUNCTION.
```

## Code Organization
- Use `%%` section headers for all named logical phases; header text
  names the phase, not the code.
- Separate sections with a single blank line before `%%`. Separate
  logically distinct statement groups within a section with a blank
  line.

### Writing Comments
**Write a comment when:** starting a new `%%` section; a non-obvious
algorithm needs a block summary; a line encodes a domain rule or
formula; a magic number needs a source; a decision could have gone
another way. **Omit** when identifiers already make the purpose clear.

Special prefixes: `% TODO:` for known incomplete work; `% NOTE:` for
important caveats or non-obvious constraints.

When editing existing files, preserve: step-labeling comments,
WHY comments, commented-out alternative code, and end-of-line
clarifications (units, roles). Remove only comments that restate what
identifiers already make obvious.
