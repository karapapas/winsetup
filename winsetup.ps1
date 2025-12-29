#Requires -Version 5.1

<#
.SYNOPSIS
    WinSetup - Interactive Windows Program Manager

.DESCRIPTION
    Detects all installed programs via winget and presents an interactive numbered list
    to choose which programs to uninstall.

.PARAMETER DryRun
    Show what would be uninstalled without actually executing the uninstall commands.

.EXAMPLE
    .\winsetup.ps1
    Runs the interactive program manager to select programs for uninstallation.

.EXAMPLE
    .\winsetup.ps1 -DryRun
    Simulates the uninstallation process without making actual changes.
#>

[CmdletBinding()]
param(
    [switch]$DryRun
)

#region Self-Elevation
# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "`n[!] This script requires Administrator privileges." -ForegroundColor Yellow
    Write-Host "[*] Attempting to restart with elevated privileges...`n" -ForegroundColor Cyan
    
    # Build argument list for the elevated process
    $arguments = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    
    if ($DryRun) {
        $arguments += " -DryRun"
    }
    
    try {
        # Start elevated process
        Start-Process powershell -Verb RunAs -ArgumentList $arguments -Wait
        exit 0
    }
    catch {
        Write-Host "[X] Failed to elevate privileges: $_" -ForegroundColor Red
        Write-Host "`nPlease run this script manually as Administrator:" -ForegroundColor Yellow
        Write-Host "  Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor White
        Write-Host "  Then execute: .\winsetup.ps1`n" -ForegroundColor White
        exit 1
    }
}
#endregion

# Color definitions for console output
$script:ColorSuccess = "Green"
$script:ColorWarning = "Yellow"
$script:ColorError = "Red"
$script:ColorInfo = "Cyan"

#region Helper Functions

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Get-WingetInstalledPrograms {
    <#
    .SYNOPSIS
        Queries winget for all installed programs and returns structured data.
    #>
    Write-ColorOutput "`n[*] Detecting installed programs via winget..." -Color $script:ColorInfo
    
    try {
        # Run winget list and capture output
        $wingetOutput = winget list --disable-interactivity 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "winget command failed with exit code $LASTEXITCODE"
        }
        
        # Parse the output
        $programs = @()
        $inDataSection = $false
        
        foreach ($line in $wingetOutput) {
            $lineStr = $line.ToString()
            
            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($lineStr)) { continue }
            
            # Detect the header line (contains "Name" and "Id")
            if ($lineStr -match "^Name\s+Id\s+Version") {
                $inDataSection = $true
                continue
            }
            
            # Skip separator line (dashes)
            if ($lineStr -match "^-+\s+-+\s+-+") {
                continue
            }
            
            # Parse data lines
            if ($inDataSection -and $lineStr -notmatch "^\d+ upgrades available" -and $lineStr -notmatch "^The following packages") {
                # Split by multiple spaces (2+ spaces typically separate columns in winget output)
                $parts = [regex]::Split($lineStr, '\s\s+') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                
                if ($parts.Count -ge 2) {
                    $program = [PSCustomObject]@{
                        Name    = $parts[0].Trim()
                        Id      = $parts[1].Trim()  # Keep exact ID as-is from winget
                        Version = if ($parts.Count -ge 3) { $parts[2].Trim() } else { "Unknown" }
                        Source  = if ($parts.Count -ge 5) { $parts[4].Trim() } else { "Unknown" }
                    }
                    
                    # Only include programs from winget source (skip msstore, local installers, etc.)
                    if ($program.Source -eq "winget" -or $program.Source -eq "Unknown") {
                        $programs += $program
                    }
                }
            }
        }
        
        Write-ColorOutput "[OK] Found $($programs.Count) installed programs`n" -Color $script:ColorSuccess
        return $programs
    }
    catch {
        Write-ColorOutput "[X] Failed to get installed programs: $_" -Color $script:ColorError
        throw
    }
}

