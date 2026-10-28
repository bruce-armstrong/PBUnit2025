//objectcomments A TestResult collects the results of executing a test case. It is an instance of the Collecting Parameter pattern.  The test framework distinguishes between failures and errors. A failure is anticipated and checked for.
forward
global type testresult from testobject
end type
end forward

shared variables
Test currentTestCase
end variables

global type testresult from testobject
event starttest ( test anv_test )
event endtest ( test anv_test )
end type
global testresult testresult

type variables
Protected pbunit_Collection inv_failureCollection
Protected pbunit_Collection inv_errorCollection
Protected Integer ii_numberOfTestsRun = 0
Private Boolean ib_stop = false

end variables

forward prototypes
public subroutine addfailure (test anv_test, string as_errorMessage)
public function integer numberoftestsrun ()
public subroutine run (testcase anv_test)
public function boolean shouldstop ()
public subroutine stop ()
public function integer numberoffailures ()
public function boolean wassuccessful ()
public function TestCase getcurrenttestcase ()
public subroutine adderror (test anv_test, string as_errormessage)
public function integer numberOfErrors ()
public function pbunit_collection errors ()
public function pbunit_collection failures ()
end prototypes

event starttest;ii_numberOfTestsRun ++
end event

public subroutine addfailure (test anv_test, string as_errorMessage);TestFailure failure

failure = create TestFailure
failure.initialize(anv_test, as_errorMessage)
inv_failureCollection.add(failure)
end subroutine

public function integer numberoftestsrun ();return ii_numberOfTestsRun
end function

public subroutine run (testcase anv_test);currentTestCase = anv_test
this.event startTest(anv_test)
anv_test.runBare()
this.event endTest(anv_test)
setNull(currentTestCase)

end subroutine

public function boolean shouldstop ();return ib_stop
end function

public subroutine stop ();ib_stop = true
end subroutine

public function integer numberoffailures ();return inv_failureCollection.size()
end function

public function boolean wassuccessful ();return (numberOfFailures() = 0) and (numberOfErrors() = 0)
end function

public function TestCase getcurrenttestcase ();return currentTestCase
end function

public subroutine adderror (test anv_test, string as_errormessage);TestFailure failure

failure = create TestFailure
failure.initialize(anv_test, as_errorMessage)
inv_errorCollection.add(failure)
end subroutine

public function integer numberOfErrors ();return inv_errorCollection.size()
end function

public function pbunit_collection errors ();return inv_errorCollection
end function

public function pbunit_collection failures ();return inv_failureCollection
end function

on testresult.create
TriggerEvent( this, "constructor" )
end on

on testresult.destroy
TriggerEvent( this, "destructor" )
end on

event constructor;inv_failureCollection = create pbunit_Collection
inv_errorCollection = create pbunit_Collection

end event

