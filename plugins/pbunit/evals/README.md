# Evals for the pbunit plugin

Cases for [`claude plugin eval`](https://code.claude.com/docs/en/plugin-evals.md). Each case runs with the
plugin and again without it, so the report shows what the skills add.

| Case | What it checks |
|---|---|
| `write-quantity-tests` | Writing tests for `n_cst_quantity`, whose invalid-range path shows a message box. Graders: the test file exists in the test library; its forward block, test events and create/destroy blocks are in the form the compiler expects; a descendant overrides `of_Warn`; no invalid-range call is made on a plain `n_cst_quantity`; the clamp and range edge cases are covered; the `write-tests` skill fired |

## Running

From the repository root:

```
claude plugin eval plugins/pbunit --scaffold --allow-tools Write Edit --no-publish
```

- `--scaffold` runs each case's `scaffold.sh`, which creates the PowerBuilder solution in the run's empty
  workspace (Git Bash is needed on Windows).
- `--allow-tools Write Edit` lets the agent write the test files. The cases don't grant a shell: on native
  Windows a run that grants one is refused, because there is no sandbox for it. So the runs write the tests
  but can't build them.
- Each case runs 3 times with the plugin and 3 times without it, on your account. Add `--runs 1` or
  `--ablation none` to spend less while changing a case, and `--max-cost-usd <n>` as a ceiling.
- Add `--keep-temp` to keep each run's workspace. To check that a run's tests compile and pass, copy its
  `tests\qtytests.pbl\*.sru` files into a workspace made by `scaffold.sh` and run
  `pwsh -File tests\framework\scripts\Invoke-PBUnit.ps1 -Project qty_tests.pbproj`.

## Updating `scaffold.sh`

`scaffold.sh` embeds copies of the framework files (`pbunit*.pbl`, `scripts`, `README.md`, `LICENSE`). When
those change, regenerate it so the cases test against the current framework.