function Show-ProgramSelectionMenu {
    <#
    .SYNOPSIS
        Displays a numbered list of programs and prompts user to select which to uninstall.
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Programs
    )
    
    Write-ColorOutput "`n================================================================" -Color $script:ColorInfo
    Write-ColorOutput "       WinSetup - Interactive Program Manager                " -Color $script:ColorInfo
    Write-ColorOutput "================================================================`n" -Color $script:ColorInfo
    
    Write-ColorOutput "Installed Programs:`n" -Color $script:ColorWarning
    
    # Display numbered list
    for ($i = 0; $i -lt $Programs.Count; $i++) {
        $num = $i + 1
        $program = $Programs[$i]
        
        # Show full ID without any truncation
        Write-Host ("{0,3}. {1,-40} ({2})" -f $num, $program.Name, $program.Id) -ForegroundColor White
    }
    
    Write-Host ""
    Write-ColorOutput "Instructions:" -Color $script:ColorWarning
    Write-ColorOutput "  - Enter the numbers of programs to UNINSTALL (comma-separated)" -Color "White"
    Write-ColorOutput "  - Example: 1,3,5-7,10" -Color "DarkGray"
    Write-ColorOutput "  - Press Enter without typing anything to exit`n" -Color "White"
    
    # Get user input
    $selection = Read-Host "Enter program numbers to uninstall"
    
    if ([string]::IsNullOrWhiteSpace($selection)) {
        return @()
    }
    
    # Parse selection (supports: 1,2,3 or 1-3 or mix)
    $selectedIndexes = @()
    $parts = $selection -split ','
    
    foreach ($part in $parts) {
        $part = $part.Trim()
        
        if ($part -match '^\d+-\d+$') {
            # Range (e.g., "5-10")
            $range = $part -split '-'
            $start = [int]$range[0]
            $end = [int]$range[1]
            
            for ($i = $start; $i -le $end; $i++) {
                if ($i -ge 1 -and $i -le $Programs.Count) {
                    $selectedIndexes += ($i - 1)
                }
            }
        }
        elseif ($part -match '^\d+$') {
            # Single number
            $num = [int]$part
            if ($num -ge 1 -and $num -le $Programs.Count) {
                $selectedIndexes += ($num - 1)
            }
        }
    }
    
    # Get unique indexes and return corresponding programs
    $selectedIndexes = $selectedIndexes | Select-Object -Unique | Sort-Object
    $selectedPrograms = @()
    
    foreach ($index in $selectedIndexes) {
        $selectedPrograms += $Programs[$index]
    }
    
    return $selectedPrograms
}

function Confirm-UninstallAction {
    <#
    .SYNOPSIS
        Shows a confirmation prompt for programs about to be uninstalled.
    #>
    param(
        [Parameter(Mandatory)]
        [array]$ProgramsToUninstall,
        
        [bool]$IsDryRun = $false
    )
    
    if ($ProgramsToUninstall.Count -eq 0) {
        Write-ColorOutput "`n[!] No programs selected for uninstallation. Exiting.`n" -Color $script:ColorWarning
        return $false
    }
    
    Write-ColorOutput "`n================================================================" -Color $script:ColorError
    Write-ColorOutput "                 UNINSTALL CONFIRMATION                      " -Color $script:ColorError
    Write-ColorOutput "================================================================`n" -Color $script:ColorError
    
    if ($IsDryRun) {
        Write-ColorOutput "[DRY RUN MODE] The following programs WOULD be uninstalled:`n" -Color $script:ColorWarning
    }
    else {
        Write-ColorOutput "The following $($ProgramsToUninstall.Count) program(s) will be UNINSTALLED:`n" -Color $script:ColorError
    }
    
    foreach ($program in $ProgramsToUninstall) {
        Write-ColorOutput "  X $($program.Name)" -Color "Red"
        Write-ColorOutput "    ID: $($program.Id) | Version: $($program.Version)" -Color "DarkGray"
    }
    
    Write-Host ""
    $confirmation = Read-Host "Are you sure you want to proceed? (yes/no)"
    
    return ($confirmation -eq 'yes' -or $confirmation -eq 'y')
}

