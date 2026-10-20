//objectcomments Command-line test runner: runs registered test cases, writes text and JUnit XML results
forward
global type n_pbunit_runner from nonvisualobject
end type
end forward

global type n_pbunit_runner from nonvisualobject
end type
global n_pbunit_runner n_pbunit_runner

type prototypes
SUBROUTINE ExitProcess (ULong uExitCode) LIBRARY "kernel32.dll"
end prototypes

type variables
Public:
// Exit codes returned by of_Run.
constant integer EXIT_PASS = 0
constant integer EXIT_FAIL = 1
constant integer EXIT_ERROR = 2

Protected:
String	is_resultfile = "pbunit_results.txt"
String	is_junitfile = "pbunit_results.xml"
String	is_filters[]
String	is_problems[]
end variables

forward prototypes
public function integer of_run (string as_commandline)
public subroutine of_exit (integer ai_exitcode)
protected subroutine of_parsecommandline (string as_commandline)
protected function integer of_gettestclasses (ref string as_classes[])
protected subroutine of_runclass (string as_class, n_pbunit_result anv_result)
protected function boolean of_istestcase (classdefinition acd_class)
protected function boolean of_matchesfilter (string as_class, string as_test)
protected function boolean of_matchespattern (string as_value, string as_pattern)
protected function integer of_writetext (n_pbunit_result anv_result, string as_outcome)
protected function integer of_writejunit (n_pbunit_result anv_result)
protected function string of_xmlescape (string as_text)
protected function integer of_split (string as_text, string as_delimiter, ref string as_parts[])
end prototypes

public function integer of_run (string as_commandline);//////////////////////////////////////////////////////////////////////////////
//
//	Function:		of_Run
//
//	Arguments:		as_commandline	Usually CommandParm().  Supports
//						/out:<file>      text results  (default pbunit_results.txt)
//						/junit:<file>    JUnit XML     (default pbunit_results.xml)
//						/filter:<list>   comma-separated class or class.test
//						                 names; a trailing * matches a prefix
//
//	Returns:		EXIT_PASS, EXIT_FAIL, or EXIT_ERROR (no tests ran, or the
//					results could not be written).
//
//////////////////////////////////////////////////////////////////////////////
String				ls_classes[]
String				ls_outcome
Integer				li_i
Integer				li_exitcode
n_pbunit_result	lnv_result

of_ParseCommandLine(as_commandline)
lnv_result = create n_pbunit_result

of_GetTestClasses(ls_classes)
For li_i = 1 To UpperBound(ls_classes)
	of_RunClass(ls_classes[li_i], lnv_result)
Next

If lnv_result.of_GetCount() = 0 Then
	is_problems[UpperBound(is_problems) + 1] = "No tests ran."
End If

If UpperBound(is_problems) > 0 Then
	ls_outcome = "ERROR"
	li_exitcode = EXIT_ERROR
ElseIf lnv_result.of_GetCount(lnv_result.STATUS_PASS) = lnv_result.of_GetCount() Then
	ls_outcome = "PASS"
	li_exitcode = EXIT_PASS
Else
	ls_outcome = "FAIL"
	li_exitcode = EXIT_FAIL
End If

If of_WriteText(lnv_result, ls_outcome) <> 1 Then li_exitcode = EXIT_ERROR
If of_WriteJUnit(lnv_result) <> 1 Then li_exitcode = EXIT_ERROR

destroy lnv_result
Return li_exitcode
end function

public subroutine of_exit (integer ai_exitcode);// Ends the process with an exit code a build script can check.
// Call this last: nothing runs after it.
ExitProcess(ai_exitcode)
end subroutine

protected subroutine of_parsecommandline (string as_commandline);// Splits on spaces outside double quotes; quotes are removed.
String	ls_tokens[], ls_token, ls_char, ls_lower
Long		ll_i
Boolean	lb_quoted
Integer	li_t

For ll_i = 1 To Len(as_commandline)
	ls_char = Mid(as_commandline, ll_i, 1)
	If ls_char = '"' Then
		lb_quoted = Not lb_quoted
	ElseIf ls_char = " " And Not lb_quoted Then
		If ls_token <> "" Then ls_tokens[UpperBound(ls_tokens) + 1] = ls_token
		ls_token = ""
	Else
		ls_token += ls_char
	End If
