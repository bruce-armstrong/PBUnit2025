#Requires -Version 7
<#
.SYNOPSIS
    PBUnit MCP server: lets AI agents find, check, build and run PBUnit tests and read their results.

.DESCRIPTION
    A Model Context Protocol server over stdio (newline-delimited JSON-RPC 2.0). Tools:

      find_projects   Test projects under a folder, with their test classes and test events (no build)
      check_source    Static checks of a test source file (.sru/.srw) for layout mistakes the compiler rejects
      run_tests       Build and run a test project with the framework's Invoke-PBUnit.ps1; structured results
      get_results     The results of the last run of a test project, without building

    Relative paths are resolved against CLAUDE_PROJECT_DIR (set by Claude Code) or the current folder.
    Nothing but protocol messages may be written to stdout; diagnostics go to stderr.
#>
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3

$ServerVersion = "0.1.0"
$PluginRoot    = Split-Path -Parent $PSScriptRoot
$SummaryScript = Join-Path $PluginRoot "skills/read-results/scripts/Get-PBUnitSummary.ps1"
$ProjectDir    = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }

$Utf8NoBom = New-Object Text.UTF8Encoding($false)
$StdIn  = New-Object IO.StreamReader([Console]::OpenStandardInput(), $Utf8NoBom)
$StdOut = New-Object IO.StreamWriter([Console]::OpenStandardOutput(), $Utf8NoBom)
$StdOut.AutoFlush = $true
$StdOut.NewLine = "`n"

class ToolError : Exception { ToolError([string]$message) : base($message) {} }

function Write-Log([string]$message) { [Console]::Error.WriteLine("[pbunit-mcp] $message") }
function Send-Message($message) { $StdOut.WriteLine(($message | ConvertTo-Json -Depth 64 -Compress)) }

# --- Paths and projects -----------------------------------------------------------------------

function Resolve-UserPath([string]$path) {
    if (-not $path) { return $ProjectDir }
    if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $ProjectDir $path }
    if (-not (Test-Path -LiteralPath $path)) { throw [ToolError]::new("Path not found: $path") }
    return (Resolve-Path -LiteralPath $path).Path
}

function Read-SourceText([string]$path) {
    $text = [IO.File]::ReadAllText($path)
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    return $text
}

function Get-ProjectInfo([string]$projectPath) {
    [xml]$xml   = Get-Content -LiteralPath $projectPath -Raw
    $root       = Split-Path -Parent $projectPath
    $libraries  = @($xml.Project.Libraries.Library | ForEach-Object { Join-Path $root $_.Path })
    $pbunitLib  = $libraries | Where-Object { (Split-Path $_ -Leaf) -ieq "pbunit.pbl" } | Select-Object -First 1
    if (-not $pbunitLib) { return $null }

    $frameworkDir = Split-Path -Parent $pbunitLib
    $invoke       = Join-Path $frameworkDir "scripts\Invoke-PBUnit.ps1"
    $problems     = @()
    $frameworkOk  = (Test-Path -LiteralPath (Join-Path $pbunitLib "testcase.sru")) -and (Test-Path -LiteralPath $invoke)
    if (-not $frameworkOk) {
        $problems += "The PBUnit framework isn't present in $frameworkDir. If it is a git submodule: delete any empty " +
            "pbunit.pbl, pbunitfunc.pbl and pbunitrunner.pbl folders there, then run 'git submodule update --init'."
    }

    # The same discovery as Invoke-PBUnit.ps1: *tests classes whose ancestor chain reaches testcase.
    $ancestors = @{}; $files = @{}
    foreach ($lib in $libraries) {
        if (-not (Test-Path -LiteralPath $lib)) { $problems += "Library folder not found: $lib"; continue }
        foreach ($file in Get-ChildItem -LiteralPath $lib -Filter *.sru -File) {
            $m = Select-String -LiteralPath $file.FullName -Pattern '^global type (\w+) from (\w+)' | Select-Object -First 1
            if ($m) {
                $name = $m.Matches[0].Groups[1].Value.ToLower()
                $ancestors[$name] = $m.Matches[0].Groups[2].Value.ToLower()
                $files[$name] = $file.FullName
            }
        }
    }
    $classes = @()
    foreach ($name in $ancestors.Keys | Sort-Object) {
        if (-not $name.EndsWith("tests")) { continue }
        $current = $name; $isTest = $false
        for ($depth = 0; $depth -lt 50 -and $ancestors.ContainsKey($current); $depth++) {
            $current = $ancestors[$current]
            if ($current -eq "testcase") { $isTest = $true; break }
        }
        if (-not $isTest) { continue }
        $tests = @(Select-String -LiteralPath $files[$name] -Pattern '^event (test\w*) \( \)\s*$' |
            ForEach-Object { $_.Matches[0].Groups[1].Value })
        $classes += [ordered]@{ class = $name; file = $files[$name]; ancestor = $ancestors[$name]; tests = $tests }
    }

    $testCount = 0; foreach ($c in $classes) { $testCount += $c.tests.Count }
    return [ordered]@{
        project      = $projectPath
        application  = [string]$xml.Project.Application.Name
        entryLibrary = (Join-Path $root $xml.Project.Libraries.AppEntry)
        frameworkDir = $frameworkDir
        invokeScript = $invoke
        frameworkPresent = $frameworkOk
        testClasses  = $classes
        testCount    = $testCount
        problems     = $problems
    }
}