function Invoke-ProgramUninstall {
    <#
    .SYNOPSIS
        Executes the uninstallation of selected programs.
    #>
    param(
        [Parameter(Mandatory)]
        [array]$ProgramsToUninstall,
        
        [bool]$IsDryRun = $false
    )
    
    $successCount = 0
    $failureCount = 0
    $failedPrograms = @()
    
    Write-ColorOutput "`n================================================================" -Color $script:ColorInfo
    Write-ColorOutput "                 UNINSTALLATION PROGRESS                     " -Color $script:ColorInfo
    Write-ColorOutput "================================================================`n" -Color $script:ColorInfo
    
    foreach ($program in $ProgramsToUninstall) {
        Write-ColorOutput "[*] Uninstalling: $($program.Name)" -Color $script:ColorInfo
        
        if ($IsDryRun) {
            Write-ColorOutput "    [DRY RUN] Would execute: winget uninstall --name '$($program.Name)' --silent" -Color $script:ColorWarning
            Start-Sleep -Milliseconds 500
            $successCount++
        }
        else {
            try {
                # Show the command being executed (debug)
                Write-ColorOutput "    [DEBUG] Executing: winget uninstall --name '$($program.Name)' --silent --disable-interactivity" -Color "DarkGray"
                
                # Execute winget uninstall using name instead of ID
                winget uninstall --name "$($program.Name)" --silent --disable-interactivity 2>&1 | Out-Null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-ColorOutput "    [OK] Successfully uninstalled" -Color $script:ColorSuccess
                    $successCount++
                }
                else {
                    Write-ColorOutput "    [X] Failed (Exit code: $LASTEXITCODE)" -Color $script:ColorError
                    $failureCount++
                    $failedPrograms += $program
                }
            }
            catch {
                Write-ColorOutput "    [X] Error: $_" -Color $script:ColorError
                $failureCount++
                $failedPrograms += $program
            }
        }
        Write-Host ""
    }
    
    # Summary
    Write-ColorOutput "================================================================" -Color $script:ColorInfo
    Write-ColorOutput "                       SUMMARY                                " -Color $script:ColorInfo
    Write-ColorOutput "================================================================`n" -Color $script:ColorInfo
    
    Write-ColorOutput "  OK Successful: $successCount" -Color $script:ColorSuccess
    
    if ($failureCount -gt 0) {
        Write-ColorOutput "  X Failed: $failureCount" -Color $script:ColorError
        Write-ColorOutput "`nFailed programs:" -Color $script:ColorError
        foreach ($failed in $failedPrograms) {
            Write-ColorOutput "  - $($failed.Name) ($($failed.Id))" -Color "Red"
        }
    }
    
    Write-Host ""
}

#endregion

#region Main Execution

function Main {
    # Display banner
    Write-Host "`n"
    Write-ColorOutput "==================================================================" -Color "Cyan"
    Write-ColorOutput "          WinSetup - Interactive Program Manager              " -Color "Cyan"
    Write-ColorOutput "==================================================================" -Color "Cyan"
    
    if ($DryRun) {
        Write-ColorOutput "`n[DRY RUN MODE ENABLED - No actual changes will be made]`n" -Color $script:ColorWarning
    }
    
    # Main loop - allows user to return to menu after uninstallation
    $continue = $true
    
    while ($continue) {
        # Get installed programs
        try {
            $allPrograms = Get-WingetInstalledPrograms
            
            if ($allPrograms.Count -eq 0) {
                Write-ColorOutput "[!] No programs detected. This might be an error with winget.`n" -Color $script:ColorWarning
                exit 1
            }
        }
        catch {
            Write-ColorOutput "`n[X] Failed to retrieve installed programs. Exiting.`n" -Color $script:ColorError
            exit 1
        }
        
        # Show interactive selection menu
        $programsToUninstall = Show-ProgramSelectionMenu -Programs $allPrograms
        
        # Check if user wants to exit (empty selection)
        if ($programsToUninstall.Count -eq 0) {
            Write-ColorOutput "`n[!] No programs selected. Exiting.`n" -Color $script:ColorWarning
            $continue = $false
            break
        }
        
        # Show confirmation
        if (-not (Confirm-UninstallAction -ProgramsToUninstall $programsToUninstall -IsDryRun:$DryRun)) {
            Write-ColorOutput "[!] Uninstallation cancelled by user.`n" -Color $script:ColorWarning
            # Ask if user wants to try again or exit
            $retry = Read-Host "Would you like to select different programs? (yes/no)"
            if ($retry -ne 'yes' -and $retry -ne 'y') {
                $continue = $false
            }
            continue
        }
        
        # Execute uninstallation
        Invoke-ProgramUninstall -ProgramsToUninstall $programsToUninstall -IsDryRun:$DryRun
        
        if (-not $DryRun) {
            Write-ColorOutput "Note: Some programs may require a system restart to complete uninstallation.`n" -Color $script:ColorInfo
        }
        
        # Ask if user wants to continue or exit
        Write-Host ""
        $continueChoice = Read-Host "Would you like to uninstall more programs? (yes/no)"
        
        if ($continueChoice -ne 'yes' -and $continueChoice -ne 'y') {
            $continue = $false
            Write-ColorOutput "`n[OK] Exiting WinSetup. Goodbye!`n" -Color $script:ColorSuccess
        }
    }
}

# Run main function
Main

#endregion
