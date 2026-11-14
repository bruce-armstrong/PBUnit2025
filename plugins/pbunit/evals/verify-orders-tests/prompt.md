---
description: Write PBUnit tests for a DataStore loader with no database, then build and run them. With the plugin the agent has the pbunit MCP tools (run_tests, check_source); without it there is no way to build. Graded on the results file the test exe writes (all tests passed, including the new class) and on what the tests prove.
tags: [write-tests, run-tests, mcp]
max_turns: 60
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit]
---

This PowerBuilder 2025 solution uses the PBUnit2025 test framework, which is in tests\framework. Please add unit tests for n_cst_orderloader in src\orders.pbl. The build machine has no database, so the tests must not need one. Call the test class n_cst_orderloader_tests and put it in the library the test project uses for its tests. Then build and run the tests, and make sure they pass before you finish.
