//objectcomments Self-tests for the testcase assertions
forward
global type n_pbunit_assert_tests from testcase
end type
end forward

global type n_pbunit_assert_tests from testcase
event test_assertequals_string ( )
event test_assertequals_message_prefix ( )
event test_assertequals_nulls ( )
event test_assertequals_long ( )
event test_assertequals_decimal ( )
event test_assertequals_boolean ( )
event test_assertequals_date ( )
event test_assertequals_datetime ( )
event test_asserttrue_false_null ( )
event test_assertrowcount ( )
event test_assertthrows ( )
end type
global n_pbunit_assert_tests n_pbunit_assert_tests

type variables
Protected:
// Assertions under test run on inv_probe and are recorded in inv_inner,
// so a failing assertion there does not fail this test.
n_pbunit_probe_case	inv_probe
testresult				inv_inner
end variables

forward prototypes
protected function long of_failurecount ()
protected function string of_lastfailure ()
end prototypes

event setup;call super::setup;inv_inner = create testresult
inv_probe = create n_pbunit_probe_case
inv_probe.of_Attach(inv_inner)
end event

event teardown;call super::teardown;destroy inv_probe
destroy inv_inner
end event

event test_assertequals_string();assertTrue("equal strings should pass", inv_probe.assertEquals("abc", "abc"))
assertFalse("different strings should fail", inv_probe.assertEquals("abc", "abd"))

assertEquals(1, of_FailureCount())
assertEquals("expected <abc> but was <abd>", of_LastFailure())
end event

event test_assertequals_message_prefix();Long	ll_expected = 5, ll_actual = 6

inv_probe.assertEquals("Total", ll_expected, ll_actual)

assertEquals("Total: expected <5> but was <6>", of_LastFailure())
end event

event test_assertequals_nulls();Long		ll_null, ll_five = 5
String	ls_null

SetNull(ll_null)
SetNull(ls_null)

assertTrue("null = null should pass", inv_probe.assertEquals(ll_null, ll_null))
assertFalse("null vs 5 should fail", inv_probe.assertEquals(ll_null, ll_five))
assertEquals("expected <null> but was <5>", of_LastFailure())

assertFalse("'x' vs null should fail", inv_probe.assertEquals("x", ls_null))
assertEquals("expected <x> but was <null>", of_LastFailure())
end event

event test_assertequals_long();Long	ll_ten = 10, ll_twenty = 20

assertTrue(inv_probe.assertEquals(ll_ten, ll_ten))
assertFalse(inv_probe.assertEquals(ll_ten, ll_twenty))
assertEquals("expected <10> but was <20>", of_LastFailure())
end event

event test_assertequals_decimal();Decimal	ldc_a = 1.5, ldc_b = 1.50, ldc_c = 2.25

assertTrue("1.5 = 1.50 should pass", inv_probe.assertEquals(ldc_a, ldc_b))
assertFalse(inv_probe.assertEquals(ldc_a, ldc_c))
assertEquals("expected <1.5> but was <2.25>", of_LastFailure())
end event

event test_assertequals_boolean();Boolean	lb_true = True, lb_false = False

assertTrue(inv_probe.assertEquals(lb_true, lb_true))
assertFalse(inv_probe.assertEquals(lb_true, lb_false))
assertEquals("expected <true> but was <false>", Lower(of_LastFailure()))
end event

event test_assertequals_date();Date	ld_a, ld_b

ld_a = Date(2026, 10, 20)
ld_b = Date(2026, 10, 21)

assertTrue(inv_probe.assertEquals(ld_a, ld_a))
assertFalse(inv_probe.assertEquals(ld_a, ld_b))
assertEquals("expected <2026-10-20> but was <2026-10-21>", of_LastFailure())
end event

event test_assertequals_datetime();DateTime	ldt_a, ldt_b

ldt_a = DateTime(Date(2026, 10, 20), Time(1, 2, 3))
ldt_b = DateTime(Date(2026, 10, 20), Time(1, 2, 4))

assertTrue(inv_probe.assertEquals(ldt_a, ldt_a))
assertFalse(inv_probe.assertEquals(ldt_a, ldt_b))
assertEquals("expected <2026-10-20 01:02:03.000000> but was <2026-10-20 01:02:04.000000>", of_LastFailure())
end event

event test_asserttrue_false_null();Long	ll_null, ll_five = 5

SetNull(ll_null)

assertFalse(inv_probe.assertTrue(False))
assertEquals("Expected true", of_LastFailure())

assertFalse(inv_probe.assertFalse(True))
assertEquals("Expected false", of_LastFailure())

assertTrue(inv_probe.assertNull(ll_null))
assertFalse(inv_probe.assertNull(ll_five))
assertEquals("Value is not null", of_LastFailure())

assertEquals(3, of_FailureCount())
end event

event test_assertrowcount();DataStore	lds_empty

lds_empty = create DataStore

assertTrue(inv_probe.assertRowCount(lds_empty, 0))
assertFalse(inv_probe.assertRowCount(lds_empty, 2))
assertEquals("datastore row count: expected <2> but was <0>", Lower(of_LastFailure()))

destroy lds_empty
end event

event test_assertthrows();assertTrue("a runtime error should satisfy assertThrows", inv_probe.assertThrows("throws_error"))

assertFalse(inv_probe.assertThrows("throws_nothing"))
assertEquals("Expected event throws_nothing to throw", of_LastFailure())

assertFalse(inv_probe.assertThrows("no_such_event"))
assertEquals("assertThrows: event no_such_event was not found", of_LastFailure())
end event

protected function long of_failurecount ();Return inv_inner.numberOfFailures()
end function

protected function string of_lastfailure ();TestFailure	lnv_failure
Integer		li_count

li_count = inv_inner.numberOfFailures()
If li_count = 0 Then Return "(no failure recorded)"

lnv_failure = inv_inner.failures().at(li_count)
Return lnv_failure.getErrorMessage()
end function

on n_pbunit_assert_tests.create
call super::create
end on

on n_pbunit_assert_tests.destroy
call super::destroy
end on
