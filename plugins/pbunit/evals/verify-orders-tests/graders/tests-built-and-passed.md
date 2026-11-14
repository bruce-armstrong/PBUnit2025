---
type: regex
weight: 3
# Written by the test exe (not the agent), as UTF-8 with a byte order mark, when run_tests or Invoke-PBUnit.ps1 runs the tests.
target:
  source: file
  path: build/orders_tests/results.txt
pattern: '^\uFEFF?RESULT: PASS[\s\S]*^PASS\s+n_cst_orderloader_tests\.'
flags: m
---