function Find-TestProjects([string]$root) {
    $skip = '\\(build|\.pb|\.git|node_modules)\\|\\plugins\\pbunit\\evals\\'
    Get-ChildItem -LiteralPath $root -Filter *.pbproj -File -Recurse -Depth 6 -ErrorAction SilentlyContinue |
        Where-Object { ($_.FullName + "\") -notmatch $skip } |
        ForEach-Object { Get-ProjectInfo $_.FullName } |
        Where-Object { $_ }
}

function Resolve-TestProject([string]$project) {
    if ($project) {
        $path = Resolve-UserPath $project
        if ((Get-Item -LiteralPath $path).PSIsContainer) {
            $found = @(Find-TestProjects $path)
        } else {
            $info = Get-ProjectInfo $path
            if (-not $info) { throw [ToolError]::new("$path doesn't list pbunit.pbl in its libraries, so it isn't a PBUnit test project.") }
            return $info
        }
    } else {
        $found = @(Find-TestProjects $ProjectDir)
    }
    if ($found.Count -eq 0) { throw [ToolError]::new("No PBUnit test project (a .pbproj that lists pbunit.pbl) was found. Pass 'project'.") }
    if ($found.Count -gt 1) {
        throw [ToolError]::new("Several test projects were found; pass 'project' as one of: " + (($found | ForEach-Object { $_.project }) -join ", "))
    }
    return $found[0]
}

function Get-OutDir($info, [string]$platform) {
    $name = [IO.Path]::GetFileNameWithoutExtension($info.project)
    $dir  = Join-Path (Split-Path -Parent $info.project) "build\$name"
    if ($platform -eq "64") { $dir += "-x64" }
    return $dir
}

# --- Results ----------------------------------------------------------------------------------

function Get-Summary([string]$outDir) {
    $output = & pwsh -NoLogo -NoProfile -NonInteractive -File $SummaryScript -Results $outDir -Json 2>&1
    $text = ($output | Out-String).Trim()
    if (-not $text.StartsWith("{")) { return $null }
    return ($text | ConvertFrom-Json -AsHashtable)
}

function Get-BuildErrors([string]$buildLog) {
    $result = [ordered]@{ errors = @(); warningCount = 0 }
    if (-not (Test-Path -LiteralPath $buildLog)) { return $result }
    $bytes = [IO.File]::ReadAllBytes($buildLog)
    $text  = if ($bytes.Length -gt 1 -and $bytes[1] -eq 0) { [Text.Encoding]::Unicode.GetString($bytes) } else { [Text.Encoding]::UTF8.GetString($bytes) }
    foreach ($line in $text -split "`r?`n") {
        if ($line -match '\[Warning\]') { $result.warningCount++; continue }
        if ($line -notmatch '\[Error\]') { continue }
        if ($line -match '\[Error\] (?<file>.+?)\((?<line>\d+),(?<col>\d+)\): (?<where>.*?)(?:\((?<rline>\d+),\d+\))?: (?<code>(?:Error|Warning) C\d+): (?<msg>.*)$') {
            $result.errors += [ordered]@{
                file = $Matches.file; line = [int]$Matches.line; column = [int]$Matches.col
                location = $Matches.where; code = $Matches.code; message = $Matches.msg.Trim()
            }
        } elseif ($line -notmatch 'Failed to build project') {
            $result.errors += [ordered]@{ message = ($line -replace '^.*?\[Error\]\s*', '').Trim() }
        }
    }
    return $result
}

# --- Tools ------------------------------------------------------------------------------------

function Invoke-FindProjects($arguments) {
    $root = Resolve-UserPath $arguments["root"]
    $projects = @(Find-TestProjects $root)
    $lines = @("Test projects under ${root}: $($projects.Count)")
    foreach ($p in $projects) {
        $lines += "- $($p.project): $($p.testClasses.Count) test classes, $($p.testCount) tests" + $(if ($p.problems) { " (problems: $($p.problems.Count))" } else { "" })
    }
    return @{ text = ($lines -join "`n"); data = [ordered]@{ root = $root; projects = $projects } }
}

function Invoke-RunTests($arguments, $progressToken) {
    $info = Resolve-TestProject $arguments["project"]
    if (-not $info.frameworkPresent) { throw [ToolError]::new(($info.problems -join " ")) }
    $platform = if ($arguments["platform"]) { [string]$arguments["platform"] } else { "32" }
    if ($platform -notin "32", "64") { throw [ToolError]::new("platform must be '32' or '64'.") }
    $testTimeout = if ($arguments["testTimeoutSeconds"]) { [int]$arguments["testTimeoutSeconds"] } else { 300 }
    $outDir = Get-OutDir $info $platform

    $argList = @("-NoLogo", "-NoProfile", "-NonInteractive", "-File", $info.invokeScript,
        "-Project", $info.project, "-OutDir", $outDir, "-Platform", $platform, "-TimeoutSeconds", $testTimeout)
    if ($arguments["filter"]) { $argList += @("-Filter", [string]$arguments["filter"]) }

    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = (Get-Command pwsh).Source
    foreach ($a in $argList) { [void]$psi.ArgumentList.Add([string]$a) }
    $psi.WorkingDirectory = Split-Path -Parent $info.project
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $started = Get-Date
    $proc = [Diagnostics.Process]::Start($psi)
    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()
    $limit = $testTimeout + 3600
    while (-not $proc.WaitForExit(15000)) {
        $elapsed = [int]((Get-Date) - $started).TotalSeconds
        if ($elapsed -gt $limit) { $proc.Kill($true); break }
        if ($null -ne $progressToken) {
            Send-Message ([ordered]@{ jsonrpc = "2.0"; method = "notifications/progress"
                params = [ordered]@{ progressToken = $progressToken; progress = $elapsed; message = "Building and running tests ($elapsed s)" } })
        }
    }
    $proc.WaitForExit()
    $console  = ($stdoutTask.Result + $stderrTask.Result).Trim()
    $exitCode = $proc.ExitCode
    $duration = [int]((Get-Date) - $started).TotalSeconds

    $resultsTxt = Join-Path $outDir "results.txt"
    $fresh = (Test-Path -LiteralPath $resultsTxt) -and ((Get-Item -LiteralPath $resultsTxt).LastWriteTime -ge $started.AddSeconds(-2))
    $summary = if ($fresh) { Get-Summary $outDir } else { $null }
    $build = Get-BuildErrors (Join-Path $outDir "build.log")

    $outcome = switch -Regex ($console) {
        "Build failed"                      { "BUILD_FAILED"; break }
        "Application Control policy"        { "BLOCKED"; break }
        "timed out"                         { "TIMEOUT"; break }
        "No test classes found"             { "NO_TESTS"; break }
        "was built as .*-bit, not"          { "WRONG_PLATFORM"; break }
        default {
            if ($summary) { $summary["outcome"] } elseif ($exitCode -eq 0) { "PASS" } else { "ERROR" }
        }
    }

    $data = [ordered]@{
        project = $info.project; platform = $platform; filter = $arguments["filter"]
        outcome = $outcome; exitCode = $exitCode; durationSeconds = $duration
        summary = $summary
        buildErrors = $(if ($outcome -eq "BUILD_FAILED") { $build.errors } else { @() })
        buildWarningCount = $build.warningCount
        artifacts = [ordered]@{ outDir = $outDir; resultsTxt = $resultsTxt; resultsXml = (Join-Path $outDir "results.xml"); buildLog = (Join-Path $outDir "build.log") }
    }
    if ($outcome -notin "PASS", "FAIL") { $data["consoleTail"] = (($console -split "`r?`n") | Select-Object -Last 30) -join "`n" }

    $lines = @("$outcome ($duration s): $($info.project) [$platform-bit]" + $(if ($arguments["filter"]) { " filter $($arguments["filter"])" } else { "" }))
    if ($summary) {
        $lines += "$($summary["tests"]) tests: $($summary["passed"]) passed, $($summary["failed"]) failed, $($summary["errors"]) errors"
        foreach ($p in $summary["problems"]) { $lines += "PROBLEM: $p" }
        foreach ($g in $summary["groups"]) { $lines += "[$($g["Count"]) x $(([string]$g["Status"]).ToUpper())] $($g["Message"])" + $(if ($g["Hint"]) { "  (hint: $($g["Hint"]))" } else { "" }) }
    }
    foreach ($e in $data.buildErrors) {
        $lines += if ($e.Contains("file")) { "$($e.file)($($e.line)): $($e.code): $($e.message)" } else { $e.message }
    }
    if ($data.Contains("consoleTail")) { $lines += "--- console (last lines) ---"; $lines += $data.consoleTail }
    return @{ text = ($lines -join "`n"); data = $data; isError = ($outcome -notin "PASS", "FAIL") }
}

function Invoke-GetResults($arguments) {
    $info = Resolve-TestProject $arguments["project"]
    $platform = if ($arguments["platform"]) { [string]$arguments["platform"] } else { "32" }
    $outDir = Get-OutDir $info $platform
    $summary = if (Test-Path -LiteralPath (Join-Path $outDir "results.txt")) { Get-Summary $outDir } else { $null }
    if (-not $summary) {
        throw [ToolError]::new("No results in $outDir. Run the tests first (run_tests).")
    }
    $lines = @("Results from $($summary["written"]) in ${outDir}:", "RESULT: $($summary["outcome"])   $($summary["tests"]) tests: $($summary["passed"]) passed, $($summary["failed"]) failed, $($summary["errors"]) errors")
    foreach ($p in $summary["problems"]) { $lines += "PROBLEM: $p" }
    foreach ($g in $summary["groups"]) { $lines += "[$($g["Count"]) x $(([string]$g["Status"]).ToUpper())] $($g["Message"])" + $(if ($g["Hint"]) { "  (hint: $($g["Hint"]))" } else { "" }) }
    return @{ text = ($lines -join "`n"); data = [ordered]@{ project = $info.project; platform = $platform; outDir = $outDir; summary = $summary } }
}

function Test-SourceFile([string]$path) {
    $issues = New-Object Collections.Generic.List[object]
    function Add-Issue([string]$severity, [int]$line, [string]$message) { $issues.Add([ordered]@{ severity = $severity; line = $line; message = $message }) }

    $bytes = [IO.File]::ReadAllBytes($path)
    $raw   = [IO.File]::ReadAllText($path)
    $crlf  = ([regex]::Matches($raw, "`r`n")).Count
    $lf    = ([regex]::Matches($raw, "(?<!`r)`n")).Count
    $encoding = [ordered]@{
        byteOrderMark = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        lineEndings = $(if ($crlf -and $lf) { "mixed" } elseif ($crlf) { "CRLF" } else { "LF" })
    }
    $ext   = [IO.Path]::GetExtension($path).ToLower()
    $lines = (Read-SourceText $path) -split "`r?`n"
    $base  = [IO.Path]::GetFileNameWithoutExtension($path)

    if ($ext -notin ".sru", ".srw") {
        return [ordered]@{ file = $path; class = $base; checked = $false; encoding = $encoding; issues = @()
            note = "Only .sru and .srw files are checked." }
    }

    # PowerScript identifiers can contain - $ # % as well as letters, digits and underscores.
    $id = '[\w$#%-]+'

    # Forward block: only 'global type ... from ...' and 'end type' (and application globals) belong there.
    $fwStart = [Array]::IndexOf($lines, "forward"); $fwEnd = [Array]::IndexOf($lines, "end forward")
    if ($fwStart -ge 0 -and $fwEnd -gt $fwStart) {
        # Windows and visual user objects also list their controls ('type <control> from <class> within <parent>')
        # and nested control instances ('dp_1 dp_1'); applications list globals ('global n_tr sqlca').
        $allowed = "^(global type $id from $id(\s+\w+)*|type $id from $id within $id|end type|global $id $id|$id $id|\s*)$"
        for ($i = $fwStart + 1; $i -lt $fwEnd; $i++) {
            if ($lines[$i] -notmatch $allowed) {
                Add-Issue "error" ($i + 1) "Only 'global type <name> from <ancestor>' and 'end type' (and, for a window, 'type <control> from <class> within <window>') belong in the forward block; declare events, variables and properties in the main type block."
            }
        }
    }

    # Main type block: the 'global type' line after the forward block.
    # 'global type n_x from nonvisualobject' or '... from nonvisualobject autoinstantiate'
    $typeLines = @(); for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match "^global type $id from $id(\s+\w+)*\s*$") { $typeLines += $i } }
    $mainStart = @($typeLines | Where-Object { $_ -gt $fwEnd }) | Select-Object -First 1
    if ($null -eq $mainStart) { $mainStart = $typeLines | Select-Object -Last 1 }
    $class = $base; $ancestor = $null; $declared = @{}
    if ($null -eq $mainStart) {
        Add-Issue "error" 0 "No 'global type <name> from <ancestor>' line."
    } else {
        $null = $lines[$mainStart] -match "^global type ($id) from ($id)"
        $class = $Matches[1]; $ancestor = $Matches[2]
        if ($class -ine $base) { Add-Issue "error" ($mainStart + 1) "The object is named $class but the file is $base$ext; they must match." }
        $mainEnd = $mainStart + 1
        while ($mainEnd -lt $lines.Count -and $lines[$mainEnd] -ne "end type") { $mainEnd++ }
        for ($i = $mainStart + 1; $i -lt $mainEnd; $i++) {
            if ($lines[$i] -match "^event (?:type $id )?($id)\s*\((.*)\)\s*$") {
                $declared[$Matches[1].ToLower()] = @{ line = $i + 1; args = $Matches[2].Trim() }
            }
        }
        # The 'global <name> <name>' instance line isn't checked: many compiling objects don't have one.
    }

    # Scripts, functions and their end markers. Header forms found in compiling code: 'event name;', 'event name();',
    # 'event type long name (string as_x);', 'event cb_ok::clicked;', 'event destructor//comment' (no semicolon),
    # 'public function boolean of_x(boolean ab_x);' and 'public subroutine  of_y();'.
    $eventScript = "^event (?:type $id )?(?:${id}::)?($id)\s*(?:\(.*\))?\s*(?:;|//)"
    $funcHeader  = "^(?:public |protected |private )?(?:function $id|subroutine)\s+($id)\s*\("
    $scripts = @{}; $bodies = @{}; $prototypes = @{}
    $openEvents = 0; $endEvents = 0; $openFuncs = 0; $endFuncs = 0
    $inPrototypes = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $l = $lines[$i]
        if ($l -eq "forward prototypes") { $inPrototypes = $true; continue }
        if ($l -eq "end prototypes") { $inPrototypes = $false; continue }
        if ($inPrototypes) {
            if ($l -match $funcHeader) { $prototypes[$Matches[1].ToLower()] = $i + 1 }
            continue
        }
        if ($l -match $eventScript) { $scripts[$Matches[1].ToLower()] = $i + 1; $openEvents++ }
        elseif ($l -match '^\s*end event\s*$') { $endEvents++ }
        elseif ($l -match ($funcHeader + '.*\);')) { $bodies[$Matches[1].ToLower()] = $i + 1; $openFuncs++ }
        elseif ($l -match '^\s*end (function|subroutine)\s*$') { $endFuncs++ }
    }
    if ($openEvents -ne $endEvents) { Add-Issue "error" 0 "$openEvents event scripts but $endEvents 'end event' lines." }
    if ($openFuncs -ne $endFuncs) { Add-Issue "error" 0 "$openFuncs function or subroutine scripts but $endFuncs 'end function'/'end subroutine' lines." }
    # PowerBuilder compiles a prototype with no script, but in a test it is almost always a mistake.
    foreach ($name in $prototypes.Keys) { if (-not $bodies.ContainsKey($name)) { Add-Issue "warning" $prototypes[$name] "$name is in 'forward prototypes' but has no script." } }
    foreach ($name in $bodies.Keys) { if (-not $prototypes.ContainsKey($name)) { Add-Issue "error" $bodies[$name] "$name has a script but isn't listed in 'forward prototypes'." } }

    # Test events.
    $isTestClass = $class.ToLower().EndsWith("tests")
    foreach ($name in $declared.Keys) {
        if (-not $name.StartsWith("test")) { continue }
        if ($declared[$name].args) { Add-Issue "warning" $declared[$name].line "Test event $name takes arguments, so the runner won't run it." }
        elseif (-not $scripts.ContainsKey($name)) { Add-Issue "error" $declared[$name].line "Test event $name is declared but has no script ('event $name();' ... 'end event')." }
    }
    if ($isTestClass -and $ancestor -ieq "testcase") {
        foreach ($name in $scripts.Keys) {
            if ($name.StartsWith("test") -and -not $declared.ContainsKey($name)) {
                Add-Issue "error" $scripts[$name] "Event $name has a script but isn't declared in the main type block ('event $name ( )')."
            }
        }
    }
    if ($isTestClass -and $ancestor -and $ancestor -ine "testcase" -and -not $ancestor.ToLower().EndsWith("tests")) {
        Add-Issue "warning" ($mainStart + 1) "$class ends in 'tests' but inherits from $ancestor. The runner treats *tests classes as test classes, and reports 'Class does not inherit from testcase' unless the ancestor chain reaches testcase; rename helpers so they don't end in 'tests'."
    }
    if ($isTestClass -and @($declared.Keys | Where-Object { $_.StartsWith("test") }).Count -eq 0 -and $ancestor -ieq "testcase") {
        Add-Issue "warning" 0 "No test events: tests are events named test... with no arguments."
    }

    # create/destroy blocks aren't checked: compiling objects can lack them, and windows have extra ones for
    # their controls ('on cb_ok.create').

    return [ordered]@{
        file = $path; class = $class; ancestor = $ancestor; checked = $true; encoding = $encoding
        testEvents = @($declared.Keys | Where-Object { $_.StartsWith("test") } | Sort-Object)
        issues = @($issues | Sort-Object { $_.line })
    }
}

