---
type: regex
target:
  source: file
  path: tests/qtytests.pbl/n_cst_quantity_tests.sru
pattern: 'on n_cst_quantity_tests\.create\r?\ncall super::create\r?\nend on\r?\n\r?\non n_cst_quantity_tests\.destroy\r?\ncall super::destroy\r?\nend on'
---
