---
name: write-tests
description: Write PBUnit unit tests for PowerBuilder 2025 code as PowerScript source files (.sru/.srw/.srd) in a solution-format project. Use when asked to add, write, extend or fix unit tests or regression tests for PowerBuilder objects, functions, PFC services or a bug fix, in a project that uses the PBUnit2025 framework.
---

# Writing PBUnit tests

Tests are PowerScript source files that you write directly into a PowerBuilder 2025 solution's library
folders (`<name>.pbl\` is a folder of `.sru`, `.srw`, `.srd`... files). The `run-tests` skill builds and runs them.

## Before writing

1. Find the test project: the `.pbproj` whose `<Libraries>` list includes `pbunit.pbl` (usually
   `tests\framework\pbunit.pbl`). Its `AppEntry` library is where test classes and test helpers go.
2. Read the code under test, including its ancestors, so you know which functions are public, protected
   or private and what they return.
3. Read one or two existing `*tests.sru` files in that library and follow their style, naming and helper
   objects. Reuse existing helpers (`n_<x>test_*`, `w_<x>test_*`, `u_<x>test_*`) before writing new ones.

## Test class rules

- Inherits from `testcase` (directly or through another test class), and the class name ends in `tests`,
  for example `n_cst_string_tests`. Discovery is automatic: there is no list to register it in.
- Each test is a user event whose name starts with `test` and that takes no arguments.
  Declare it in the `global type ... from testcase` block and give it a script.
- Every test runs on a new instance of the class: `setup`, the test event, then `teardown`.
- Put shared fixtures in instance variables created in `setup` and destroyed or closed in `teardown`.
- Write the file in the exact format in [reference/source-format.md](reference/source-format.md): UTF-8 with
  a byte order mark, CRLF line endings, one object per file, file name = object name.

## Writing good tests

- One behavior per test event. Start the script with a one-line comment that states the behavior.
- Label assertions: pass a short message as the first argument, e.g. `assertEquals("trimmed", "abc", ls_result)`.
  Failures then read `trimmed: expected <abc> but was <ab>`. The full list is in
  [reference/assertions.md](reference/assertions.md).
- When a later check depends on an earlier one, stop early: `If Not assertEquals("opened", 1, li_rc) Then Return`.
- Test edge cases the code handles: null, empty, zero, negative, boundaries, invalid input and the
  return code for failure (PFC functions usually return 1 for success and -1 for failure).
- Leave nothing behind: close windows, destroy objects, delete temporary files, and put back any
  global state you changed (application manager settings, themes, INI files, registry values).
- Never let the code under test open a message box or a modal window: the run hangs until it times out.
  Use a test double that overrides the call instead.
- Don't use real databases, networks, printers, browsers or user interaction. Code that needs them is tested
  through test doubles; see [reference/test-doubles.md](reference/test-doubles.md).

## When code is hard to test

[reference/test-doubles.md](reference/test-doubles.md) has the patterns used in practice, with code:
exposing protected functions through a test descendant, recording side effects instead of performing them,
faking an external service, counting and cancelling DataWindow retrieves, hosting visual controls in a
hidden window, and skipping tests whose environment isn't available.

If the code has no protected function you can override for a side effect (a message box, a file dialog,
an HTTP call), propose moving that call into a small protected function. Ask the user before changing
production code to make it testable.

## Prove the tests work

1. Run the new tests with the `run-tests` skill, filtered to the new class.
2. For a regression test, make sure it **fails without the fix**: put back the old version of the fixed
   file(s) with `git restore --source=<fix-commit>~1 -- "<path>"`, run the test and see it fail, then
   restore the current version with `git restore -- "<path>"` and see it pass. Check `git status`
   afterwards. (Don't use `git show ... > file`: PowerShell's `>` can change the file's encoding.)
   If the fix is not committed yet, `git restore` would discard it: copy the fixed file somewhere safe
   first and copy it back afterwards, or ask the user to commit the fix before you do this.
   A test that passes on the broken code doesn't test the fix; rework it until it fails there.
3. Use the `read-results` skill to interpret anything other than a clean pass.

## Don't

- Edit the PBUnit framework (`pbunit.pbl`, `pbunitfunc.pbl`, `pbunitrunner.pbl`). It is usually a git
  submodule; framework changes belong in the PBUnit2025 repository.
- Commit `n_pbunit_registry.sru`: the run script generates it.
- Weaken or delete an assertion to make a failing test pass without explaining why the expectation was wrong.
