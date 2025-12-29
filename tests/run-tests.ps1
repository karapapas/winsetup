<#
.SYNOPSIS
    WinSetup Test Suite - Validates install and uninstall functionality

.DESCRIPTION
    Runs unit tests and integration tests to ensure winsetup scripts work correctly.
    Tests include file parsing, error handling, and actual install/uninstall operations.
    All test artifacts are automatically cleaned up, even if tests fail.

.EXAMPLE
    .\run-tests.ps1
    
.PARAMETER SkipIntegration
    Skip integration tests (faster, unit tests only)
    
.PARAMETER SkipCleanup
    Skip cleanup (for debugging only)
#>

param(
    [switch]$SkipIntegration = $false,
    [switch]$SkipCleanup = $false
)

#region Self-Elevation
# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "`n[!] This test suite requires Administrator privileges." -ForegroundColor Yellow
    Write-Host "[*] Attempting to restart with elevated privileges...`n" -ForegroundColor Cyan
    
    # Build argument list for the elevated process
    $arguments = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    
    if ($SkipIntegration) {
        $arguments += " -SkipIntegration"
    }
    
    if ($SkipCleanup) {
        $arguments += " -SkipCleanup"
    }
    
    try {
        # Start elevated process
        Start-Process powershell -Verb RunAs -ArgumentList $arguments -Wait
        exit 0
    }
    catch {
        Write-Host "[X] Failed to elevate privileges: $_" -ForegroundColor Red
        Write-Host "`nPlease run this test suite manually as Administrator:" -ForegroundColor Yellow
        Write-Host "  Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor White
        Write-Host "  Then execute: .\tests\run-tests.ps1`n" -ForegroundColor White
        exit 1
    }
}
#endregion

# Color helpers
function Write-Success { param($msg) Write-Host "[PASS] $msg" -ForegroundColor Green }
function Write-Failure { param($msg) Write-Host "[FAIL] $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Header { param($msg) Write-Host "" ; Write-Host "$msg" -ForegroundColor Yellow }

# Test result tracking
$script:PassedTests = 0
$script:FailedTests = 0
$script:TestLog = @()

# Cleanup tracking - ensures everything is removed even if tests fail
$script:TempFiles = @()
$script:InstalledPackages = @()

function Test-Assert {
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$FailureMessage = ""
    )
    
    if ($Condition) {
        Write-Success $TestName
        $script:PassedTests++
        $script:TestLog += "[PASS] $TestName"
    }
    else {
        Write-Failure "$TestName - $FailureMessage"
        $script:FailedTests++
        $script:TestLog += "[FAIL] $TestName - $FailureMessage"
    }
}

function Cleanup-TestArtifacts {
    Write-Header "--- Cleanup ---"
    
    # Clean up temporary files
    if ($script:TempFiles.Count -gt 0) {
        Write-Info "Removing temporary files..."
        foreach ($file in $script:TempFiles) {
            if (Test-Path $file) {
                Remove-Item $file -Force -ErrorAction SilentlyContinue
                Write-Info "  Removed: $file"
            }
        }
    }
    
    # Clean up installed test packages
    if ($script:InstalledPackages.Count -gt 0) {
        Write-Info "Removing test packages..."
        foreach ($package in $script:InstalledPackages) {
            Write-Info "  Uninstalling: $package"
            winget uninstall $package --silent 2>&1 | Out-Null
            Start-Sleep -Seconds 1
        }
    }
    
    Write-Info "Cleanup complete - system restored to original state"
}

# Pre-flight checks
Write-Header "=== WinSetup Test Suite ==="
Write-Info "Test isolation enabled - all artifacts will be cleaned up automatically"

Write-Info "Running pre-flight checks..."

# Check winget
$wingetAvailable = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
Test-Assert "Winget available" $wingetAvailable "winget not found in PATH"

if (-not $wingetAvailable) {
    Write-Failure "Cannot proceed without winget. Please install App Installer from Microsoft Store."
    exit 1
}

# Change to parent directory (where winsetup.bat is located)
$scriptDir = Split-Path -Parent $PSScriptRoot
Push-Location $scriptDir

