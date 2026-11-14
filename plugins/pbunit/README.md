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

## MCP tools

The plugin also starts an MCP server, `pbunit` (`mcp/PBUnitMcpServer.ps1`, run with `pwsh`), so agents can
work with the framework without a shell:

| Tool | Use |
|---|---|
| `find_projects` | Test projects under a folder, with their test classes and test events; reports a missing framework. No build |
| `check_source` | Checks `.sru`/`.srw` test sources for layout mistakes the compiler rejects or that stop tests from running, in about a second |
| `run_tests` | Builds and runs a test project (filter, platform, timeout). Returns the outcome, failures grouped with hints, and compile errors with file and line |
| `get_results` | The last run's results, without building |

In Claude Code the tools are named `mcp__plugin_pbunit_pbunit__<tool>`. A build can take minutes;
`run_tests` sends progress notifications while it waits.

`mcp/Test-PBUnitMcpServer.ps1` tests the server over stdio against this repository's self-test project
(`-SkipBuilds` for the quick checks).

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
