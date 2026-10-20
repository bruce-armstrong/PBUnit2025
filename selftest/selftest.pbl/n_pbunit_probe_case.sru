//objectcomments Test case used by the self-tests to run assertions against its own result
forward
global type n_pbunit_probe_case from testcase
end type
end forward

global type n_pbunit_probe_case from testcase
event throws_error ( )
event throws_nothing ( )
end type
global n_pbunit_probe_case n_pbunit_probe_case

forward prototypes
public subroutine of_attach (testresult anv_result)
end prototypes

event throws_error();PowerObject	lpo_null

// Null object reference: a PowerBuilder runtime error.
lpo_null.ClassName()
end event

event throws_nothing();Return
end event

public subroutine of_attach (testresult anv_result);// Assertions made on this object are recorded in anv_result.
inv_result = anv_result
end subroutine

on n_pbunit_probe_case.create
call super::create
end on

on n_pbunit_probe_case.destroy
call super::destroy
end on
