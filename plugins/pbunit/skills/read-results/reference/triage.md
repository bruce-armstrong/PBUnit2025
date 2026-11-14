# Symptoms and causes

## The run didn't complete (exit 2)

| Symptom | Cause | What to do |
|---|---|---|
| `No test classes found (classes ending in 'tests' that inherit from testcase)` | No class in the project's libraries has a name ending in `tests` and an ancestor chain that reaches `testcase` | Check the class name and the `global type ... from` line; check the library is listed in the `.pbproj` |
| `Build failed; see <folder>\build.log` | Compile error | Find the `[Error]` lines in `build.log` (UTF-16 text). Each gives `file(line,col)` and the message. Usually a syntax or type error in a new test or helper; see the write-tests skill's source-format reference |
| `The exe was built as 32-bit, not 64-bit` (or the reverse) | The build ignored the platform | Rerun; if it persists, report the PBAutoBuild version |
| `Could not start ... An Application Control policy has blocked this file` | Windows Smart App Control (or another application control policy) blocks the newly built, unsigned exe | Environment. Tell the user; never change security settings yourself |
| `Test run timed out after N seconds (a dialog may have opened)` | A test opened a message box or modal window, or loops forever | Find the test: rerun with `-Filter` on one class at a time. Replace the dialog with a test double (write-tests skill, test-doubles pattern 2 or 9) |
| `No results file was written.` and an exit code such as `-1073741819` | The exe crashed (access violation) before writing results, often because it couldn't load its PBDs or the PowerBuilder runtime | Run through `Invoke-PBUnit.ps1`, which puts the PBDs beside the exe; check the runtime version the exe expects is installed |
| `PBUnit framework not found` or `Invoke-PBUnit.ps1` missing | The framework submodule isn't checked out | Delete empty placeholder `.pbl` folders in the framework folder if any, then `git submodule update --init` |

## Runner problems (`PROBLEM:` lines, outcome ERROR)

| Message | Cause |
|---|---|
| `n_pbunit_registry not found. Build with Invoke-PBUnit.ps1...` | The exe was built without the script (for example in the IDE before the script ever ran), so the generated class list is missing |
| `No tests ran.` | The filter matched nothing, or the class has no test events: tests are events whose names start with `test` and take no arguments, declared in the class's `global type` block and given a script |
| `Unknown argument: <arg>` | A bad argument to the test exe; check `-Filter` quoting |

## Records for a whole class

| Message on a `(class)` record | Cause |
|---|---|
| `Class not found` | The registry lists a class that isn't in the build, for example one that failed to compile or was deleted. Rerun the script, which regenerates the registry |
| `Class does not inherit from testcase` | The name ends in `tests` but the class isn't a test case. Rename helpers so they don't end in `tests` |

## Failures and errors in tests

| Pattern | Likely cause |
|---|---|
| Message starts `Not configured:` | Environment: the test needs setup the user must provide, named in the message. Not a regression |
| Every test in a class fails with the same message | The class's `setup` or shared fixture is failing (the first assertion in setup fails, and so every test does). Fix the fixture first |
| `label: expected <x> but was <y>` | An assertion. Read the test's comment and the code under test to decide whether the code or the expectation is wrong |
| `Runtime error <n>: <text> [<object>.<routine> line <n>]` (ERROR) | A PowerBuilder runtime error. If `<object>` is the code under test, it's usually a real bug (for example `Mismatched ANY datatypes in expression` from comparing values of different types, or a null object reference). If it's the test or a helper, the test is wrong. `teardown` still ran |
| `<ExceptionClass>: <message>` (ERROR) | An exception the code threw and the test didn't expect. If throwing is correct, the test should use `assertThrows` |
| `Test <name> was not found.` | The test event is declared but has no script, or is misspelled |
| A retrieve probe counts 0 retrieves and the code returns -1 | The DataWindow object has an external data source, so `Retrieve()` returns -1 without firing `retrievestart`. Use the production DataWindow object with its SQL source (test-doubles pattern 4) |
| A test expects 0 or more rows after a retrieve the probe cancelled, but gets -1 | A retrieve cancelled in `retrievestart` returns -1; the test's expectation is wrong (test-doubles pattern 4) |
| Results change between runs | Test order or shared state: a test depends on files, settings or globals another test left behind. Make `setup`/`teardown` restore everything |
| Fails only with `-Platform 64` (or only 32) | Code that calls Windows API functions with the wrong pointer or handle size for that platform |

## Timing

Test times in the results are CPU time from PowerBuilder's `CPU()` in seconds with millisecond resolution;
`0.000` is normal for fast tests. They aren't wall-clock times.
