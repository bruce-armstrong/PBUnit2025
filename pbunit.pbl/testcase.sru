//objectcomments A test case defines the fixture to run multiple tests.
forward
global type testcase from test
end type
end forward

global type testcase from test
event setup ( )
event teardown ( )
event runtest ( )
end type
global testcase testcase

type variables
Protected TestResult inv_result
Protected String is_name
Private Boolean ib_stop
Private Boolean ib_error
end variables

forward prototypes
public subroutine runbare ()
public subroutine initialize (string as_name)
public function string tostring ()
public subroutine run (TestResult anv_result)
public subroutine fail (string as_message)
public function integer counttestcases ()
protected function testresult createresult ()
protected function testresult getresult ()
public function string name ()
public function testresult run ()
public subroutine stop ()
public function boolean shouldstop ()
public subroutine error (error anv_error)
public function boolean error ()
public function Test suite ()
public function boolean assert (boolean ab_condition)
public function boolean assert (string as_message, boolean ab_condition)
public function boolean assertisvalid (string as_message, powerobject apo_object)
public function boolean assertisvalid (powerobject apo_object)
public function boolean assertnotnull (string as_message, any aa_value)
public function boolean assertnotnull (any aa_value)
public function boolean asserttrue (boolean ab_condition)
public function boolean asserttrue (string as_message, boolean ab_condition)
public function boolean assertfalse (boolean ab_condition)
public function boolean assertfalse (string as_message, boolean ab_condition)
public function boolean assertnull (any aa_value)
public function boolean assertnull (string as_message, any aa_value)
public function boolean assertequals (string as_expected, string as_actual)
public function boolean assertequals (string as_message, string as_expected, string as_actual)
public function boolean assertequals (long al_expected, long al_actual)
public function boolean assertequals (string as_message, long al_expected, long al_actual)
public function boolean assertequals (decimal adc_expected, decimal adc_actual)
public function boolean assertequals (string as_message, decimal adc_expected, decimal adc_actual)
public function boolean assertequals (boolean ab_expected, boolean ab_actual)
public function boolean assertequals (string as_message, boolean ab_expected, boolean ab_actual)
public function boolean assertequals (date ad_expected, date ad_actual)
public function boolean assertequals (string as_message, date ad_expected, date ad_actual)
public function boolean assertequals (datetime adt_expected, datetime adt_actual)
public function boolean assertequals (string as_message, datetime adt_expected, datetime adt_actual)
public function boolean assertrowcount (datawindow adw_target, long al_expected)
public function boolean assertrowcount (datastore ads_target, long al_expected)
public function boolean assertthrows (string as_eventname)
public function boolean assertthrows (string as_message, string as_eventname)
protected function boolean of_comparison (string as_message, boolean ab_equal, string as_expected, string as_actual)
end prototypes

event runtest;if triggerEvent(is_name) = -1 and not error() then
	fail("Test " + is_name + " was not found.")
end if
end event

public subroutine runbare ();this.event setUp()
this.event runTest()
this.event tearDown()
end subroutine

public subroutine initialize (string as_name);is_name = as_name
end subroutine

public function string tostring ();return super::toString() + "." + is_name
end function

public subroutine run (TestResult anv_result);inv_result = anv_result
anv_result.run(this)
setNull(inv_result)
end subroutine

public subroutine fail (string as_message);if isValid(inv_result) then
	inv_result.addFailure(this, as_message)
end if
end subroutine

public function integer counttestcases ();return 1
end function

protected function testresult createresult ();TestResult theResult

theResult = create TestResult
return theResult

end function

protected function testresult getresult ();return inv_result
end function

public function string name ();return is_name
end function

public function testresult run ();TestResult theResult 

theResult = createResult()
run(theResult)
return theResult
end function

public subroutine stop ();ib_stop = true
end subroutine

public function boolean shouldstop ();return ib_stop
end function

public subroutine error (error anv_error);String	ls_message

ib_error = true