Next
If ls_token <> "" Then ls_tokens[UpperBound(ls_tokens) + 1] = ls_token

For li_t = 1 To UpperBound(ls_tokens)
	ls_lower = Lower(ls_tokens[li_t])
	If Left(ls_lower, 5) = "/out:" Then
		is_resultfile = Mid(ls_tokens[li_t], 6)
	ElseIf Left(ls_lower, 7) = "/junit:" Then
		is_junitfile = Mid(ls_tokens[li_t], 8)
	ElseIf Left(ls_lower, 8) = "/filter:" Then
		of_Split(Mid(ls_tokens[li_t], 9), ",", is_filters)
	Else
		is_problems[UpperBound(is_problems) + 1] = "Unknown argument: " + ls_tokens[li_t]
	End If
Next
end subroutine

protected function integer of_gettestclasses (ref string as_classes[]);// The class list comes from n_pbunit_registry, which Invoke-PBUnit.ps1
// generates into the application's library before each build.
NonVisualObject	lnv_registry
String				ls_list

If Not IsValid(FindClassDefinition("n_pbunit_registry")) Then
	is_problems[UpperBound(is_problems) + 1] = "n_pbunit_registry not found. " + &
		"Build with Invoke-PBUnit.ps1, which generates it from the *tests classes."
	Return 0
End If

lnv_registry = create using "n_pbunit_registry"
ls_list = String(lnv_registry.Dynamic of_GetTestClasses())
destroy lnv_registry

Return of_Split(ls_list, ",", as_classes)
end function

protected subroutine of_runclass (string as_class, n_pbunit_result anv_result);ClassDefinition	lcd_class
ScriptDefinition	lsd_script
String				ls_tests[], ls_name
Integer				li_s, li_t
Boolean				lb_seen
TestCase				lnv_case

lcd_class = FindClassDefinition(as_class)
If Not IsValid(lcd_class) Then
	anv_result.of_AddRecord(as_class, "(class)", anv_result.STATUS_ERROR, "Class not found", 0)
	Return
End If
If Not of_IsTestCase(lcd_class) Then
	anv_result.of_AddRecord(as_class, "(class)", anv_result.STATUS_ERROR, "Class does not inherit from testcase", 0)
	Return
End If

// Tests are events whose names start with "test" and take no arguments.
For li_s = 1 To UpperBound(lcd_class.ScriptList)
	lsd_script = lcd_class.ScriptList[li_s]
	If lsd_script.Kind <> ScriptEvent! Then Continue
	If Lower(Left(lsd_script.Name, 4)) <> "test" Then Continue
	If UpperBound(lsd_script.ArgumentList) > 0 Then Continue

	ls_name = lsd_script.Name
	lb_seen = False
	For li_t = 1 To UpperBound(ls_tests)
		If ls_tests[li_t] = ls_name Then lb_seen = True
	Next
	If Not lb_seen Then ls_tests[UpperBound(ls_tests) + 1] = ls_name
Next

For li_t = 1 To UpperBound(ls_tests)
	If Not of_MatchesFilter(as_class, ls_tests[li_t]) Then Continue

	lnv_case = create using as_class
	lnv_case.initialize(ls_tests[li_t])
	lnv_case.run(anv_result)
	destroy lnv_case
Next
end subroutine

protected function boolean of_istestcase (classdefinition acd_class);ClassDefinition	lcd_ancestor

lcd_ancestor = acd_class.Ancestor
Do While IsValid(lcd_ancestor)
	If Lower(lcd_ancestor.Name) = "testcase" Then Return True
	lcd_ancestor = lcd_ancestor.Ancestor
Loop

Return False
end function

protected function boolean of_matchesfilter (string as_class, string as_test);Integer	li_f

If UpperBound(is_filters) = 0 Then Return True

For li_f = 1 To UpperBound(is_filters)
	If Pos(is_filters[li_f], ".") > 0 Then
		If of_MatchesPattern(as_class + "." + as_test, is_filters[li_f]) Then Return True
	Else
		If of_MatchesPattern(as_class, is_filters[li_f]) Then Return True
	End If
