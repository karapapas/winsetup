# WinSetup - Interactive Windows Program Manager

An interactive PowerShell tool that helps you manage installed programs on Windows. Instead of maintaining static lists, **WinSetup** detects what's currently installed and lets you choose what to keep or uninstall through a beautiful terminal UI.

## Overview

WinSetup provides an **interactive interface** to:
- 🔍 **Detect** all installed programs via `winget`
- ☑️  **Select** programs to keep using an intuitive multi-select menu
- 🗑️  **Uninstall** programs you don't need with confirmation
- 📊 **Review** a summary of what was removed

## Features

- Interactive numbered list selection in the terminal
- Arrow-free input (type numbers like: 1,3,5-10)
- Range support for bulk selections 
- Safe defaults - explicit confirmation required before uninstallation
- Automatic detection of installed programs via winget
- Dry-run mode for testing without making changes
- Built-in self-elevation (automatically requests admin rights)
- No external dependencies - uses only built-in PowerShell

## Prerequisites

- Windows 10/11 with PowerShell 5.1 or later
- winget installed (pre-installed on Windows 11 and recent Windows 10 builds)
- Administrator privileges (script will auto-elevate)

## Installation

1. Clone the repository:
   ```powershell
   git clone <repository-url>
   cd winsetup
   ```

2. Run the script:
   ```powershell
   .\winsetup.ps1
   ```

## Usage

### Basic Usage

Run the script:

```powershell
.\winsetup.ps1
```

What happens:
1. Script detects all installed programs via `winget list`
2. Displays a numbered list of all programs
3. You type the numbers of programs to uninstall (e.g., `1,3,5-10`)
   - Or press Enter without typing to exit
4. Shows confirmation with list of selected programs
5. Uninstalls after you type `yes`
6. After uninstallation, asks if you want to uninstall more programs
   - Type `yes` to return to the menu and select more programs
   - Type `no` to exit

### Dry Run Mode

Test the script without making any actual changes:

```powershell
.\winsetup.ps1 -DryRun
```

In dry-run mode:
- All steps execute normally (program detection, selection, confirmation)
- Instead of actually uninstalling programs, the script shows what commands would be executed
- No winget uninstall commands are run
- You can safely test your selections without affecting your system
- Perfect for verifying which programs would be removed before committing to the action

Example output in dry-run mode:
```
[*] Uninstalling: Candy Crush Saga
    [DRY RUN] Would execute: winget uninstall --id "king.CandyCrushSaga" --silent
```

### Selection Syntax

When prompted, you can enter:
- Single numbers: `5`
- Multiple numbers: `1,3,7,10`
- Ranges: `5-10`
- Mixed: `1,3,5-10,15`
- Nothing (just Enter): Exits without uninstalling

## Example Workflow

```powershell
PS C:\winsetup> .\winsetup.ps1

==================================================================
          WinSetup - Interactive Program Manager              
==================================================================

[*] Detecting installed programs via winget...
[OK] Found 47 installed programs

================================================================
       WinSetup - Interactive Program Manager                
================================================================

Installed Programs:

  1. Microsoft Edge                        (Microsoft.Edge)
  2. Git                                    (Git.Git)
  3. Visual Studio Code                     (Microsoft.VisualStudioCode)
  4. Candy Crush Saga                       (king.CandyCrushSaga)
  5. Xbox Game Bar                          (Microsoft.XboxGameBar)
  ...

Instructions:
  - Enter the numbers of programs to UNINSTALL (comma-separated)
  - Example: 1,3,5-7,10
  - Press Enter without typing anything to exit

Enter program numbers to uninstall: 4,5

================================================================
                 UNINSTALL CONFIRMATION                      
================================================================

The following 2 program(s) will be UNINSTALLED:

  X Candy Crush Saga
    ID: king.CandyCrushSaga | Version: 1.0.0.0
  X Xbox Game Bar
    ID: Microsoft.XboxGameBar | Version: 5.721.2911.0

Are you sure you want to proceed? (yes/no): yes

================================================================
                 UNINSTALLATION PROGRESS                     
================================================================

[*] Uninstalling: Candy Crush Saga
    [OK] Successfully uninstalled

[*] Uninstalling: Xbox Game Bar
    [OK] Successfully uninstalled

================================================================
                       SUMMARY                                
================================================================

  OK Successful: 2
```

### Error: winget not found
- **Solution**: Update Windows or install [App Installer](https://www.microsoft.com/p/app-installer/9nblggh4nns1) from the Microsoft Store

### Error: Cannot be loaded because running scripts is disabled
- **Solution**: Run PowerShell as Administrator and execute:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

### Error: Permission denied / Access denied
- Solution: The script will auto-elevate. If it fails, right-click PowerShell and select "Run as Administrator"

### Program fails to uninstall
- Some programs may require manual uninstallation through Windows Settings
- Check the summary section for specific error messages
- Try running `winget uninstall --id <ProgramId>` manually to see detailed error

## Safety Features

- Explicit selection required - user must type program numbers
- Confirmation prompt shows exactly what will be uninstalled
- Dry-run mode available for testing
- Auto-elevation with user consent (UAC prompt)
- Error handling continues with remaining programs if one fails
- Clear summary of results at the end

## Notes

- Scripts run in **silent mode** to minimize interaction during uninstall
- Some programs may require a **system restart** after uninstallation
- The script only shows programs from the **winget source** (excludes Microsoft Store apps installed via different methods)
- Uninstallation is **permanent** - make sure you've selected the correct programs

## Migration from Old Version

If you were using the previous batch-based version with `install.bat` and `uninstall.bat`:

**Old workflow**: Maintain text files with programs to install/uninstall
**New workflow**: Interactive detection and selection at runtime

The old batch files and text files (`software-to-install.txt`, `software-to-uninstall.txt`) are deprecated and will be removed in the next version.

## License

This project is open source and available for personal and commercial use.
