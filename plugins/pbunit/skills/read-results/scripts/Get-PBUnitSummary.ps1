<#
.SYNOPSIS
    Summarizes a PBUnit run: totals, runner problems, and the failing tests grouped by class and by message.

.DESCRIPTION
    Reads results.xml (JUnit XML) and, beside it, results.txt (which also holds the RESULT line and any
    PROBLEM lines) as written by Invoke-PBUnit.ps1 or the PBUnit test exe.

    -Results can be a results.xml file, a results.txt file, or the folder that holds them. Without it, the
    newest results.xml under .\build is used.

.EXAMPLE
    pwsh -File Get-PBUnitSummary.ps1 -Results C:\src\app\build\app_tests
.EXAMPLE
    pwsh -File Get-PBUnitSummary.ps1 -Json
#>
param(
    [string]$Results,
    # How many test names to list for each message group.
    [int]$MaxTests = 8,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

# --- Locate the files -------------------------------------------------------
if (-not $Results) {
    $found = Get-ChildItem -Path (Join-Path (Get-Location) "build") -Filter results.xml -Recurse -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $found) { Write-Host "No results.xml found under .\build. Pass -Results <file or folder>."; exit 2 }
    $Results = $found.FullName
}
$Results = (Resolve-Path $Results).Path
if ((Get-Item $Results).PSIsContainer) {
    $folder = $Results
    $xmlPath = Join-Path $folder "results.xml"
    $txtPath = Join-Path $folder "results.txt"
} else {
    $folder = Split-Path -Parent $Results
    $base = [IO.Path]::GetFileNameWithoutExtension($Results)
    $xmlPath = Join-Path $folder "$base.xml"
    $txtPath = Join-Path $folder "$base.txt"
}

$summary = [ordered]@{
    folder   = $folder
    written  = $null
    outcome  = $null
    tests    = 0
    passed   = 0
    failed   = 0
    errors   = 0
    problems = @()
    classes  = @()
    groups   = @()
}

# --- results.txt: outcome and runner problems -------------------------------
if (Test-Path $txtPath) {
    $lines = Get-Content $txtPath -Encoding UTF8
    $summary.written = (Get-Item $txtPath).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    if ($lines.Count -gt 0 -and $lines[0] -match '^RESULT: (\w+)') { $summary.outcome = $Matches[1] }
    $summary.problems = @($lines | Where-Object { $_ -like 'PROBLEM: *' } | ForEach-Object { $_.Substring(9) })
}