function Invoke-CheckSource($arguments) {
    $path = Resolve-UserPath $arguments["path"]
    $files = if ((Get-Item -LiteralPath $path).PSIsContainer) {
        @(Get-ChildItem -LiteralPath $path -File | Where-Object { $_.Extension -in ".sru", ".srw" } | ForEach-Object { $_.FullName })
    } else { @($path) }
    $results = @($files | ForEach-Object { Test-SourceFile $_ })
    $errorCount = 0; $warningCount = 0
    $lines = @()
    foreach ($r in $results) {
        foreach ($i in $r.issues) {
            if ($i.severity -eq "error") { $errorCount++ } else { $warningCount++ }
            $lines += "$($r.file)$(if ($i.line) { "($($i.line))" }): $($i.severity): $($i.message)"
        }
    }
    $lines = @("Checked $($results.Count) file(s): $errorCount errors, $warningCount warnings") + $lines
    return @{ text = ($lines -join "`n"); data = [ordered]@{ files = $results; errorCount = $errorCount; warningCount = $warningCount } }
}

# --- Protocol ---------------------------------------------------------------------------------

$Tools = @(
    [ordered]@{
        name = "find_projects"
        description = "Find PBUnit test projects (.pbproj files that list pbunit.pbl) under a folder and list their test classes and test events, without building. Also reports a missing framework (for example an uninitialized git submodule)."
        inputSchema = [ordered]@{ type = "object"; properties = [ordered]@{
            root = [ordered]@{ type = "string"; description = "Folder to search; defaults to the project folder" } } }
    },
    [ordered]@{
        name = "check_source"
        description = "Check PowerScript test sources (.sru/.srw) for layout mistakes the PowerBuilder compiler rejects or that stop tests from running: events or properties in the forward block, scripts without end markers, functions missing from forward prototypes, test events without scripts or with arguments, helper classes named *tests. Takes about a second, so use it before run_tests, which builds the project. It doesn't type-check code; run_tests reports compile errors."
        inputSchema = [ordered]@{ type = "object"; required = @("path"); properties = [ordered]@{
            path = [ordered]@{ type = "string"; description = "A .sru/.srw file, or a library folder to check all of them" } } }
    },
    [ordered]@{
        name = "run_tests"
        description = "Build a PBUnit test project with PBAutoBuild and run its tests (all, or a filter). Returns the outcome (PASS, FAIL, BUILD_FAILED, TIMEOUT, BLOCKED, NO_TESTS, ERROR), counts, failures grouped by message with hints, and compile errors with file and line. A build can take several minutes."
        inputSchema = [ordered]@{ type = "object"; properties = [ordered]@{
            project = [ordered]@{ type = "string"; description = "The test project's .pbproj, or a folder containing exactly one; defaults to the only test project under the project folder" }
            filter = [ordered]@{ type = "string"; description = "Comma-separated class or class.test names; a trailing * matches a prefix, e.g. n_cst_string_tests.test_trim*" }
            platform = [ordered]@{ type = "string"; enum = @("32", "64"); description = "Build a 32-bit (default) or 64-bit exe" }
            testTimeoutSeconds = [ordered]@{ type = "integer"; description = "How long the test exe may run, default 300; a test that opens a dialog hangs until this" } } }
    },
    [ordered]@{
        name = "get_results"
        description = "The results of the last run of a PBUnit test project (outcome, counts, failures grouped by message with hints), without building."
        inputSchema = [ordered]@{ type = "object"; properties = [ordered]@{
            project = [ordered]@{ type = "string"; description = "The test project's .pbproj, or a folder containing exactly one" }
            platform = [ordered]@{ type = "string"; enum = @("32", "64"); description = "Which build's results: 32 (default) or 64" } } }
    }
)

