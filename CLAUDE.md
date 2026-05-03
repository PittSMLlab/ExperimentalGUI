# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

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
release. Do not use language features, functions, or syntaxes
introduced after R2021a without an explicit compatibility note.
Similarly, do not use functions removed before R2021a. A common
example in older lab code: `findstr` was removed in R2014b and must
be replaced with `strfind`.

## Code Style Requirements
- Wrap lines at 76 characters (the MATLAB editor default)
- Use spaces around `=` and binary comparison operators (`~=`, `==`,
  `<`, `>`, `<=`, `>=`)
- Do not use brackets around a single output argument: write
  `out = func()` not `[out] = func()`
- Suffix no-argument method calls with `()` to distinguish them from
  property access: write `obj.method()` not `obj.method`
- Include a MATLAB `arguments` block immediately after the documentation
  comment for all functions that accept inputs; declare input sizes,
  types, and default values there rather than using `nargin` checks.
  When adding an `arguments` block to an existing function, verify all
  callers supply the now-required arguments. Place multiline validators
  on the line(s) following the argument name, indented to align with
  the argument name:
  ```matlab
  options.Colors (:,3) double ...
      {mustBeInRange(options.Colors, 0, 1)} = []
  ```
- Use camelCase for function file names and PascalCase for script
  file names (not underscore-separated). Do not rename existing files
  unless explicitly instructed — file renaming can complicate git
  version history. Use camelCase or PascalCase for variable names.
  Choose names that make their purpose clear without a comment —
  prefer `participantCount` over `n`, `knotLocations` over `kl`.
  Abbreviations are acceptable when they are unambiguous in context
  (e.g., `tbl`, `fig`, `lme`, `pval`).
- Do not use `i` or `j` as loop index variables (reserved for the
  imaginary unit in MATLAB). For stride loops use `st`; for generic
  enumeration use `ii`, `jj`, or `kk`. When iterating over a named
  collection and a terse abbreviation adds unambiguous clarity, prefer
  it over `ii`: `mscl` (muscles), `mrkr` (markers), `lbl` (labels),
  `fld` (fields), `tr` (trials), `con` (conditions), `fp` (force
  plates), `fi` (files), `stp` (steps), `lg` (legs), `sd` (sides),
  `ord` (order), `ch` (channels), `stat` (statistics), `hrm`
  (harmonics). Use `ii` when no short name adds clarity or when a
  terse name would introduce ambiguity. Never use verbose `i`-prefix
  names (e.g., `iMuscle`, `iMarker`) — these conflict with the
  imaginary-unit prohibition.
- Do not indent the base level of code inside functions, as the MATLAB
  IDE autoformatter removes this indentation
- Align `=` signs within a group of closely related assignments to make
  differences between variable names visually apparent:
  ```matlab
  minSpacing  = max(1, round(options.MinSpacing));
  optimizeFor = upper(options.OptimizeFor);
  maxEvals    = round(options.MaxEvals);
  ```
  Apply this within a logical group; do not force alignment across
  unrelated statements separated by blank lines.
- Write decimal numbers with an explicit leading zero: use `0.5`
  not `.5`.
- Use modern NaN-omitting aggregation functions rather than the
  deprecated `nan*` family: write `mean(x, 'omitnan')` instead of
  `nanmean(x)`, and equivalently for `median`, `std`, and `sum`.
  For `min` and `max`, the `'omitnan'` flag requires an explicit
  empty placeholder for the second argument:
  `min(x, [], 'omitnan')` / `max(x, [], 'omitnan')`. Writing
  `min(x, 'omitnan')` invokes the element-wise two-array form and
  returns an array, not a scalar.

## Documentation Comments
Every function requires a standard doc block after the definition line.

**H1 line** — the first comment line, on the line immediately after
`function`. No space between `%` and the function name; the name is
in ALL CAPS, followed by a brief one-line description. This is the
only place in a comment block where there is no space after `%`:
```matlab
%MYFUNCTION Compute stride-by-stride parameters from GRF data.
```