Next

Return False
end function

protected function boolean of_matchespattern (string as_value, string as_pattern);// Case-insensitive; a trailing * matches any suffix.
String	ls_value, ls_pattern

ls_value = Lower(Trim(as_value))
ls_pattern = Lower(Trim(as_pattern))

If Right(ls_pattern, 1) = "*" Then
	ls_pattern = Left(ls_pattern, Len(ls_pattern) - 1)
	Return Left(ls_value, Len(ls_pattern)) = ls_pattern
End If

Return ls_value = ls_pattern
end function

protected function integer of_writetext (n_pbunit_result anv_result, string as_outcome);String		ls_class, ls_test, ls_status, ls_messages, ls_lines[]
Decimal{3}	ldc_seconds
Long			ll_i, ll_m
Integer		li_file

li_file = FileOpen(is_resultfile, LineMode!, Write!, LockWrite!, Replace!, EncodingUTF8!)
If li_file < 0 Then Return -1

FileWrite(li_file, "RESULT: " + as_outcome)
FileWrite(li_file, String(anv_result.of_GetCount(anv_result.STATUS_PASS)) + " passed, " + &
	String(anv_result.of_GetCount(anv_result.STATUS_FAIL)) + " failed, " + &
	String(anv_result.of_GetCount(anv_result.STATUS_ERROR)) + " errors  (" + &
	String(Today(), "yyyy-mm-dd") + " " + String(Now(), "hh:mm:ss") + ")")
For ll_i = 1 To UpperBound(is_problems)
	FileWrite(li_file, "PROBLEM: " + is_problems[ll_i])
Next
FileWrite(li_file, "")

For ll_i = 1 To anv_result.of_GetCount()
	anv_result.of_GetRecord(ll_i, ls_class, ls_test, ls_status, ls_messages, ldc_seconds)
	FileWrite(li_file, Left(Upper(ls_status) + "     ", 6) + ls_class + "." + ls_test)
	of_Split(ls_messages, "~r~n", ls_lines)
	For ll_m = 1 To UpperBound(ls_lines)
		FileWrite(li_file, "        " + ls_lines[ll_m])
	Next
Next

FileClose(li_file)
Return 1
end function

protected function integer of_writejunit (n_pbunit_result anv_result);// JUnit XML, as read by GitHub Actions, Azure DevOps, Jenkins and others.
String		ls_class, ls_test, ls_status, ls_messages, ls_first[]
String		ls_suite, ls_lines[]
Decimal{3}	ldc_seconds, ldc_suite, ldc_total
Long			ll_i, ll_j, ll_count, ll_line
Long			ll_suitetests, ll_suitefail, ll_suiteerror
Integer		li_file

ll_count = anv_result.of_GetCount()
For ll_i = 1 To ll_count
	anv_result.of_GetRecord(ll_i, ls_class, ls_test, ls_status, ls_messages, ldc_seconds)
	ldc_total += ldc_seconds
Next

ll_line = 1
ls_lines[ll_line] = '<?xml version="1.0" encoding="UTF-8"?>'
ll_line ++
ls_lines[ll_line] = '<testsuites tests="' + String(ll_count) + '" failures="' + &
	String(anv_result.of_GetCount(anv_result.STATUS_FAIL)) + '" errors="' + &
	String(anv_result.of_GetCount(anv_result.STATUS_ERROR)) + '" time="' + String(ldc_total, "0.000") + '">'

