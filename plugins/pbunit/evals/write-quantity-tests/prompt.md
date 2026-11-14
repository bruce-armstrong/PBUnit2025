---
description: Write PBUnit tests for a class whose invalid-input path shows a message box. Checks the test file's structure, that no test can open the message box, the edge cases covered, and that the write-tests skill was used.
tags: [write-tests]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit]
---

This PowerBuilder 2025 solution uses the PBUnit2025 test framework, which is in tests\framework. Please add unit tests for n_cst_quantity in src\qty.pbl, covering of_SetRange and of_Clamp, including bad input. Call the test class n_cst_quantity_tests and put it in the library the test project uses for its tests. I'll build and run them myself later, so just write the files.
