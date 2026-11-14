# PBUnit plugin for Claude Code

Skills that teach Claude Code (and other agents that read `SKILL.md` skills) how to work with
[PBUnit 2025](https://github.com/bruce-armstrong/PBUnit2025) tests in a PowerBuilder 2025 solution:

| Skill | Use |
|---|---|
| `pbunit:write-tests` | Write test classes and test doubles as PowerScript source, in the format the PowerBuilder compiler expects, and prove a regression test fails without the fix |
| `pbunit:run-tests` | Build and run the tests with `Invoke-PBUnit.ps1`, filtered or complete, 32-bit or 64-bit |
| `pbunit:read-results` | Summarize `results.xml` / `results.txt` and decide whether each failure is in the code, the test or the environment |

Claude loads a skill automatically when a request matches it, for example "add a regression test for
this fix" or "why did the unit tests fail?". You can also run one directly, e.g. `/pbunit:run-tests`.

## Install

In Claude Code:

```
/plugin marketplace add bruce-armstrong/PBUnit2025
/plugin install pbunit@pbunit2025
```

Or from a shell:

```
claude plugin marketplace add bruce-armstrong/PBUnit2025
claude plugin install pbunit@pbunit2025
```

## Requirements

The skills drive the tools the framework already uses: Windows, PowerShell 7 (`pwsh`) and PowerBuilder 2025
(`pbautobuild250.exe`), with the framework in the project, usually as a git submodule at `tests\framework`.

## License

Common Public License 1.0, like the rest of PBUnit 2025.