if isValid(inv_result) and isValid(anv_error) then
	ls_message = "Error Number " + string(anv_error.number) + & 
					 ".~r~nError text = " + anv_error.text + &
					 ".~r~nWindow/Menu/Object = " + anv_error.windowMenu + &
					 ".~r~nError Object/Control = " + anv_error.object + &
					 ".~r~nScript = " + anv_error.objectEvent + &
					 ".~r~nLine in Script = " + string(anv_error.line) + "."
	inv_result.addError(this, ls_message)
end if
end subroutine

public function boolean error ();return ib_error
end function

public function Test suite ();TestSuite	lnv_suite

lnv_suite = create TestSuite
lnv_suite.initialize(className())
return lnv_suite
end function

public function boolean assert (boolean ab_condition);assert("Condition failed", ab_condition)
return ab_condition
end function

public function boolean assert (string as_message, boolean ab_condition);if ab_condition then
else
	fail(as_message)
end if

return ab_condition
end function

public function boolean assertisvalid (string as_message, powerobject apo_object);if isValid(apo_object) then
	return true
end if

fail(as_message)

return false
end function

public function boolean assertisvalid (powerobject apo_object);return assertIsValid("Object is not valid", apo_object)
end function

public function boolean assertnotnull (string as_message, any aa_value);if isNull(aa_value) then
	fail(as_message)
	return false
end if

return true
end function

public function boolean assertnotnull (any aa_value);return assertNotNull("Value is null", aa_value)
end function

public function boolean asserttrue (boolean ab_condition);return assertTrue("Expected true", ab_condition)
end function

public function boolean asserttrue (string as_message, boolean ab_condition);if ab_condition = true then return true

fail(as_message)
return false
end function

public function boolean assertfalse (boolean ab_condition);return assertFalse("Expected false", ab_condition)
end function

public function boolean assertfalse (string as_message, boolean ab_condition);if ab_condition = false then return true

fail(as_message)
return false
end function

public function boolean assertnull (any aa_value);return assertNull("Value is not null", aa_value)
end function

public function boolean assertnull (string as_message, any aa_value);if isNull(aa_value) then return true

fail(as_message)
return false
end function

protected function boolean of_comparison (string as_message, boolean ab_equal, string as_expected, string as_actual);// Shared by the assertEquals overloads: records "expected <x> but was <y>".
String	ls_message

if ab_equal then return true

ls_message = "expected <" + as_expected + "> but was <" + as_actual + ">"
if len(as_message) > 0 then ls_message = as_message + ": " + ls_message

fail(ls_message)
return false
end function

public function boolean assertequals (string as_expected, string as_actual);return assertEquals("", as_expected, as_actual)
end function

public function boolean assertequals (string as_message, string as_expected, string as_actual);Boolean	lb_equal
String	ls_expected = "null", ls_actual = "null"

if isNull(as_expected) or isNull(as_actual) then
	lb_equal = isNull(as_expected) and isNull(as_actual)
else
	lb_equal = (as_expected = as_actual)
end if
if not isNull(as_expected) then ls_expected = as_expected
if not isNull(as_actual) then ls_actual = as_actual

return of_comparison(as_message, lb_equal, ls_expected, ls_actual)
end function

public function boolean assertequals (long al_expected, long al_actual);return assertEquals("", al_expected, al_actual)
end function

public function boolean assertequals (string as_message, long al_expected, long al_actual);Boolean	lb_equal
String	ls_expected = "null", ls_actual = "null"

if isNull(al_expected) or isNull(al_actual) then
	lb_equal = isNull(al_expected) and isNull(al_actual)
else
	lb_equal = (al_expected = al_actual)
end if
if not isNull(al_expected) then ls_expected = string(al_expected)
if not isNull(al_actual) then ls_actual = string(al_actual)

return of_comparison(as_message, lb_equal, ls_expected, ls_actual)
end function

public function boolean assertequals (decimal adc_expected, decimal adc_actual);return assertEquals("", adc_expected, adc_actual)
end function

public function boolean assertequals (string as_message, decimal adc_expected, decimal adc_actual);Boolean	lb_equal
String	ls_expected = "null", ls_actual = "null"

