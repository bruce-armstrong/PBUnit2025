//objectcomments Test result that records every test's outcome and time, and traps runtime errors
forward
global type n_pbunit_result from testresult
end type
end forward

global type n_pbunit_result from testresult
end type
global n_pbunit_result n_pbunit_result

type variables
Public:
constant string STATUS_PASS = "pass"
constant string STATUS_FAIL = "fail"
constant string STATUS_ERROR = "error"

Protected:
// One entry per test run, in run order.
String		is_class[]
String		is_test[]
String		is_status[]
String		is_messages[]
Decimal{3}	idc_seconds[]

// The test currently running.
String		is_currentstatus
String		is_currentmessages
end variables

forward prototypes
public subroutine run (testcase anv_test)
public subroutine addfailure (test anv_test, string as_errormessage)
public subroutine adderror (test anv_test, string as_errormessage)
public subroutine of_addrecord (string as_class, string as_test, string as_status, string as_messages, decimal adc_seconds)
public function long of_getcount ()
public function integer of_getrecord (long al_index, ref string as_class, ref string as_test, ref string as_status, ref string as_messages, ref decimal adc_seconds)
public function long of_getcount (string as_status)
end prototypes

public subroutine run (testcase anv_test);//////////////////////////////////////////////////////////////////////////////
//
//	Function:		run
//
//	Description:	Runs one test, turning any exception (including PowerBuilder
//					runtime errors) into a test error, and records the outcome.
//
//////////////////////////////////////////////////////////////////////////////
Long	ll_start

is_currentstatus = STATUS_PASS
is_currentmessages = ""
ll_start = CPU()

Try
	super::run(anv_test)
Catch (RuntimeError lre_error)
	this.addError(anv_test, "Runtime error " + String(lre_error.Number) + ": " + &
		lre_error.GetMessage() + " [" + lre_error.ObjectName + "." + &
		lre_error.RoutineName + " line " + String(lre_error.Line) + "]")
	Try
		anv_test.Event teardown()
	Catch (Throwable lth_teardown)
	End Try
Catch (Throwable lth_error)
	this.addError(anv_test, lth_error.ClassName() + ": " + lth_error.GetMessage())
	Try
		anv_test.Event teardown()
	Catch (Throwable lth_teardown2)
	End Try
End Try

of_AddRecord(anv_test.ClassName(), anv_test.name(), is_currentstatus, is_currentmessages, &
	(CPU() - ll_start) / 1000.000)
end subroutine

public subroutine addfailure (test anv_test, string as_errormessage);super::addFailure(anv_test, as_errormessage)

If is_currentstatus = STATUS_PASS Then is_currentstatus = STATUS_FAIL
If Len(is_currentmessages) > 0 Then is_currentmessages += "~r~n"
is_currentmessages += as_errormessage
end subroutine

public subroutine adderror (test anv_test, string as_errormessage);super::addError(anv_test, as_errormessage)

is_currentstatus = STATUS_ERROR
If Len(is_currentmessages) > 0 Then is_currentmessages += "~r~n"
is_currentmessages += as_errormessage
end subroutine

public subroutine of_addrecord (string as_class, string as_test, string as_status, string as_messages, decimal adc_seconds);// Also used by the runner to report problems that are not a single test,
// such as a class that is not a test case.
Long	ll_index

ll_index = UpperBound(is_class) + 1
is_class[ll_index] = as_class
is_test[ll_index] = as_test
is_status[ll_index] = as_status
is_messages[ll_index] = as_messages
idc_seconds[ll_index] = adc_seconds
end subroutine

public function long of_getcount ();Return UpperBound(is_class)
end function

public function integer of_getrecord (long al_index, ref string as_class, ref string as_test, ref string as_status, ref string as_messages, ref decimal adc_seconds);If al_index < 1 Or al_index > UpperBound(is_class) Then Return -1

as_class = is_class[al_index]
as_test = is_test[al_index]
as_status = is_status[al_index]
as_messages = is_messages[al_index]
adc_seconds = idc_seconds[al_index]

Return 1
end function

public function long of_getcount (string as_status);Long	ll_i, ll_count

For ll_i = 1 To UpperBound(is_status)
	If is_status[ll_i] = as_status Then ll_count ++
Next

Return ll_count
end function

on n_pbunit_result.create
call super::create
end on

on n_pbunit_result.destroy
call super::destroy
end on
