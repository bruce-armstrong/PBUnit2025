//objectcomments PBUnit self-test runner.  Copy this application object as the starting point for a test project.
forward
global transaction sqlca
global dynamicdescriptionarea sqlda
global dynamicstagingarea sqlsa
global error error
global message message
end forward

global type pbunit_selftest from application
 string appruntimeversion = "25.1.0.6430"
integer highdpimode = 0
end type
global pbunit_selftest pbunit_selftest

on pbunit_selftest.create
appname = "pbunit_selftest"
message = create message
sqlca = create transaction
sqlda = create dynamicdescriptionarea
sqlsa = create dynamicstagingarea
error = create error
end on

on pbunit_selftest.destroy
destroy( sqlca )
destroy( sqlda )
destroy( sqlsa )
destroy( error )
destroy( message )
end on

event open;// Runs the tests named in n_pbunit_registry, writes the results, and ends
// the process with exit code 0 (pass), 1 (failures) or 2 (problems).
n_pbunit_runner	lnv_runner
Integer				li_exitcode

lnv_runner = create n_pbunit_runner
li_exitcode = lnv_runner.of_Run(CommandParm())
lnv_runner.of_Exit(li_exitcode)
end event

event systemerror;// Route the error to the running test case, if there is one.
If f_catchsystemerror() = 1 Then Return

Halt Close
end event