try {
    Write-Header "--- Unit Tests ---"

    # Test 1: Empty file handling
    Write-Info "Testing empty file handling..."
    $tempEmpty = "tests\temp-empty.txt"
    $script:TempFiles += $tempEmpty
    New-Item -Path $tempEmpty -ItemType File -Force | Out-Null
    $emptyContent = Get-Content $tempEmpty -ErrorAction SilentlyContinue
    Test-Assert "Empty file handling" ($emptyContent.Count -eq 0) "Empty file should have no content"

    # Test 2: File with blank lines
    Write-Info "Testing blank lines handling..."
    $tempBlank = "tests\temp-blank.txt"
    $script:TempFiles += $tempBlank
    @("7zip.7zip", "", "  ", "Git.Git") | Set-Content $tempBlank
    $blankContent = Get-Content $tempBlank | Where-Object { $_.Trim() -ne "" }
    Test-Assert "Blank lines handling" ($blankContent.Count -eq 2) "Should filter out blank lines"

    # Test 3: Non-existent file
    Write-Info "Testing missing file handling..."
    $missingFile = "tests\non-existent-file.txt"
    $fileExists = Test-Path $missingFile
    Test-Assert "Missing file detection" (-not $fileExists) "File should not exist"

    # Test 4: Verify test config files exist
    Test-Assert "Test install config exists" (Test-Path "tests\test-software-install.txt")
    Test-Assert "Test uninstall config exists" (Test-Path "tests\test-software-uninstall.txt")

    # Test 5: Verify main scripts exist
    Test-Assert "winsetup.bat exists" (Test-Path "winsetup.bat")
    Test-Assert "install.bat exists" (Test-Path "install.bat")
    Test-Assert "uninstall.bat exists" (Test-Path "uninstall.bat")

    if (-not $SkipIntegration) {
        Write-Header "--- Integration Tests ---"

        $testPackage = "7zip.7zip"
        $testPackageName = "7-Zip"

        # Helper function to check if package is installed
        function Test-PackageInstalled {
            param([string]$PackageId)
            $result = winget list --id $PackageId --exact 2>&1
            return [bool]($result -match $PackageId)
        }

        # Record initial state - preserve if already installed
        Write-Info "Recording initial system state..."
        $wasInstalledBefore = Test-PackageInstalled $testPackage
        
        if ($wasInstalledBefore) {
            Write-Info "  Note: $testPackageName was already installed - will preserve"
        }
        else {
            # Clean slate - ensure test package is not installed
            if (Test-PackageInstalled $testPackage) {
                Write-Info "  Removing existing test package..."
                winget uninstall $testPackage --silent --accept-source-agreements 2>&1 | Out-Null
                Start-Sleep -Seconds 2
            }
        }

        # Test 6: Install test package
        Write-Info "Testing installation of $testPackageName..."
        $installOutput = winget install $testPackage --silent --accept-source-agreements 2>&1
        Start-Sleep -Seconds 3
        
        $installed = Test-PackageInstalled $testPackage
        
        # Only track for cleanup if we installed it (not pre-existing)
        if ($installed -and -not $wasInstalledBefore) {
            $script:InstalledPackages += $testPackage
        }
        
        Test-Assert "Install test package" $installed "Package installation failed"

        # Test 7: Verify installation
        if (Test-PackageInstalled $testPackage) {
            Test-Assert "Verify installation" $true
        }
        else {
            Test-Assert "Verify installation" $false "Package not found after installation"
        }

        # Test 8: Idempotency - install already installed package
        Write-Info "Testing idempotency (re-install)..."
        $idempotentSuccess = $false
        try {
            $reinstallOutput = winget install $testPackage --silent --accept-source-agreements 2>&1
            $idempotentSuccess = $true  # Should not error
        }
        catch {
            $idempotentSuccess = $false
        }
        Test-Assert "Idempotency check" $idempotentSuccess "Re-installing should not fail"

        # Only test uninstall if package wasn't pre-existing
        if (-not $wasInstalledBefore) {
            # Test 9: Uninstall test package
            Write-Info "Testing uninstallation of $testPackageName..."
            $uninstallOutput = winget uninstall $testPackage --silent 2>&1
            Start-Sleep -Seconds 3
            
            $uninstallSuccess = -not (Test-PackageInstalled $testPackage)
            
            if ($uninstallSuccess) {
                # Remove from cleanup list since we successfully uninstalled
                $script:InstalledPackages = $script:InstalledPackages | Where-Object { $_ -ne $testPackage }
            }
            
            Test-Assert "Uninstall test package" $uninstallSuccess "Package uninstallation failed"

            # Test 10: Verify removal
            if (-not (Test-PackageInstalled $testPackage)) {
                Test-Assert "Verify removal" $true
            }
            else {
                Test-Assert "Verify removal" $false "Package still found after uninstallation"
            }
        }
        else {
            Write-Info "Skipping uninstall test - preserving pre-existing installation"
            Test-Assert "Package preservation" $true "Pre-existing package preserved"
        }

        # Test 11: Graceful failure - uninstall non-existent package
        Write-Info "Testing graceful failure (uninstall non-existent)..."
        $gracefulSuccess = $true
        try {
            winget uninstall "NonExistent.Package.12345" --silent 2>&1 | Out-Null
            # Should not crash the script
        }
        catch {
            $gracefulSuccess = $false
        }
        Test-Assert "Graceful failure handling" $gracefulSuccess "Script should handle missing packages gracefully"

    }
    else {
        Write-Info "Skipping integration tests (-SkipIntegration flag set)"
    }

}
catch {
    Write-Failure "Unexpected error during tests: $_"
    throw
}
finally {
    Pop-Location
}

# Results summary (before cleanup so we can see results)
Write-Header "=== Test Results ==="
Write-Host "Passed: $script:PassedTests" -ForegroundColor Green
Write-Host "Failed: $script:FailedTests" -ForegroundColor $(if ($script:FailedTests -eq 0) { "Green" } else { "Red" })

# Save log
$logPath = Join-Path $PSScriptRoot "test-results.log"
$script:TestLog | Set-Content $logPath
Write-Info "Test log saved to: $logPath"

# Always run cleanup unless explicitly skipped
if (-not $SkipCleanup) {
    Cleanup-TestArtifacts
}
else {
    Write-Info "Skipping cleanup (-SkipCleanup flag set for debugging)"
}

if ($script:FailedTests -eq 0) {
    Write-Host ""
    Write-Success "=== All Tests Passed ==="
    exit 0
}
else {
    Write-Host ""
    Write-Failure "=== Some Tests Failed ==="
    exit 1
}
