# Evals for the pbunit plugin

Cases for [`claude plugin eval`](https://code.claude.com/docs/en/plugin-evals.md). Each case runs with the
plugin and again without it, so the report shows what the skills add.

| Case | Skill | What it checks |
|---|---|---|
| `write-quantity-tests` | write-tests | Tests for `n_cst_quantity`, whose invalid-range path calls a protected `of_Warn` that shows a message box. Graders: the test file is in the test library; its forward block and create/destroy blocks have the form the compiler expects; the agent wrote an `of_Warn` override; no invalid-range call is made on a plain `n_cst_quantity`; the clamp and range edge cases are covered |
| `load-orders-tests` | write-tests | Tests for `n_cst_orderloader`, which retrieves `d_orders` into a DataStore, with no database. Graders: the file's structure; the agent wrote a `retrievestart` probe and used the production `d_orders` (an external copy never fires `retrievestart`); nothing connects to a database; the expectations allow for a cancelled retrieve returning -1 |
| `read-failing-results` | read-results | A failing run with three groups of failures: 27 tests that need `PFC_SECURITY_INI` (environment), a runtime error in the PFC linkage service (code), and every `n_cst_sort_tests` test failing in the class's own `setup` (fixture). Graders: each group classified correctly, the setting named, and nothing written |

Each case also reports whether its skill fired (not scored). Graders on the transcript look only at text the
agent wrote with Write or Edit, because the files it reads (the code under test, the skills' reference
files) contain the same patterns.

## Running

From the repository root:

```
claude plugin eval plugins/pbunit --scaffold --allow-tools Write Edit --no-publish
```

Add `--case <name>` to run one case.

- `--scaffold` runs each case's `scaffold.sh`, which creates the PowerBuilder solution in the run's empty
  workspace. On Windows it needs Git Bash, and `bash` must find Git Bash before
  `C:\Windows\System32\bash.exe` (the WSL launcher), or every run fails with
  `scaffold failed ... execvpe(/bin/bash) failed`. In PowerShell, before running the eval:

  ```powershell
  $env:Path = "C:\Program Files\Git\usr\bin;C:\Program Files\Git\bin;" + $env:Path
  ```
- The `claude` CLI must be signed in (`claude`, then `/login`); runs use its credentials.
- `--allow-tools Write Edit` lets the agent write the test files. The cases don't grant a shell: on native
  Windows a run that grants one is refused, because there is no sandbox for it. So the runs write tests
  but can't build them.
- Each case runs 3 times with the plugin and 3 times without it, on your account; a write-tests case costs
  about $2 for the six runs. Add `--runs 1` or `--ablation none` to spend less while changing a case, and
  `--max-cost-usd <n>` as a ceiling.
- Add `--keep-temp` to keep each run's workspace. To check that a run's tests compile and pass, copy the
  `.sru` files it wrote into a workspace made by the case's `scaffold.sh`, and run
  `pwsh -File tests\framework\scripts\Invoke-PBUnit.ps1 -Project <the case's .pbproj>`.

## Changing a case

Each case's project files are in its `fixture/` folder. `scaffold.sh` is generated from them plus a copy of
the framework (`pbunit*.pbl`, `scripts`, `README.md`, `LICENSE`). After changing a fixture or the framework,
regenerate every case's `scaffold.sh` and commit the result:

```
pwsh -File plugins/pbunit/evals/Update-Scaffolds.ps1
```
