#Requires -Version 7
<#
.SYNOPSIS
    Tests PBUnitMcpServer.ps1 by talking MCP to it over stdio, as a client does.

.DESCRIPTION
    Uses the repository's own self-test project (pbunit_selftest.pbproj) for real builds, and a temporary copy of
    it with a compile error and with broken test sources for the failure paths. Needs PowerBuilder 2025
    (PBAutoBuild) and takes a few minutes. Exit code 0 when every check passes.

.EXAMPLE
    pwsh -File plugins/pbunit/mcp/Test-PBUnitMcpServer.ps1
#>
param([switch]$SkipBuilds)

$ErrorActionPreference = "Stop"
$repo   = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$server = Join-Path $PSScriptRoot "PBUnitMcpServer.ps1"
$script:failures = 0
$script:nextId = 0

function Check([string]$name, [bool]$condition, [string]$detail = "") {
    if ($condition) { Write-Host "  PASS  $name" }
    else { Write-Host "  FAIL  $name $detail"; $script:failures++ }
}

function Start-Server([string]$projectDir) {
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = (Get-Command pwsh).Source
    foreach ($a in "-NoLogo", "-NoProfile", "-NonInteractive", "-File", $server) { [void]$psi.ArgumentList.Add($a) }
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.Environment["CLAUDE_PROJECT_DIR"] = $projectDir
    $psi.StandardOutputEncoding = New-Object Text.UTF8Encoding($false)
    $p = [Diagnostics.Process]::Start($psi)
    $p.StandardInput.AutoFlush = $true
    $script:stderrTask = $p.StandardError.ReadToEndAsync()
    return $p
}

function Invoke-Rpc($p, [string]$method, $params, [switch]$Notification) {
    $msg = [ordered]@{ jsonrpc = "2.0"; method = $method }
    if ($null -ne $params) { $msg.params = $params }
    if ($Notification) { $p.StandardInput.WriteLine(($msg | ConvertTo-Json -Depth 20 -Compress)); return }
    $id = ++$script:nextId; $msg.id = $id
    $p.StandardInput.WriteLine(($msg | ConvertTo-Json -Depth 20 -Compress))
    $script:progress = 0
    while ($true) {
        $line = $p.StandardOutput.ReadLine()
        if ($null -eq $line) { throw "Server closed stdout. stderr: $($script:stderrTask.Result)" }
        $reply = $line | ConvertFrom-Json -AsHashtable
        if ($reply["method"] -eq "notifications/progress") { $script:progress++; continue }
        if ($reply["id"] -eq $id) { return $reply }
    }
}

function Invoke-Tool($p, [string]$name, $arguments, [switch]$WithProgress) {
    $params = [ordered]@{ name = $name; arguments = $arguments }
    if ($WithProgress) { $params["_meta"] = @{ progressToken = "t$($script:nextId + 1)" } }
    $reply = Invoke-Rpc $p "tools/call" $params
    if ($reply.ContainsKey("error")) { throw "tools/call $name failed: $($reply.error.message)" }
    return $reply.result
}

