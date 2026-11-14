# PBUnit assertions

All assertions are functions on `testcase`, so a test calls them directly. Each returns `true` if it
passed and records a failure (without stopping the test) if not. Use the return value to stop early:

```
If Not assertEquals("window opened", 1, li_rc) Then Return
```

## assertEquals

| Overloads | Failure text |
|---|---|
| `assertEquals(string expected, string actual)` | `expected <abc> but was <abd>` |
| `assertEquals(string message, string expected, string actual)` | `message: expected <abc> but was <abd>` |
| the same two forms for `long`, `decimal`, `boolean`, `date`, `datetime` | dates `yyyy-mm-dd`, datetimes `yyyy-mm-dd hh:mm:ss.ffffff` |

- Two nulls are equal; a null and a value are not. A null shows as `null`, so `"null"` the string and a
  null string look the same in the message.
- Integer arguments and literals (`1`, `li_count`) use the `long` overload.
- For `decimal`, declare `Decimal` variables rather than passing literals such as `1.5`, so the
  `decimal` overload is chosen.
- For a type with no overload (`time`, `double`, `real`, `blob`, `any`), convert both sides yourself,
  for example `assertEquals("time", "13:45:00", String(lt_time, "hh:mm:ss"))`, or compare with
  `assertTrue("label", ld_a = ld_b)`.
- For `ulong`, `longlong` and other numeric types, assign the value to a `Long` (if it fits) or compare
  `String(...)` of both sides, so the overload is unambiguous.
- The message argument comes **first**. `assertEquals(1, li_rc, "label")` doesn't compile.

## Other assertions

| Assertion | Passes when | Failure text |
|---|---|---|
| `assertTrue([message,] boolean)` | the value is `true` | `Expected true` or the message |
| `assertFalse([message,] boolean)` | the value is `false` | `Expected false` or the message |
| `assertNull([message,] any)` | `IsNull(value)` | `Value is not null` or the message |
| `assertNotNull([message,] any)` | not null | `Value is null` or the message |
| `assertIsValid([message,] powerobject)` | `IsValid(object)` | `Object is not valid` or the message |
| `assertRowCount(datawindow, long)` / `assertRowCount(datastore, long)` | `RowCount()` equals the count | `<classname> row count: expected <2> but was <0>` |
| `assertThrows([message,] string eventname)` | the named event throws, including a PowerBuilder runtime error | `Expected event <name> to throw`, or `assertThrows: event <name> was not found` |
| `assert([message,] boolean)` | the value is `true` | `Condition failed` or the message |
| `fail(message)` | never: records the message as a failure | the message |

A `null` boolean fails both `assertTrue` and `assertFalse`.

## assertThrows

PowerScript has no closures, so the code that should throw goes in its own event on the test class, with
no arguments. Do **not** start that event's name with `test`, or it also runs as a test:

```
//objectcomments Unit tests for n_cst_parser
forward
global type n_cst_parser_tests from testcase
end type
end forward

global type n_cst_parser_tests from testcase
event test_rejects_empty_input ( )
event parse_empty ( )
end type
global n_cst_parser_tests n_cst_parser_tests

event test_rejects_empty_input();// An empty string is an error, not an empty result.
assertThrows("empty input", "parse_empty")
end event

event parse_empty();n_cst_parser	lnv_parser

lnv_parser = Create n_cst_parser
lnv_parser.of_Parse("")
end event

on n_cst_parser_tests.create
call super::create
end on

on n_cst_parser_tests.destroy
call super::destroy
end on
```

The parser that `parse_empty` creates isn't destroyed when `of_Parse` throws. That's harmless in a test;
to clean it up, keep it in an instance variable and destroy it in `teardown`.

## Errors versus failures

An assertion that doesn't hold is a **failure** (FAIL). An exception or PowerBuilder runtime error that
escapes a test, `setup` or `teardown` is an **error** (ERROR), reported with the error number, message,
object, routine and line. The run continues with the next test either way.
