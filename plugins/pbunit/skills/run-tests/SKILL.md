---
name: run-tests
description: Build and run PBUnit unit tests for a PowerBuilder 2025 solution project with Invoke-PBUnit.ps1 (PBAutoBuild), all of them or a filtered subset, 32-bit or 64-bit. Use when asked to run, rerun or check PowerBuilder unit tests, to verify a fix or a refactoring, or right after writing or changing PBUnit tests.
---

# Running PBUnit tests

`Invoke-PBUnit.ps1` (in the framework's `scripts` folder) finds the test classes, generates
`n_pbunit_registry.sru`, builds the test project with PBAutoBuild, runs the test exe and prints the results.

## Requirements

- Windows, PowerShell 7 (`pwsh`), and PowerBuilder 2025, whose `pbautobuild250.exe` is by default in
  `C:\Program Files (x86)\Appeon\PowerBuilder 25.0\`. Pass `-PBAutoBuild <path>` if it's elsewhere.
- The framework's files must be present. If the framework is a git submodule (`tests\framework` with a
  `.gitmodules` entry) and its folder has no `scripts\Invoke-PBUnit.ps1`:
  1. If the folder holds only empty `pbunit.pbl`, `pbunitfunc.pbl` and `pbunitrunner.pbl` folders
     (PowerBuilder creates them when it connects to a repository), delete those empty folders.
  2. Run `git submodule update --init` in the repository root.

## Find the command

1. Prefer the project's own wrapper if it has one (for example `tests\run_tests.ps1`); read it first to
   see its parameters.
2. Otherwise find the test project: the `.pbproj` whose libraries include `pbunit.pbl`. Run:

```
pwsh -File <framework>\scripts\Invoke-PBUnit.ps1 -Project <path>\<tests>.pbproj
```

| Option | Use |
|---|---|
| `-Filter "<list>"` | Comma-separated `class` or `class.test` names; a trailing `*` matches a prefix, e.g. `n_cst_string_tests` or `n_cst_string_tests.test_trim*`. Use it while working on one class; run everything before reporting that work is done |
| `-Platform 64` | Build and run a 64-bit exe (default 32). Run both when the code under test calls Windows API functions (external functions) |
| `-OutDir <dir>` | Output folder. Default `build\<project>` beside the project, or `build\<project>-x64` |
| `-TimeoutSeconds <n>` | How long the test run may take (default 300) |

## Running it

- The build takes from under a minute to several minutes, depending on the size of the project.
  Give the command a timeout of at least 10 minutes, or run it in the background and wait for it.
- Don't run two builds of the same project at the same time: they share output folders.
- The script prints `Test classes: ...`, `Building ...`, then the contents of `results.txt` and the path of
  `results.xml`. It writes `build.log`, `results.txt` and `results.xml` in the output folder.

| Exit code | Meaning |
|---|---|
| 0 | All tests passed |
| 1 | At least one test failed or had an error |
| 2 | The run didn't complete: no test classes, build failure, wrong platform, the exe couldn't start, timeout, or a runner problem such as an unknown argument |

## After the run

- Exit 0: report the count from the results' second line, for example `172 passed, 0 failed, 0 errors`.
- Any other exit code: use the `read-results` skill to find the cause before changing code or tests.
- The run leaves `n_pbunit_registry.sru` in the test library and PBDs in the output folder. Both are
  expected; don't commit them. Check that `git status` shows only the changes you meant to make.

## Never

- Change Windows security settings. If Windows blocks the test exe ("An Application Control policy has
  blocked this file"), that is Smart App Control or another application control policy. Stop and tell the
  user; they decide whether to sign the exe, allow it, or turn the policy off.
- Click through or dismiss dialogs the test exe opens, or kill unrelated processes. If a run times out,
  report it (see `read-results`).
