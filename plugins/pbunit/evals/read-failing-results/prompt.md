---
description: Interpret a failing PBUnit run. Three groups of failures with different causes - 27 tests that need configuration (environment), a runtime error inside the PFC linkage service (code), and every test in one class failing in the test class's own setup (fixture). Checks that each is classified correctly and nothing is "fixed" by weakening tests.
tags: [read-results]
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

I made some changes to PFC and ran the unit tests with tests\run_tests.ps1. It says FAIL, and the results are in build\pfc_tests. What went wrong, and what should I do about it? Don't change anything yet, just tell me.
