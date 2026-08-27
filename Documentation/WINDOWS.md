# CodexMeter for Windows

CodexMeter for Windows is a native .NET 8 WPF tray application for Windows 10 and Windows 11. It reads local Codex token-count events from `%USERPROFILE%\.codex\sessions` and `%USERPROFILE%\.codex\archived_sessions`.

## Install

1. Download the x64 or ARM64 ZIP and `SHA256SUMS-windows.txt` from the public [`windows-v0.1.1` GitHub release](https://github.com/HechoLP/CodexMeter-Releases/releases/tag/windows-v0.1.1).
2. Verify the downloaded ZIP in PowerShell:

   ```powershell
   Get-FileHash .\CodexMeter-Windows-0.1.1-x64.zip -Algorithm SHA256
   Get-Content .\SHA256SUMS-windows.txt
   ```

3. Confirm that the two SHA-256 values are identical, then extract the ZIP to a permanent folder such as `%LOCALAPPDATA%\Programs\CodexMeter`.
4. Because the preview is not code-signed, Windows SmartScreen may display a warning. Run only the file whose hash matches the official release manifest. If Windows marks the downloaded executable as blocked, use **Properties → Unblock** or:

   ```powershell
   Unblock-File .\CodexMeter.exe
   Start-Process .\CodexMeter.exe
   ```

The application starts as a diamond icon in the notification area. Windows may place it inside the hidden-icons menu initially.

## Features

- Today, this week, this month, and all locally available usage
- Input, cached input, output, and total-token breakdowns
- Icon-only notification-area presence by default
- File-system event refresh with a configurable fallback interval
- Launch at sign-in using the current user's Windows `Run` registry key
- In-memory changed-file cache; no prompts, responses, source code, credentials, or raw paths are persisted
- Duplicate archived-session protection and inherited subagent-history exclusion

## Build

Install the .NET 8 SDK and run from the repository root:

```powershell
dotnet restore .\Windows\CodexMeter.Windows.sln
dotnet test .\Windows\CodexMeter.Windows.sln --configuration Release
.\Windows\Scripts\package.ps1 -RuntimeIdentifier win-x64 -ResetManifest
.\Windows\Scripts\package.ps1 -RuntimeIdentifier win-arm64
```

The packages and checksums are written to `Artifacts`.

## Privacy and limitations

The Windows app scans only the two supported `.codex` session roots. It does not read `auth.json`, use Codex credentials, or send usage totals over the network. The initial Windows preview is a portable, unsigned ZIP rather than an installed MSIX package; removing the extracted folder uninstalls the app. Disable **Launch at sign-in** first if it was enabled.
