# Windows Setup Automation

A lightweight automation tool to streamline Windows setup by removing bloatware and installing essential developer tools.

## Overview

This project provides simple batch scripts that leverage `winget` (Windows Package Manager) to:
- **Uninstall** unwanted bloatware and pre-installed Windows apps
- **Install** essential developer tools and applications

## Prerequisites

- **Windows 10/11** with `winget` installed (comes pre-installed on Windows 11 and recent Windows 10 builds)
- **Administrator privileges** (required for installing/uninstalling software)

## Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd winsetup
   ```

2. **Customize software lists** (optional):
   - Edit `software-to-install.txt` to add/remove applications you want to install
   - Edit `software-to-uninstall.txt` to add/remove bloatware you want to remove

## Usage

### Unified Entry Point (Recommended)

The recommended way to use this tool is through the unified `winsetup.bat` script:

**Uninstall Bloatware:**
```cmd
winsetup.bat uninstall
```

**Install Developer Tools:**
```cmd
winsetup.bat install
```

**Show Help:**
```cmd
winsetup.bat help
```

> **Note**: Right-click and select **"Run as Administrator"**, or run from an elevated command prompt.

### Backward Compatibility

The original `install.bat` and `uninstall.bat` scripts are still available for backward compatibility. They now call the unified `winsetup.bat` script internally:

```cmd
# These still work:
install.bat
uninstall.bat
```

## Default Software

### Pre-configured installations:
- Git
- 7-Zip
- Notepad++
- Visual Studio Code
- Google Chrome
- Python 3.12
- Docker Desktop

### Pre-configured removals:
- Xbox apps (Game Bar, TCUI, Gaming Overlay, etc.)
- Bing Weather
- Zune Music & Video
- Windows Feedback Hub
- Maps, Your Phone, Office Hub
- And other common Windows bloatware

## Customization

### Adding software to install:
1. Find the winget package ID by running:
   ```cmd
   winget search <app-name>
   ```
2. Add the package ID to `software-to-install.txt` (one per line)

### Adding software to uninstall:
1. Find the package ID by running:
   ```cmd
   winget list
   ```
2. Add the package ID to `software-to-uninstall.txt` (one per line)

## Troubleshooting

- **Error: winget not found**: Update to the latest version of Windows or install [App Installer](https://www.microsoft.com/p/app-installer/9nblggh4nns1) from the Microsoft Store
- **Permission denied**: Ensure you're running the scripts as Administrator
- **Package not found**: Verify the package ID is correct using `winget search <package-name>`

## Testing

A comprehensive test suite is available to validate install and uninstall functionality.

### Running Tests

**Prerequisites:**
- PowerShell 5.1 or later
- Administrator privileges (automatically requested)
- winget installed

**Easy Method (Recommended):**

Simply double-click `tests\run-tests.bat` or run:

```cmd
cd tests
run-tests.bat
```

This automatically handles admin elevation and execution policy.

**Advanced Options:**

```powershell
# PowerShell as Administrator with execution policy bypass
cd tests
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
.\run-tests.ps1

# Skip integration tests (faster, unit tests only)
.\run-tests.ps1 -SkipIntegration
```

### What Gets Tested

**Unit Tests:**
- File handling (empty files, blank lines, missing files)
- Script file existence validation
- Configuration file validation

**Integration Tests:**
- Install test package (7-Zip)
- Verify installation succeeded
- Uninstall test package
- Verify removal succeeded
- Idempotency checks (re-installing already installed packages)
- Graceful failure handling (non-existent packages)

### Expected Output

When all tests pass, you'll see:
```
=== WinSetup Test Suite ===
[✓] Admin check
[✓] Winget available

--- Unit Tests ---
[✓] Empty file handling
[✓] Blank lines handling
... (more tests)

--- Integration Tests ---
[✓] Install test package
[✓] Verify installation
... (more tests)

=== Test Results ===
Passed: 17
Failed: 0
[✓] === All Tests Passed ===
```

Test results are saved to `tests/test-results.log`.

For more details, see [tests/README.md](tests/README.md).

## Notes

- Scripts run in **silent mode** (`--silent` flag) to minimize user interaction
- For safety, review the software lists before running the scripts
- Some apps may require a system restart after installation/uninstallation
- Run the test suite before making changes to validate functionality

## Future Improvements

See [SUGGESTIONS.md](SUGGESTIONS.md) for planned enhancements and recommendations.

## License

This project is open source and available for personal and commercial use.
