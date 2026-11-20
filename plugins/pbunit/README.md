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

## MCP server

The plugin includes an MCP server, `pbunit`, so agents can find, check, build and run tests and read their
results without a shell. It's a single PowerShell 7 script, [`mcp/PBUnitMcpServer.ps1`](mcp/PBUnitMcpServer.ps1),
that talks MCP over stdin/stdout. There is nothing to build or deploy: an MCP client starts the script, and
the script runs the project's own `Invoke-PBUnit.ps1` and PBAutoBuild.

### Tools

| Tool | Parameters | Use |
|---|---|---|
| `find_projects` | `root` (folder; default: the project folder) | Test projects under a folder, with their test classes and test events; reports a missing framework, such as an uninitialized submodule. No build |
| `check_source` | `path` (required: a `.sru`/`.srw` file or a library folder) | Checks test sources for layout mistakes the compiler rejects or that stop tests from running, in about a second. Doesn't type-check; `run_tests` reports compile errors |
| `run_tests` | `project` (`.pbproj`, or a folder with exactly one; default: the only test project under the project folder), `filter` (e.g. `n_cst_string_tests.test_trim*`), `platform` (`32` or `64`, default `32`), `testTimeoutSeconds` (default 300) | Builds and runs the tests. Returns the outcome (`PASS`, `FAIL`, `BUILD_FAILED`, `TIMEOUT`, `BLOCKED`, `NO_TESTS`, `ERROR`), counts, failures grouped by message with hints, compile errors with file and line, and the paths of `results.txt`, `results.xml` and `build.log` |
| `get_results` | `project`, `platform` | The last run's results, without building |

Results go to `build\<project>\` (`build\<project>-x64\` for 64-bit) next to the `.pbproj`.

### The project folder

Relative paths, and tools called without a path, use the project folder:

1. `PBUNIT_PROJECT_DIR`, if set. Set it for clients that have no project folder, such as Claude Desktop.
2. `CLAUDE_PROJECT_DIR`, which Claude Code sets to the folder the session runs in.
3. Otherwise, the server's current folder.

An absolute path always works, whatever the project folder is.

### In Claude Code

Installing the plugin is all it takes. The plugin's [`.mcp.json`](.mcp.json) has Claude Code start the server with
each session:

```json
"pbunit": {
  "command": "pwsh",
  "args": ["-NoLogo", "-NoProfile", "-NonInteractive", "-File", "${CLAUDE_PLUGIN_ROOT}/mcp/PBUnitMcpServer.ps1"]
}
```

The tools are named `mcp__plugin_pbunit_pbunit__<tool>`. Type `/mcp` in a session to see whether `pbunit` is
connected. The `run-tests` and `read-results` skills use the tools when they're available.

### In Claude Desktop and other MCP clients

Register the same command by hand, with the full path of a copy of the script:

- in a project that has the framework as a submodule, `tests\framework\plugins\pbunit\mcp\PBUnitMcpServer.ps1`
- in a clone of this repository, `plugins\pbunit\mcp\PBUnitMcpServer.ps1`
- if the plugin is installed in Claude Code, the copy it keeps up to date:
  `%USERPROFILE%\.claude\plugins\marketplaces\pbunit2025\plugins\pbunit\mcp\PBUnitMcpServer.ps1`

For **Claude Desktop**, open Settings > Developer > Edit Config, and add the server to `mcpServers` (keep the
rest of the file as it is):

```json
{
  "mcpServers": {
    "pbunit": {
      "command": "C:\\Program Files\\PowerShell\\7\\pwsh.exe",
      "args": ["-NoLogo", "-NoProfile", "-NonInteractive", "-File",
               "C:\\Users\\you\\.claude\\plugins\\marketplaces\\pbunit2025\\plugins\\pbunit\\mcp\\PBUnitMcpServer.ps1"],
      "env": { "PBUNIT_PROJECT_DIR": "C:\\Projects\\MySolution" }
    }
  }
}
```

Then quit Claude Desktop completely (from the system tray, not just by closing the window) and start it again.
The tools appear in a chat's tools menu. Use the full path to `pwsh.exe`, because Claude Desktop may not have the
same `PATH` as your shell. `PBUNIT_PROJECT_DIR` is optional; without it, ask for a project by its full path.
The Microsoft Store version of Claude Desktop keeps the file under
`%LOCALAPPDATA%\Claude-Data\<package>\claude_desktop_config.json`, not `%APPDATA%\Claude`. Edit Config opens the
right one.

For **VS Code** (Copilot agent mode), put the same entry in `.vscode/mcp.json` under `"servers"` instead of
`"mcpServers"`, with `"type": "stdio"`. Other clients that start stdio servers take the same command, arguments and
environment.

### Long runs and timeouts

A build takes a minute or more, and the whole suite can take several minutes. `run_tests` sends MCP progress
notifications while it waits; a client that doesn't use them to extend its request timeout may give up on a long
run. The tests themselves keep running, and `get_results` reads the results afterwards. A test that opens a
message box or a modal window hangs until `testTimeoutSeconds` runs out, and then the outcome is `TIMEOUT`.

### Troubleshooting

- The server writes its diagnostics to stderr, prefixed `[pbunit-mcp]`. Claude Code shows them with
  `claude --debug`; Claude Desktop writes them to `mcp-server-pbunit.log` in its logs folder.
- Run `pwsh -File plugins/pbunit/mcp/Test-PBUnitMcpServer.ps1` to test the server over stdio against this
  repository's self-test project, as a client would. Add `-SkipBuilds` for the checks that take a few seconds;
  the full run builds the self-tests and needs PowerBuilder 2025.

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
