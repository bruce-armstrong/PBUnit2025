# PowerScript source format for test objects

PowerBuilder 2025 solutions store each object as a text file in its library folder. The compiler is strict
about the layout, so copy the skeletons here (or an existing object of the same kind) rather than writing
from memory.

## File rules

- Encoding UTF-8 **with** a byte order mark, and CRLF line endings. If you create or edit the file with a
  tool that writes plain UTF-8 or LF line endings, convert it afterwards in PowerShell:

  ```powershell
  $path = "C:\path\to\n_cst_example_tests.sru"
  $text = [IO.File]::ReadAllText($path) -replace "`r?`n", "`r`n"
  [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($true)))
  ```
- One object per file. The file name is the object name plus its extension: `.sru` user object (including
  test classes), `.srw` window, `.srd` DataWindow, `.srf` function, `.sra` application.
- Put new test objects in the test project's `AppEntry` library folder. Don't create a new library unless
  asked: it also needs a `<name>.pblmeta` file and an entry in the `.pbproj`.

## Test class skeleton

```
//objectcomments Unit tests for n_cst_example (what they cover; no database needed)
forward
global type n_cst_example_tests from testcase
end type
end forward

global type n_cst_example_tests from testcase
event test_returns_1_for_valid_input ( )
event test_rejects_null ( )
end type
global n_cst_example_tests n_cst_example_tests

type variables
Protected:
n_cst_example	inv_example
end variables

forward prototypes
protected function integer of_helper (string as_value)
end prototypes

event setup;call super::setup;inv_example = Create n_cst_example
end event

event teardown;call super::teardown;If IsValid(inv_example) Then Destroy inv_example
end event

event test_returns_1_for_valid_input();// A valid value is accepted.
assertEquals("valid", 1, inv_example.of_SetValue("abc"))
assertEquals("stored", "abc", inv_example.of_GetValue())
end event

event test_rejects_null();// Null is rejected and the value is kept.
string	ls_null

SetNull(ls_null)
assertEquals("null", -1, inv_example.of_SetValue(ls_null))
end event

protected function integer of_helper (string as_value);Return Len(as_value)
end function

on n_cst_example_tests.create
call super::create
end on

on n_cst_example_tests.destroy
call super::destroy
end on
```

## Section order and syntax

1. `//objectcomments <text>` (optional, first line).
2. `forward` block: only `global type <name> from <ancestor>` / `end type`. Never put events, variables or
   properties here.
3. The main `global type <name> from <ancestor>` block: property settings (windows: `integer width = 2400`,
   `boolean visible = false`) and the declarations of new user events, `event name ( )` or
   `event type integer name ( long al_row )`. Then `global <name> <name>`.
4. Optional `type prototypes` ... `end prototypes` for external (DLL) functions.
5. Optional `type variables` ... `end variables`: access labels `Public:`, `Protected:`, `Private:` on their
   own lines; constants as `constant string NAME = "value"`.
6. `forward prototypes` ... `end prototypes`: one line per function or subroutine, matching its header
   exactly, e.g. `public function string of_name (long al_id)`. Omit the block if there are none.
7. Scripts, in any order:
   - An event declared in **this** object: `event test_x();<first statement>` ... `end event`.
   - An event inherited from the ancestor, **extending** it (ancestor script runs first):
     `event setup;call super::setup;<first statement>` ... `end event`.
   - An inherited event **overriding** it (ancestor script doesn't run): `event pfc_print;<first statement>`.
     In an extended event, `AncestorReturnValue` holds the ancestor's return value.
   - Functions: `public function integer of_x (long al_value);<first statement>` ... `end function`;
     subroutines end with `end subroutine`.
   The first statement goes on the header line, straight after the semicolon.
8. `on <name>.create` and `on <name>.destroy` blocks, last. Copy them from a sibling of the same kind:
   - a descendant of `testcase`, a window, a visual user object, or any user-defined class: `call super::create` /
     `call super::destroy`;
   - a direct descendant of `nonvisualobject`: `call super::create` then `TriggerEvent( this, "constructor" )`,
     and `TriggerEvent( this, "destructor" )` then `call super::destroy`.

PowerScript reminders: `&` continues a statement on the next line; `~r~n`, `~t` and `~"` are escapes inside
strings; strings can use `"` or `'`; `//` and `/* */` comments; one-line `If x Then statement`.

## Helper object skeletons

Test descendant that exposes protected functions (`.sru`):

```
//objectcomments Exposes protected n_cst_example functions to the example tests
forward
global type n_pfctest_example from n_cst_example
end type
end forward

global type n_pfctest_example from n_cst_example
end type
global n_pfctest_example n_pfctest_example

forward prototypes
public function integer of_parsefortest (string as_text)
end prototypes

public function integer of_parsefortest (string as_text);Return of_Parse(as_text)
end function

on n_pfctest_example.create
call super::create
end on

on n_pfctest_example.destroy
call super::destroy
end on
```

Hidden host window (`.srw`). Inherit from the window class the code expects (for PFC services, `w_master`
or a descendant; for a plain DataWindow host, `window`):

```
//objectcomments Hidden window that hosts visual controls created by unit tests
forward
global type w_pfctest_host from window
end type
end forward

global type w_pfctest_host from window
integer width = 2400
integer height = 1400
boolean visible = false
boolean titlebar = true
string title = "Unit test host"
boolean controlmenu = true
long backcolor = 67108864
end type
global w_pfctest_host w_pfctest_host

on w_pfctest_host.create
end on

on w_pfctest_host.destroy
end on
```

A window that inherits from `window` directly has empty `create`/`destroy` blocks, as above. Don't declare
controls in window source; create them at run time with `OpenUserObject` (see test-doubles.md).

## DataWindow objects (.srd)

Copy an existing `.srd` from the test library and change its columns; writing the syntax from scratch is
error-prone. A minimal external DataWindow with one `long` column:

```
//objectcomments Unit test DataWindow (external)
release 6;
datawindow(units=0 timer_interval=0 color=1090519039 processing=0 HTMLDW=no print.documentname="" print.orientation = 0 print.margin.left = 110 print.margin.right = 110 print.margin.top = 97 print.margin.bottom = 97 print.paper.source = 0 print.paper.size = 0 print.prompt=no print.buttons=no print.preview.buttons=no )
summary(height=0 color="536870912" )
footer(height=0 color="536870912" )
detail(height=58 color="536870912" )
table(column=(type=long updatewhereclause=yes name=id dbname="id" )
 )
column(band=detail id=1 alignment="1" tabsequence=10 border="0" color="33554432" x="4" y="3" height="51" width="400" format="[general]"  name=id edit.limit=0 edit.case=any edit.focusrectangle=no edit.autoselect=no  font.face="MS Sans Serif" font.height="-8" font.weight="400"  font.family="2" font.pitch="2" font.charset="0" background.mode="2" background.color="1090519039" )
htmltable(border="0" )
htmlgen(clientevents="1" clientvalidation="1" clientcomputedfields="1" clientformatting="0" clientscriptable="0" generatejavascript="1" )
```

- Column types: `long`, `char(n)`, `decimal(n)`, `date`, `datetime`, `number`.
- Retrieval arguments need a SQL source: `retrieve="SELECT ... WHERE id = :a_id" arguments=(("a_id", number))`
  inside `table(...)`. Tests never let that SQL run; see the retrieve probe in test-doubles.md.
- Load rows in a test with `InsertRow` and `SetItem`, then `ResetUpdate()` if the rows must look retrieved.
