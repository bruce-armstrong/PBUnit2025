//objectcomments A Test can be run and collect its results.
forward
global type test from testobject
end type
end forward

global type test from testobject
end type
global test test

forward prototypes
public function integer counttestcases ()
public subroutine run (testresult inv_result)
public function test suite ()
public function boolean shouldrerun ()
end prototypes

public function integer counttestcases ();return 0
end function

public subroutine run (testresult inv_result);
end subroutine

public function test suite ();return this
end function

public function boolean shouldrerun ();return false
end function

on test.create
TriggerEvent( this, "constructor" )
end on

on test.destroy
TriggerEvent( this, "destructor" )
end on

