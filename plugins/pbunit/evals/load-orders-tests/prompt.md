---
description: Write PBUnit tests for a service that retrieves a DataWindow, with no database. Checks that retrieves are counted through retrievestart on the production d_orders (a SQL source; an external copy never fires retrievestart), that nothing connects to a database, and that the expectations match what a cancelled retrieve returns.
tags: [write-tests, datawindow]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit]
---

This PowerBuilder 2025 solution uses the PBUnit2025 test framework, which is in tests\framework. Please add unit tests for n_cst_orderloader in src\orders.pbl. The build machine has no database, so the tests must not need one. Call the test class n_cst_orderloader_tests and put it in the library the test project uses for its tests. I'll build and run them myself later, so just write the files.
