//objectcomments Powerbuilder library functions
forward
global type n_pbunit_objectservice from nonvisualobject
end type
end forward

shared variables
 
String _CurrentTestMethodName 
end variables

global type n_pbunit_objectservice from nonvisualobject autoinstantiate
end type

forward prototypes
public function string of_getpbversion ()
public function boolean of_is_a_valid_test_class (string as_classname, string as_librarylist[])
public function boolean of_is_a_test_method (scriptdefinition asd_scriptdefinition)
public subroutine of_get_test_method_list (string as_testcase_name, ref string as_testmethod_name_list[], ref string as_librarylist[])
public subroutine of_set_current_test_method_name (string as_methodname)
public function string of_get_current_test_method_name ()
end prototypes

public function string of_getpbversion ();integer li_majver, li_minver

ContextInformation ci

getContextService( "ContextInformation", ci )

ci.GetMajorVersion(li_majver)
ci.GetMinorVersion(li_minver)

string PBVersion

PBVersion = string(li_majver) + '.' + string(li_minver)

return PBVersion

//return "9.0"
end function

public function boolean of_is_a_valid_test_class (string as_classname, string as_librarylist[]);ClassDefinition	lcd_notATestClass
ClassDefinition	lcd_class
ClassDefinition	lcd_ancestor


lcd_class = findClassDefinition(as_className, as_libraryList)
if isValid(lcd_class) then
else
	return false
end if

if lower(as_className) = "warning" or &
	lower(as_className) = "asynctestcase" then
	return false
end if


lcd_ancestor = lcd_class.ancestor
do while IsValid(lcd_ancestor)
	
	if lower(lcd_ancestor.name) = "testcase" 	then
		exit
	end if
	lcd_ancestor = lcd_ancestor.ancestor
loop

if isValid(lcd_ancestor) then
else
	return false
end if	

return true
end function

public function boolean of_is_a_test_method (scriptdefinition asd_scriptdefinition);TypeDefinition	ltd_returnType

if asd_scriptDefinition.kind = ScriptEvent! then
else
	return false
end if

if lower(mid(asd_scriptDefinition.name, 1, 4)) = "test" then
//if  lower(asd_scriptDefinition.name) <> "setup" &
//	or lower(asd_scriptDefinition.name) <> "teardown" &
//	or lower(asd_scriptDefinition.name) <> "constructor" &
//	or lower(asd_scriptDefinition.name) <> "destructor" &
//	then
else
	return false
end if

if upperBound(asd_scriptDefinition.argumentList) > 0 then
	return false
end if

return true
end function

public subroutine of_get_test_method_list (string as_testcase_name, ref string as_testmethod_name_list[], ref string as_librarylist[]);ClassDefinition	lcd_notATestClass
ClassDefinition	lcd_class
ClassDefinition	lcd_ancestor
int 					i, index  

string				ls_empty[]

as_testmethod_name_list = ls_empty

lcd_class = findClassDefinition(as_testcase_name, as_libraryList)
if Not isValid(lcd_class) then
	return 
end if


 
for i = 1 to upperBound(lcd_class.scriptList)
	if of_is_a_Test_Method(lcd_class.scriptList[i]) then
		index ++
  	   as_testmethod_name_list [index] = lcd_class.scriptList[i].name

//		lnv_testCase = create using as_className
//		lnv_testCase.initialize(lcd_class.scriptList[li].name)
//		addTest(lnv_testCase)
	end if
next

return
end subroutine

public subroutine of_set_current_test_method_name (string as_methodname); _CurrentTestMethodName  = as_MethodName
end subroutine

public function string of_get_current_test_method_name ();return _CurrentTestMethodName
end function

on n_pbunit_objectservice.create
call super::create
TriggerEvent( this, "constructor" )
end on

on n_pbunit_objectservice.destroy
TriggerEvent( this, "destructor" )
call super::destroy
end on