# --- results.xml: every test ------------------------------------------------
$records = @()
if (Test-Path $xmlPath) {
    if (-not $summary.written) { $summary.written = (Get-Item $xmlPath).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss") }
    [xml]$doc = Get-Content $xmlPath -Raw -Encoding UTF8
    foreach ($suite in @($doc.testsuites.testsuite)) {
        if (-not $suite) { continue }
        foreach ($case in @($suite.testcase)) {
            $status = "pass"; $text = ""
            if ($case.failure) { $status = "fail"; $text = [string]$case.failure.InnerText }
            if ($case.error)   { $status = "error"; $text = [string]$case.error.InnerText }
            $records += [pscustomobject]@{
                Class   = $case.classname
                Test    = $case.name
                Status  = $status
                Message = (($text -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -First 1)
                Text    = $text.Trim()
            }
        }
    }
}

if (-not (Test-Path $xmlPath) -and -not (Test-Path $txtPath)) {
    Write-Host "No results.xml or results.txt in $folder. The run did not get as far as writing results:"
    Write-Host "check the run's console output and build.log."
    exit 2
}

$summary.tests  = $records.Count
$summary.passed = @($records | Where-Object Status -eq "pass").Count
$summary.failed = @($records | Where-Object Status -eq "fail").Count
$summary.errors = @($records | Where-Object Status -eq "error").Count
if (-not $summary.outcome) {
    $summary.outcome = if ($summary.tests -eq 0) { "ERROR" } elseif ($summary.failed + $summary.errors -eq 0) { "PASS" } else { "FAIL" }
}

# --- Classes with failures ---------------------------------------------------
$byClass = $records | Group-Object Class
foreach ($c in $byClass) {
    $bad = @($c.Group | Where-Object Status -ne "pass")
    if ($bad.Count -eq 0) { continue }
    $messages = @($bad | Select-Object -ExpandProperty Message -Unique)
    $summary.classes += [pscustomobject]@{
        Class        = $c.Name
        Tests        = $c.Count
        NotPassing   = $bad.Count
        AllFailed    = ($bad.Count -eq $c.Count)
        SameMessage  = ($messages.Count -eq 1)
    }
}

# --- Failures grouped by identical first message line ----------------------
function Get-Hint([string]$message, [string]$status, [object]$classInfo, [string]$testClass) {
    if ($message -like 'Not configured:*') { return "environment: a prerequisite the test needs is not set up" }
    if ($message -match '^(Class not found|Class does not inherit from testcase)') { return "discovery: the class name or ancestor is wrong" }
    if ($message -match '^Runtime error') {
        # The runner ends runtime errors with [<object>.<routine> line <n>]
        if ($message -match '\[(\w+)\.(\w+) line \d+\]\s*$') {
            $object = $Matches[1]; $routine = $Matches[2]
            if ($object -ieq $testClass) { return "runtime error in the test class itself ($routine): a test or fixture problem" }
            return "runtime error in $object.$routine, outside the test class: usually the code under test, unless $object is a test helper"
        }
        return "runtime error in the code under test or in the test's setup"
    }
    if ($status -eq "error") { return "exception thrown by the code under test or by the test" }
    if ($classInfo -and $classInfo.AllFailed -and $classInfo.SameMessage -and $classInfo.Tests -gt 1) {
        return "every test in the class fails the same way: likely setup or fixture"
    }
    if ($message -match 'expected <.*> but was <.*>') { return "assertion: compare with the test's intent" }
    return ""
}

$bad = @($records | Where-Object Status -ne "pass")
foreach ($g in ($bad | Group-Object Status, Message | Sort-Object Count -Descending)) {
    $first = $g.Group[0]
    $classInfo = $summary.classes | Where-Object Class -eq $first.Class | Select-Object -First 1
    $names = @($g.Group | ForEach-Object { "$($_.Class).$($_.Test)" })
    $summary.groups += [pscustomobject]@{
        Status  = $first.Status
        Count   = $g.Count
        Message = $first.Message
        Hint    = (Get-Hint $first.Message $first.Status $classInfo $first.Class)
        Tests   = $names
    }
}

# --- Output -----------------------------------------------------------------
if ($Json) {
    $summary | ConvertTo-Json -Depth 5
} else {
    Write-Host "Results: $folder  (written $($summary.written))"
    Write-Host ("RESULT: {0}   {1} tests: {2} passed, {3} failed, {4} errors" -f `
        $summary.outcome, $summary.tests, $summary.passed, $summary.failed, $summary.errors)
    foreach ($p in $summary.problems) { Write-Host "PROBLEM: $p" }

    if ($summary.classes.Count -gt 0) {
        Write-Host ""
        Write-Host "Classes with failing tests:"
        foreach ($c in $summary.classes | Sort-Object NotPassing -Descending) {
            $note = if ($c.AllFailed -and $c.SameMessage -and $c.Tests -gt 1) { "  (all, same message)" } elseif ($c.AllFailed) { "  (all)" } else { "" }
            Write-Host ("  {0,-40} {1} of {2}{3}" -f $c.Class, $c.NotPassing, $c.Tests, $note)
        }
        Write-Host ""
        Write-Host "Failures grouped by message:"
        foreach ($g in $summary.groups) {
            Write-Host ("  [{0} x {1}] {2}" -f $g.Count, $g.Status.ToUpper(), $g.Message)
            if ($g.Hint) { Write-Host "      hint: $($g.Hint)" }
            $shown = $g.Tests | Select-Object -First $MaxTests
            foreach ($n in $shown) { Write-Host "      $n" }
            if ($g.Tests.Count -gt $MaxTests) { Write-Host "      ... and $($g.Tests.Count - $MaxTests) more" }
        }
    }
}

switch ($summary.outcome) { "PASS" { exit 0 } "FAIL" { exit 1 } default { exit 2 } }