// Records are grouped by class because each class's tests run together.
ll_i = 1
Do While ll_i <= ll_count
	anv_result.of_GetRecord(ll_i, ls_suite, ls_test, ls_status, ls_messages, ldc_seconds)
	ll_suitetests = 0; ll_suitefail = 0; ll_suiteerror = 0; ldc_suite = 0
	For ll_j = ll_i To ll_count
		anv_result.of_GetRecord(ll_j, ls_class, ls_test, ls_status, ls_messages, ldc_seconds)
		If ls_class <> ls_suite Then Exit
		ll_suitetests ++
		ldc_suite += ldc_seconds
		If ls_status = anv_result.STATUS_FAIL Then ll_suitefail ++
		If ls_status = anv_result.STATUS_ERROR Then ll_suiteerror ++
	Next

	ll_line ++
	ls_lines[ll_line] = '  <testsuite name="' + of_XmlEscape(ls_suite) + '" tests="' + String(ll_suitetests) + &
		'" failures="' + String(ll_suitefail) + '" errors="' + String(ll_suiteerror) + &
		'" time="' + String(ldc_suite, "0.000") + '">'

	For ll_j = ll_i To ll_i + ll_suitetests - 1
		anv_result.of_GetRecord(ll_j, ls_class, ls_test, ls_status, ls_messages, ldc_seconds)
		ll_line ++
		ls_lines[ll_line] = '    <testcase classname="' + of_XmlEscape(ls_class) + '" name="' + &
			of_XmlEscape(ls_test) + '" time="' + String(ldc_seconds, "0.000") + '"'
		If ls_status = anv_result.STATUS_PASS Then
			ls_lines[ll_line] += '/>'
		Else
			of_Split(ls_messages, "~r~n", ls_first)
			If UpperBound(ls_first) = 0 Then ls_first[1] = ""
			ls_lines[ll_line] += '>'
			ll_line ++
			If ls_status = anv_result.STATUS_ERROR Then
				ls_lines[ll_line] = '      <error message="' + of_XmlEscape(ls_first[1]) + '">' + &
					of_XmlEscape(ls_messages) + '</error>'
			Else
				ls_lines[ll_line] = '      <failure message="' + of_XmlEscape(ls_first[1]) + '">' + &
					of_XmlEscape(ls_messages) + '</failure>'
			End If
			ll_line ++
			ls_lines[ll_line] = '    </testcase>'
		End If
	Next

	ll_line ++
	ls_lines[ll_line] = '  </testsuite>'
	ll_i += ll_suitetests
Loop

ll_line ++
ls_lines[ll_line] = '</testsuites>'

li_file = FileOpen(is_junitfile, LineMode!, Write!, LockWrite!, Replace!, EncodingUTF8!)
If li_file < 0 Then Return -1
For ll_i = 1 To ll_line
	FileWrite(li_file, ls_lines[ll_i])
Next
FileClose(li_file)

Return 1
end function

protected function string of_xmlescape (string as_text);String	ls_result, ls_char
Long		ll_i

If IsNull(as_text) Then Return ""

For ll_i = 1 To Len(as_text)
	ls_char = Mid(as_text, ll_i, 1)
	Choose Case ls_char
		Case "&"
			ls_result += "&amp;"
		Case "<"
			ls_result += "&lt;"
		Case ">"
			ls_result += "&gt;"
		Case '"'
			ls_result += "&quot;"
		Case "~r"
			ls_result += "&#13;"
		Case "~n"
			ls_result += "&#10;"
		Case "~t"
			ls_result += "&#9;"
		Case Else
			ls_result += ls_char
	End Choose
Next

Return ls_result
end function

protected function integer of_split (string as_text, string as_delimiter, ref string as_parts[]);// Splits as_text on as_delimiter, trimming parts and dropping empty ones.
String	ls_empty[], ls_part
Long		ll_start, ll_pos

as_parts = ls_empty
If IsNull(as_text) Or as_text = "" Then Return 0

ll_start = 1
Do
	ll_pos = Pos(as_text, as_delimiter, ll_start)
	If ll_pos = 0 Then
		ls_part = Trim(Mid(as_text, ll_start))
	Else
		ls_part = Trim(Mid(as_text, ll_start, ll_pos - ll_start))
	End If
	If ls_part <> "" Then as_parts[UpperBound(as_parts) + 1] = ls_part
	ll_start = ll_pos + Len(as_delimiter)
Loop While ll_pos > 0

Return UpperBound(as_parts)
end function

on n_pbunit_runner.create
call super::create
TriggerEvent( this, "constructor" )
end on

on n_pbunit_runner.destroy
TriggerEvent( this, "destructor" )
call super::destroy
end on
