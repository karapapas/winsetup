# WinSetup Test Suite

## Overview

This test suite validates the install and uninstall functionality of the WinSetup automation tool. It includes both unit tests (logic validation) and integration tests (actual winget operations).

## Prerequisites

- Windows 10/11 with PowerShell 5.1+
- winget installed and available in PATH
- Administrator privileges (script will auto-elevate)

## Running Tests

### Quick Start (Recommended)

Simply double-click `run-tests.bat` in the `tests` folder, or run:

```cmd
cd tests
run-tests.bat
```

Or run the PowerShell script directly:

```powershell
.\tests\run-tests.ps1
```

The test suite will automatically:
- Request Administrator privileges if needed (UAC prompt)
- Bypass PowerShell execution policy
- Run all tests
- Clean up test artifacts
- Display results

### Skip Integration Tests

To run only unit tests (faster):

```powershell
.\tests\run-tests.ps1 -SkipIntegration
```

### What Gets Tested

#### Unit Tests
- Empty software list files
- Files with blank lines
- Non-existent files
- Error handling

#### Integration Tests
- Install test package (7-Zip)
- Verify package installation
- Uninstall test package
- Verify package removal
- Idempotency checks
- Graceful failure handling

## Test Package

The test suite uses **7-Zip** (`7zip.7zip`) as the test package because:
- Small download size (~2MB)
- Safe and widely used
- No system dependencies
- Easy to install/uninstall
- Available in winget

## Expected Output

```
=== WinSetup Test Suite ===
[✓] Admin check passed
[✓] Winget available

--- Unit Tests ---
[✓] Empty file handling
[✓] Blank lines handling
[✓] Missing file handling

--- Integration Tests ---
[✓] Install test package (7zip)
[✓] Verify installation
[✓] Uninstall test package
[✓] Verify removal

=== All Tests Passed ===
```

## Cleanup

The test suite automatically cleans up after itself. If you need to manually clean up:

```powershell
winget uninstall 7zip.7zip
```

## Adding New Tests

To add new test cases:

1. Edit `test-software-install.txt` or `test-software-uninstall.txt` to add package IDs
2. Update `run-tests.ps1` to include new test logic
3. Use small, safe packages for integration tests

## Troubleshooting

**Tests fail with "Admin required"**
- The script should auto-elevate. If it fails, manually run PowerShell as Administrator

**Tests fail with "winget not found"**
- Ensure winget is installed and in PATH
- Update Windows to the latest version

**Integration tests timeout**
- Check your internet connection
- Verify winget can reach package repositories