**Description** — follows the H1 line with exactly one blank comment
line (`%`) between them. No section header. Use paragraph
indentation: the first line of each paragraph is indented three
spaces after `%`; all continuation lines in the same paragraph use
one space after `%`:
```matlab
%
%   First sentence of description, indented.
% Continuation lines use one space after %.
%
%   A second paragraph, again indented on its first line.
% Continuation lines use one space here too.
```

**Inputs / Outputs** — labeled section headers (`% Inputs:`,
`% Outputs:`), with each argument indented three spaces:
```matlab
% Inputs:
%   argName - description of the argument
%
% Outputs:
%   out - description of the output
```

**Examples** (optional) — include after Outputs when it would
clarify how the function is used within the labTools pipeline.

**Toolbox Dependencies** — list any required MATLAB toolboxes;
state `None` if only core MATLAB is required.

**See Also** — function names must be ALL CAPS so that MATLAB
renders them as clickable hyperlinks in the Command Window:
```matlab
% See also RELATEDFUNCTION, ANOTHERFUNCTION.
```

Do not include a `Syntax` section — it redundantly restates the
function definition and adds no information.

## Code Organization
- Use `%%` section headers to divide every script and function into
  named logical phases. The header text should name the phase, not
  describe the code:
  ```matlab
  %% Validate Input Arguments
  %% Fit Zero-Knot Linear Mixed-Effects Model (ML)
  %% Prepare Output Data Structure
  ```
- Separate sections with a single blank line before the `%%` header.
  Separate logically distinct groups of statements within a section
  with a single blank line.
- Maintain consistent whitespace and indentation throughout.
- In the 'Labels and Descriptions' `aux` block found in parameter
  computation functions, keep each parameter name and its description
  on a single line regardless of length — this block is exempt from
  the 76-character line-wrap rule

### Writing Comments
Write comments to help a future reader (including yourself) understand
purposes and decisions that are not obvious from the code itself.

**Write a comment when:**
- Starting a new `%%` section — the header *is* the comment; make it
  descriptive (see section header guidance above).
- A group of statements implements a non-obvious algorithm or
  multi-step procedure — add a short block comment above the group
  summarizing what it does and, if non-obvious, why that approach
  was chosen.
- A single line encodes a domain-specific rule, constraint, or
  formula — add an end-of-line comment explaining its meaning:
  ```matlab
  bias = mean(stepAsym(end-39:end));  % mean of last 40 non-bad strides
  pval = results.pValue(2);           % LRT p-value (second row = complex model)
  ```
- A value is a magic number whose meaning would not be obvious to
  a reader unfamiliar with the study protocol:
  ```matlab
  numBase = 40;   % strides used to estimate baseline bias
  alpha   = 0.05; % significance threshold for likelihood ratio test
  ```
- A decision could reasonably have been made differently — explain
  why this choice was made:
  ```matlab
  % must use ML (not REML) for valid likelihood ratio test
  lme = fitlme(tbl, formula, 'FitMethod', 'ML');
  ```

**Omit a comment when:**
- The identifier names already make the purpose completely clear.
  `participantIDs = unique(tbl.Participant)` needs no comment.
- The comment would merely restate the code in English
  (`% increment counter` above `ii = ii + 1`).

**Special prefixes:**
- `% TODO:` — known incomplete work or a known limitation to
  revisit later.
- `% NOTE:` — an important caveat, subtle invariant, or
  non-obvious constraint that future editors must not accidentally
  remove.

### Comment Preservation

When editing existing files, preserve all of the following:

- **Step-labeling comments** — short inline or block comments that
  label distinct steps in a multi-step algorithm (e.g., `% round to
  integer and canonicalize by sorting for the cache key`). These are
  navigation aids for readers of complex code.
- **WHY comments** — comments explaining a non-obvious decision, a
  hidden constraint, or a subtle invariant (e.g., `% must use ML for
  valid likelihood ratio test`).
- **Commented-out code** — alternative implementations or temporarily
  disabled code that the author hasn't decided to delete (e.g., an
  `% alternatively:` block). These represent work in progress.
- **End-of-line clarifications** — inline comments on assignment lines
  that clarify units, roles, or non-obvious behavior (e.g.,
  `% Lower bound`, `% safety limit to prevent infinite loops`).

Remove only comments that redundantly restate what the adjacent code
already makes obvious from its identifier names alone.