if isNull(adc_expected) or isNull(adc_actual) then
	lb_equal = isNull(adc_expected) and isNull(adc_actual)
else
	lb_equal = (adc_expected = adc_actual)
end if
if not isNull(adc_expected) then ls_expected = string(adc_expected)
if not isNull(adc_actual) then ls_actual = string(adc_actual)

return of_comparison(as_message, lb_equal, ls_expected, ls_actual)
end function

public function boolean assertequals (boolean ab_expected, boolean ab_actual);return assertEquals("", ab_expected, ab_actual)
end function

public function boolean assertequals (string as_message, boolean ab_expected, boolean ab_actual);Boolean	lb_equal
String	ls_expected = "null", ls_actual = "null"

if isNull(ab_expected) or isNull(ab_actual) then
	lb_equal = isNull(ab_expected) and isNull(ab_actual)
else
	lb_equal = (ab_expected = ab_actual)
end if
if not isNull(ab_expected) then ls_expected = string(ab_expected)
if not isNull(ab_actual) then ls_actual = string(ab_actual)

return of_comparison(as_message, lb_equal, ls_expected, ls_actual)
end function

public function boolean assertequals (date ad_expected, date ad_actual);return assertEquals("", ad_expected, ad_actual)
end function

public function boolean assertequals (string as_message, date ad_expected, date ad_actual);Boolean	lb_equal
String	ls_expected = "null", ls_actual = "null"

if isNull(ad_expected) or isNull(ad_actual) then
	lb_equal = isNull(ad_expected) and isNull(ad_actual)
else
	lb_equal = (ad_expected = ad_actual)
end if
if not isNull(ad_expected) then ls_expected = string(ad_expected, "yyyy-mm-dd")
if not isNull(ad_actual) then ls_actual = string(ad_actual, "yyyy-mm-dd")

return of_comparison(as_message, lb_equal, ls_expected, ls_actual)
end function

public function boolean assertequals (datetime adt_expected, datetime adt_actual);return assertEquals("", adt_expected, adt_actual)
end function

public function boolean assertequals (string as_message, datetime adt_expected, datetime adt_actual);Boolean	lb_equal
String	ls_expected = "null", ls_actual = "null"

if isNull(adt_expected) or isNull(adt_actual) then
	lb_equal = isNull(adt_expected) and isNull(adt_actual)
else
	lb_equal = (adt_expected = adt_actual)
end if
if not isNull(adt_expected) then ls_expected = string(adt_expected, "yyyy-mm-dd hh:mm:ss.ffffff")
if not isNull(adt_actual) then ls_actual = string(adt_actual, "yyyy-mm-dd hh:mm:ss.ffffff")

return of_comparison(as_message, lb_equal, ls_expected, ls_actual)
end function

public function boolean assertrowcount (datawindow adw_target, long al_expected);if not isValid(adw_target) then
	fail("assertRowCount: DataWindow is not valid")
	return false
end if

return assertEquals(adw_target.ClassName() + " row count", al_expected, adw_target.RowCount())
end function

public function boolean assertrowcount (datastore ads_target, long al_expected);if not isValid(ads_target) then
	fail("assertRowCount: DataStore is not valid")
	return false
end if

return assertEquals(ads_target.ClassName() + " row count", al_expected, ads_target.RowCount())
end function

public function boolean assertthrows (string as_eventname);return assertThrows("Expected event " + as_eventname + " to throw", as_eventname)
end function

public function boolean assertthrows (string as_message, string as_eventname);// Triggers the named event (declared on the test case, no arguments) and
// passes if it throws.  PowerScript has no closures, so the code expected
// to throw goes in its own event.
Integer	li_rc

try
	li_rc = this.TriggerEvent(as_eventname)
catch (Throwable lth_expected)
	return true
end try

if li_rc = -1 then
	fail("assertThrows: event " + as_eventname + " was not found")
else
	fail(as_message)
end if
return false
end function

on testcase.create
TriggerEvent( this, "constructor" )
end on

on testcase.destroy
TriggerEvent( this, "destructor" )
end on

event constructor;call super::constructor;setNull(inv_result)
ib_stop = false
end event