function Invoke-Tool([string]$name, $arguments, $progressToken) {
    if ($null -eq $arguments) { $arguments = @{} }
    try {
        $r = switch ($name) {
            "find_projects" { Invoke-FindProjects $arguments }
            "check_source"  { Invoke-CheckSource $arguments }
            "run_tests"     { Invoke-RunTests $arguments $progressToken }
            "get_results"   { Invoke-GetResults $arguments }
            default         { throw [ToolError]::new("Unknown tool: $name") }
        }
        $content = @([ordered]@{ type = "text"; text = $r.text }, [ordered]@{ type = "text"; text = ($r.data | ConvertTo-Json -Depth 32) })
        return [ordered]@{ content = $content; structuredContent = $r.data; isError = [bool]$r["isError"] }
    } catch [ToolError] {
        return [ordered]@{ content = @([ordered]@{ type = "text"; text = $_.Exception.Message }); isError = $true }
    } catch {
        Write-Log "tool $name failed: $($_ | Out-String)"
        return [ordered]@{ content = @([ordered]@{ type = "text"; text = "Internal error in ${name}: $($_.Exception.Message)" }); isError = $true }
    }
}

Write-Log "started (version $ServerVersion, project folder $ProjectDir)"
while ($null -ne ($line = $StdIn.ReadLine())) {
    if (-not $line.Trim()) { continue }
    try { $msg = $line | ConvertFrom-Json -AsHashtable }
    catch { Send-Message ([ordered]@{ jsonrpc = "2.0"; id = $null; error = [ordered]@{ code = -32700; message = "Parse error" } }); continue }
    if (-not $msg.ContainsKey("id") -or $null -eq $msg["id"]) { continue }   # a notification
    $id = $msg["id"]; $params = $msg["params"]
    try {
        $result = switch ($msg["method"]) {
            "initialize" {
                $version = if ($params -and $params["protocolVersion"]) { $params["protocolVersion"] } else { "2025-06-18" }
                [ordered]@{
                    protocolVersion = $version
                    capabilities = [ordered]@{ tools = [ordered]@{ listChanged = $false } }
                    serverInfo = [ordered]@{ name = "pbunit"; version = $ServerVersion }
                    instructions = "Tools for PBUnit tests in PowerBuilder 2025 solutions: find_projects, check_source (fast, before building), run_tests (builds; can take minutes), get_results."
                }
            }
            "ping"       { @{} }
            "tools/list" { [ordered]@{ tools = $Tools } }
            "tools/call" {
                $token = if ($params["_meta"]) { $params["_meta"]["progressToken"] } else { $null }
                Invoke-Tool $params["name"] $params["arguments"] $token
            }
            default { throw [System.Management.Automation.ItemNotFoundException]::new("Method not found: $($msg["method"])") }
        }
        Send-Message ([ordered]@{ jsonrpc = "2.0"; id = $id; result = $result })
    } catch [System.Management.Automation.ItemNotFoundException] {
        Send-Message ([ordered]@{ jsonrpc = "2.0"; id = $id; error = [ordered]@{ code = -32601; message = $_.Exception.Message } })
    } catch {
        Write-Log ($_ | Out-String)
        Send-Message ([ordered]@{ jsonrpc = "2.0"; id = $id; error = [ordered]@{ code = -32603; message = $_.Exception.Message } })
    }
}
