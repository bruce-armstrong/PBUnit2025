---
name: read-results
description: Interpret PBUnit test results for PowerBuilder (results.txt / results.xml from Invoke-PBUnit.ps1, build.log, the script's exit code) and decide whether each failure comes from the code under test, the test itself, or the environment. Use after a PBUnit run that did not pass cleanly, or when asked why PowerBuilder unit tests failed, hung or didn't run.
---

# Reading PBUnit results

## 1. Summarize

If the `pbunit` MCP tools are available, `run_tests` and `get_results` already return this summary (with
compile errors for a failed build); start from that.

Otherwise run the bundled summary script on the run's output folder (the folder with `results.xml`, `results.txt`
and `build.log`; by default `build\<test project>` beside the `.pbproj`):

```
pwsh -File "${CLAUDE_SKILL_DIR}/scripts/Get-PBUnitSummary.ps1" -Results "<output folder>"
```

It prints the outcome, totals, runner `PROBLEM:` lines, the classes with failing tests, and the failures
grouped by message, with a hint for each group. Add `-Json` for machine-readable output.

If you can't run scripts, read `results.txt` instead: line 1 is `RESULT: PASS|FAIL|ERROR`, line 2 the counts,
then any `PROBLEM:` lines, then one `PASS`, `FAIL` or `ERROR` line per test (`class.test`) with its messages
indented below it. Group the failures yourself by class and by message.

Check the `written` time: if it is older than the run you just did, the run didn't get as far as writing
results, and these are old results. Then the cause is in the script's console output or `build.log`.

## 2. Classify each group

| Outcome | Meaning |
|---|---|
| `PASS` (exit 0) | Every test passed |
| `FAIL` (exit 1) | Some tests have `FAIL` (an assertion didn't hold) or `ERROR` (an exception or runtime error) |
| `ERROR` (exit 2) | The runner itself reported a problem (`PROBLEM:` lines), or no tests ran |
| exit 2, no new results | Build failure, timeout, wrong platform, or the exe couldn't start |

Decide for each group whether the cause is:

- **Environment**: a missing prerequisite, not a code problem. Messages that start `Not configured:`,
  blocked exes, missing framework files, a test database or file that isn't there.
- **Test**: the test or its fixture is wrong. Typical signs: every test in a class fails with the same
  message (setup), a test double that doesn't do what the test assumes, an expectation that contradicts
  the documented behavior.
- **Code**: the code under test behaves differently from what the test expects, or throws a runtime error
  on input it should handle.

[reference/triage.md](reference/triage.md) lists known symptoms and their causes. Read the failing test's
source and the code under test before deciding: the test's leading comment states the intended behavior.

## 3. Check whether a failure is new

When you have changed code, find out whether the failures were there before your change. Run the same
filter on the code without your change (for example on a clean checkout of the base branch, or after
`git stash`, then `git stash pop`), or compare with an earlier results file. Report pre-existing failures
separately from new ones.

## 4. Report

Tell the user:

- the outcome and counts, e.g. `RESULT: FAIL, 172 tests: 145 passed, 27 failed, 0 errors`;
- each group of failures: how many tests, the message, and your classification with the evidence
  (for example "all 27 are `n_cst_security_groups_tests`, which needs `PFC_SECURITY_INI` set; not a
  regression");
- what you propose next: a code fix, a test fix, or a setup step for the user.

Don't change a test's expectation to make it pass unless you can show the expectation was wrong, and say so
when you do. Don't call a run passing when it ended with exit code 2.