$temp = Join-Path ([IO.Path]::GetTempPath()) ("pbunit-mcp-test-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory $temp | Out-Null
$enc = New-Object Text.UTF8Encoding($true)
function Write-Source([string]$path, [string]$text) { [IO.File]::WriteAllText($path, ($text -replace "`r?`n", "`r`n"), $enc) }

try {
    $p = Start-Server $repo

    Write-Host "Protocol"
    $init = Invoke-Rpc $p "initialize" ([ordered]@{ protocolVersion = "2025-06-18"; capabilities = @{}; clientInfo = @{ name = "test"; version = "1" } })
    Check "initialize returns the client's protocol version" ($init.result.protocolVersion -eq "2025-06-18")
    Check "initialize declares tools" ($init.result.capabilities.ContainsKey("tools"))
    Invoke-Rpc $p "notifications/initialized" $null -Notification
    $list = Invoke-Rpc $p "tools/list" @{}
    $names = @($list.result.tools | ForEach-Object { $_.name })
    Check "tools/list has the four tools" (($names -join ",") -eq "find_projects,check_source,run_tests,get_results") ($names -join ",")
    Check "every tool has an object input schema" (@($list.result.tools | Where-Object { $_.inputSchema.type -ne "object" }).Count -eq 0)
    Check "ping" ((Invoke-Rpc $p "ping" @{}).ContainsKey("result"))
    $bad = Invoke-Rpc $p "no/such/method" @{}
    Check "unknown method is error -32601" ($bad.error.code -eq -32601)

    Write-Host "find_projects"
    $r = Invoke-Tool $p "find_projects" @{}
    $proj = @($r.structuredContent.projects)
    Check "finds exactly the self-test project (not eval fixtures)" ($proj.Count -eq 1 -and $proj[0].project -like "*pbunit_selftest.pbproj") ($proj.project -join ", ")
    Check "framework present" ($proj[0].frameworkPresent -eq $true)
    $assertClass = @($proj[0].testClasses | Where-Object { $_.class -eq "n_pbunit_assert_tests" })
    Check "lists n_pbunit_assert_tests with its 11 tests" ($assertClass.Count -eq 1 -and @($assertClass[0].tests).Count -eq 11) "$(@($proj[0].testClasses | ForEach-Object { $_.class }) -join ',')"
    $script:selfTestCount = $proj[0].testCount
    $r = Invoke-Tool $p "find_projects" @{ root = "no\such\folder" }
    Check "missing root is a tool error" ($r.isError -eq $true)

    Write-Host "check_source"
    $r = Invoke-Tool $p "check_source" @{ path = "selftest\selftest.pbl" }
    Check "the self-test library has no issues" ($r.structuredContent.errorCount -eq 0 -and $r.structuredContent.warningCount -eq 0) $r.content[0].text
    $r = Invoke-Tool $p "check_source" @{ path = "pbunit.pbl\testcase.sru" }
    Check "testcase.sru has no issues" ($r.structuredContent.errorCount -eq 0) $r.content[0].text

    $broken = Join-Path $temp "n_bad_tests.sru"
    Write-Source $broken @'
forward
global type n_bad_tests from testcase
event test_one ( )
end type
end forward

global type n_bad_tests from testcase
event test_one ( )
event test_two ( )
event test_args ( long al_x )
end type
global n_bad_tests n_bad_tests

forward prototypes
protected function integer of_missing ()
end prototypes

event test_one();assertTrue(True)
end event

event test_three();assertTrue(True)
end event

event test_args;assertTrue(True)
end event
'@
    $r = Invoke-Tool $p "check_source" @{ path = $broken }
    $msgs = @($r.structuredContent.files[0].issues | ForEach-Object { $_.message }) -join " | "
    Check "flags an event in the forward block" ($msgs -match "forward block") $msgs
    Check "flags a test event without a script" ($msgs -match "test_two is declared but has no script") $msgs
    Check "flags a test script that isn't declared" ($msgs -match "test_three has a script but isn't declared") $msgs
    Check "flags a test event with arguments" ($msgs -match "test_args takes arguments") $msgs
    Check "warns about a prototype without a script" ($msgs -match "of_missing is in 'forward prototypes'") $msgs
    Check "reports LF/no BOM as encoding facts, not issues" ($r.structuredContent.files[0].encoding.lineEndings -eq "CRLF") ($r.structuredContent.files[0].encoding | ConvertTo-Json -Compress)

    $helper = Join-Path $temp "n_helper_tests.sru"
    Write-Source $helper ((Get-Content (Join-Path $repo "selftest\selftest.pbl\n_pbunit_probe_case.sru") -Raw) -replace 'n_pbunit_probe_case', 'n_helper_tests' -replace 'from testcase', 'from nonvisualobject')
    $r = Invoke-Tool $p "check_source" @{ path = $helper }
    Check "warns about a helper named *tests" ((@($r.structuredContent.files[0].issues | ForEach-Object { $_.message }) -join " ") -match "ends in 'tests' but inherits")

    $r = Invoke-Tool $p "get_results" @{ project = "no_such.pbproj" }
    Check "get_results with a missing project is a tool error" ($r.isError -eq $true)

    if (-not $SkipBuilds) {
        Write-Host "run_tests (builds; takes a few minutes)"
        $r = Invoke-Tool $p "run_tests" @{} -WithProgress
        $s = $r.structuredContent
        Check "self-tests PASS" ($s.outcome -eq "PASS" -and $r.isError -eq $false) "$($s.outcome) $($r.content[0].text)"
        Check "every test passed ($script:selfTestCount, as find_projects counted)" ($s.summary.passed -eq $script:selfTestCount -and $s.summary.tests -eq $script:selfTestCount) "$($s.summary.passed) of $($s.summary.tests)"
        Check "buildErrors is an empty list, not null, when the build succeeds" ($s.ContainsKey("buildErrors") -and $null -ne $s["buildErrors"] -and $s["buildErrors"] -is [object[]] -and $s["buildErrors"].Count -eq 0) "($(if ($null -eq $s["buildErrors"]) { 'null' } else { $s["buildErrors"].GetType().Name }))"
        $r = Invoke-Tool $p "run_tests" @{ filter = "n_pbunit_assert_tests.test_assertequals_d*" }
        Check "filter runs 3 tests" ($r.structuredContent.summary.tests -eq 3) "$($r.structuredContent.summary.tests)"
        $r = Invoke-Tool $p "run_tests" @{ filter = "no_such_tests" }
        Check "a filter that matches nothing is ERROR with the runner's problem" ($r.structuredContent.outcome -eq "ERROR" -and ($r.structuredContent.summary.problems -join " ") -match "No tests ran") $r.content[0].text
        $r = Invoke-Tool $p "get_results" @{}
        Check "get_results reads the last run" ($r.structuredContent.summary.outcome -eq "ERROR")

        # A copy of the self-test project with a compile error
        $copy = Join-Path $temp "copy"
        New-Item -ItemType Directory $copy | Out-Null
        foreach ($item in "pbunit.pbl", "pbunitfunc.pbl", "pbunitrunner.pbl", "pbunitmocks.pbl", "selftest", "scripts", "pbunit_selftest.pbproj") {
            Copy-Item -Recurse (Join-Path $repo $item) (Join-Path $copy $item)
        }
        $f = Join-Path $copy "selftest\selftest.pbl\n_pbunit_assert_tests.sru"
        Write-Source $f ((Get-Content $f -Raw) -replace 'inv_probe\.assertEquals\("abc", "abc"\)', 'inv_probe.assertEqualz("abc", "abc")')
        $r = Invoke-Tool $p "run_tests" @{ project = (Join-Path $copy "pbunit_selftest.pbproj") }
        $raw = $r.structuredContent["buildErrors"]
        Check "buildErrors is a list even with one error" ($raw -is [object[]]) "($(if ($null -eq $raw) { 'null' } else { $raw.GetType().Name }))"
        Check "exactly the one real compile error (not the log's summary lines)" (@($raw).Count -eq 1) "($(@($raw).Count): $(@($raw) | ConvertTo-Json -Compress))"
        $e = @($raw)
        Check "a compile error is BUILD_FAILED" ($r.structuredContent.outcome -eq "BUILD_FAILED" -and $r.isError -eq $true) $r.structuredContent.outcome
        Check "the compile error has file, line and message" ($e.Count -ge 1 -and $e[0].file -like "*n_pbunit_assert_tests.sru" -and $e[0].line -gt 0 -and $e[0].message -match "assertequalz") ($e | ConvertTo-Json -Compress)
    }

    $p.StandardInput.Close()
    if (-not $p.WaitForExit(10000)) { $p.Kill($true) }
    Check "the server exits when stdin closes" ($p.HasExited)
} finally {
    if ($p -and -not $p.HasExited) { $p.Kill($true) }
    Remove-Item -Recurse -Force $temp -ErrorAction SilentlyContinue
}

Write-Host ""
if ($script:failures -eq 0) { Write-Host "All checks passed."; exit 0 } else { Write-Host "$($script:failures) check(s) failed."; exit 1 }
