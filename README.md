# PBUnit 2025

A unit testing framework for PowerBuilder 2025 solution-format projects (`.pbsln` / `.pbproj`).

It is based on [PBUnit](https://sourceforge.net/projects/pbunit/), an xUnit-style framework for PowerBuilder
that is no longer maintained (see also the [original quick start](https://maonet.wordpress.com/2008/02/05/pbunitpowerunit-quick-start/)).
This version keeps the original `testcase` model and replaces the GUI runner with a command-line runner:

- more assertions: `assertEquals` for common types, `assertTrue`/`assertFalse`/`assertNull`, `assertRowCount`, `assertThrows`
- automatic test discovery: no list of test classes to maintain
- runtime errors in a test are reported as test errors instead of stopping the run
- text and JUnit XML results, and a process exit code that build scripts and CI servers can check
- a PowerShell script that builds the test project with PBAutoBuild and runs it

## Contents

| Path | What it is |
|---|---|
| `pbunit.pbl` | Core: `testcase`, `testsuite`, `testresult` and the assertions |
| `pbunitfunc.pbl` | `f_catchsystemerror`, for an application's `systemerror` event |
| `pbunitrunner.pbl` | `n_pbunit_runner` (command line, discovery, reports) and `n_pbunit_result` |
| `scripts/Invoke-PBUnit.ps1` | Builds a test project, runs it and prints the results |
| `selftest/` and `pbunit_selftest.pbproj` | The framework's own tests, and an example test application |

## Adding PBUnit to a project

1. Add this repository to your project, for example as a git submodule:

   ```
   git submodule add <url of this repository> tests/framework
   ```

2. Create a test project (`.pbproj`) whose entry library holds your test application and test cases.
   List the PBUnit libraries after it, followed by the libraries under test:

   ```xml
   <Libraries AppEntry="tests\mytests.pbl">
     <Library Path="tests\mytests.pbl"/>
     <Library Path="tests\framework\pbunitrunner.pbl"/>
     <Library Path="tests\framework\pbunit.pbl"/>
     <Library Path="tests\framework\pbunitfunc.pbl"/>
     <Library Path="src\myapp.pbl"/>
   </Libraries>
   ```

3. Create the test application. Copy `selftest/selftest.pbl/pbunit_selftest.sra` and adjust the globals your
   code expects (for example, a PFC application declares `sqlca` as `n_tr` and creates `gnv_app`). The `open`
   event only needs:

   ```
   n_pbunit_runner	lnv_runner
   Integer				li_exitcode

   lnv_runner = create n_pbunit_runner
   li_exitcode = lnv_runner.of_Run(CommandParm())
   lnv_runner.of_Exit(li_exitcode)
   ```

   `of_Exit` ends the process at once, so do any cleanup (such as destroying `gnv_app`) before calling it.

4. Ignore the generated registry, `n_pbunit_registry.sru` in the entry library, and the build output folder.

## Writing tests

A test case is a class that inherits from `testcase` and whose name ends in `tests`.
Each test is an event whose name starts with `test` and that takes no arguments.
Every test runs on a new instance of the class, with the `setup` and `teardown` events around it.

```
global type n_cst_string_tests from testcase
event test_trims_both_ends ( )
end type

event test_trims_both_ends();n_cst_string	lnv_string

assertEquals("abc", lnv_string.of_Trim("  abc  "))
end event
```

### Assertions

Each assertion returns `true` if it passed. Most have an overload that takes a message as the first argument,
which is prefixed to the failure text.

| Assertion | Failure text |
|---|---|
| `assertEquals(expected, actual)` for string, long, decimal, boolean, date, datetime | `expected <10> but was <20>` |
| `assertTrue(condition)`, `assertFalse(condition)` | `Expected true` / `Expected false` |
| `assertNull(value)`, `assertNotNull(value)` | `Value is not null` / `Value is null` |
| `assertIsValid(object)` | `Object is not valid` |
| `assertRowCount(datawindow or datastore, expected)` | `datastore row count: expected <2> but was <0>` |
| `assertThrows("event_name")` | `Expected event event_name to throw` |
| `assert(message, condition)`, `fail(message)` | the message |

Two null values are equal; a null and a non-null value are not.

`assertThrows` triggers an event on the test case and passes if it throws (including PowerBuilder runtime
errors). PowerScript has no closures, so put the code that should throw in its own event, and do not start
that event's name with `test` or it will also run as a test.

## Running tests

```
pwsh -File tests\framework\scripts\Invoke-PBUnit.ps1 -Project mytests.pbproj
pwsh -File tests\framework\scripts\Invoke-PBUnit.ps1 -Project mytests.pbproj -Filter "n_cst_string_tests.test_trim*"
```

The script:

1. finds the test classes in the project's libraries and writes `n_pbunit_registry.sru` into the entry library,
2. builds the project with `pbautobuild250.exe /pbc /d` and moves the PBDs next to the exe,
3. runs the exe and prints `results.txt`; `results.xml` is written beside it.

Options: `-OutDir` (default `build\<project name>`), `-Filter`, `-TimeoutSeconds` (default 300) and
`-PBAutoBuild` (the path to `pbautobuild250.exe`).

| Exit code | Meaning |
|---|---|
| 0 | All tests passed |
| 1 | At least one test failed or had an error |
| 2 | Nothing ran or the run could not complete: build failure, no tests found, unknown argument, timeout |

The test exe can also be run directly, or from the PowerBuilder IDE with these arguments:

| Argument | Default |
|---|---|
| `/out:<file>` | `pbunit_results.txt` |
| `/junit:<file>` | `pbunit_results.xml` |
| `/filter:<list>` | all tests; a comma-separated list of `class` or `class.test` names, where a trailing `*` matches a prefix |

When running from the IDE, run the script once first so that `n_pbunit_registry` exists.

## Things to know

- A test that opens a message box or modal window stops the run until the script's timeout. Configure the code
  under test to log instead of display, or replace the visual parts with test doubles.
- Test times are CPU time as reported by PowerBuilder's `CPU()`, in milliseconds.
- Windows Smart App Control blocks unsigned executables it has not seen before, which includes each newly built
  test exe. Sign the exe as part of the build, or run the tests on a machine where Smart App Control is off.
- `Invoke-PBUnit.ps1` needs PowerShell 7 (`pwsh`) and PowerBuilder 2025 (PBAutoBuild 25).

## License

PBUnit is licensed under the [Common Public License 1.0](LICENSE), and so is this modified version.
The `pbunit.pbl` and `pbunitfunc.pbl` libraries come from the original project; `testcase` has been extended
with the assertions above. `pbunitrunner.pbl`, `scripts/` and `selftest/` are new.

Modifications © 2026 Bruce Armstrong.
