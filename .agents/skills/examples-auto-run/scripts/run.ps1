# Examples Auto-Run Skill - PowerShell Script
# Automatically discovers and runs example scripts in the repository,
# capturing output and reporting success/failure for each example.

param(
    [string]$ExamplesDir = "examples",
    [string]$PythonCmd = "python",
    [int]$TimeoutSeconds = 60,
    [switch]$FailFast,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "../../..")

# Results tracking
$Results = @{
    Passed  = @()
    Failed  = @()
    Skipped = @()
}

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
}

function Write-Status {
    param(
        [string]$Status,
        [string]$Message
    )
    switch ($Status) {
        "PASS"  { Write-Host "  [PASS] $Message" -ForegroundColor Green }
        "FAIL"  { Write-Host "  [FAIL] $Message" -ForegroundColor Red }
        "SKIP"  { Write-Host "  [SKIP] $Message" -ForegroundColor Yellow }
        "INFO"  { Write-Host "  [INFO] $Message" -ForegroundColor Blue }
        default { Write-Host "  $Message" }
    }
}

function Test-PythonAvailable {
    try {
        $null = & $PythonCmd --version 2>&1
        return $true
    } catch {
        return $false
    }
}

function Get-ExampleFiles {
    param([string]$Directory)
    $fullPath = Join-Path $RepoRoot $Directory
    if (-not (Test-Path $fullPath)) {
        Write-Status "INFO" "Examples directory not found: $fullPath"
        return @()
    }
    return Get-ChildItem -Path $fullPath -Filter "*.py" -Recurse |
        Where-Object { $_.Name -notmatch '^_' } |
        Sort-Object FullName
}

function Invoke-Example {
    param([System.IO.FileInfo]$File)
    $relativePath = $File.FullName.Substring($RepoRoot.ToString().Length).TrimStart('\', '/')

    # Check for skip marker in file
    $content = Get-Content $File.FullName -Raw -ErrorAction SilentlyContinue
    if ($content -match '# ?skip-auto-run') {
        Write-Status "SKIP" $relativePath
        $Results.Skipped += $relativePath
        return
    }

    if ($Verbose) {
        Write-Status "INFO" "Running: $relativePath"
    }

    try {
        $process = Start-Process -FilePath $PythonCmd `
            -ArgumentList $File.FullName `
            -WorkingDirectory $RepoRoot `
            -RedirectStandardOutput "$env:TEMP\example_stdout.txt" `
            -RedirectStandardError "$env:TEMP\example_stderr.txt" `
            -PassThru -NoNewWindow

        $completed = $process.WaitForExit($TimeoutSeconds * 1000)

        if (-not $completed) {
            $process.Kill()
            Write-Status "FAIL" "$relativePath (timeout after ${TimeoutSeconds}s)"
            $Results.Failed += $relativePath
            return
        }

        if ($process.ExitCode -eq 0) {
            Write-Status "PASS" $relativePath
            $Results.Passed += $relativePath
        } else {
            Write-Status "FAIL" "$relativePath (exit code: $($process.ExitCode))"
            if ($Verbose) {
                $stderr = Get-Content "$env:TEMP\example_stderr.txt" -Raw -ErrorAction SilentlyContinue
                if ($stderr) { Write-Host $stderr -ForegroundColor Red }
            }
            $Results.Failed += $relativePath
        }
    } catch {
        Write-Status "FAIL" "$relativePath (error: $_)"
        $Results.Failed += $relativePath
    }
}

function Write-Summary {
    Write-Header "Summary"
    $total = $Results.Passed.Count + $Results.Failed.Count + $Results.Skipped.Count
    Write-Host "  Total:   $total"
    Write-Host "  Passed:  $($Results.Passed.Count)" -ForegroundColor Green
    Write-Host "  Failed:  $($Results.Failed.Count)" -ForegroundColor $(if ($Results.Failed.Count -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  Skipped: $($Results.Skipped.Count)" -ForegroundColor Yellow

    if ($Results.Failed.Count -gt 0) {
        Write-Host ""
        Write-Host "  Failed examples:" -ForegroundColor Red
        foreach ($f in $Results.Failed) {
            Write-Host "    - $f" -ForegroundColor Red
        }
    }
}

# ── Main ──────────────────────────────────────────────────────────────────────
Write-Header "Examples Auto-Run"

if (-not (Test-PythonAvailable)) {
    Write-Host "ERROR: Python not found. Ensure '$PythonCmd' is available." -ForegroundColor Red
    exit 1
}

$examples = Get-ExampleFiles -Directory $ExamplesDir
if ($examples.Count -eq 0) {
    Write-Status "INFO" "No example files found in '$ExamplesDir'."
    exit 0
}

Write-Status "INFO" "Found $($examples.Count) example file(s) in '$ExamplesDir'"

foreach ($example in $examples) {
    Invoke-Example -File $example
    if ($FailFast -and $Results.Failed.Count -gt 0) {
        Write-Host ""
        Write-Host "Stopping early due to -FailFast flag." -ForegroundColor Yellow
        break
    }
}

Write-Summary

if ($Results.Failed.Count -gt 0) {
    exit 1
}
exit 0
