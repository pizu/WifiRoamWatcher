# Wi-Fi Roam Watcher Troubleshooting

This file contains common startup and runtime issues for Wi-Fi Roam Watcher.

---

## PowerShell says: Access to the path is denied

Example error:

```text
Access to the path '...\Start-WiFiRoamWatcher.ps1' is denied.
CategoryInfo          : ObjectNotFound
FullyQualifiedErrorId : CommandNotFoundException
```

This usually means Windows cannot read or execute the script file properly.

Common causes:

- The ZIP file was downloaded from the internet and Windows blocked the extracted files.
- The script file has incorrect permissions.
- `Start-WiFiRoamWatcher.ps1` is accidentally a folder instead of a file.
- The script is being run from a protected or problematic folder.

---

## Fix 1: Check that the script is a real file

Open PowerShell in the Wi-Fi Roam Watcher folder and run:

```powershell
Get-Item .\Start-WiFiRoamWatcher.ps1 -Force | Format-List FullName,Mode,Length,Attributes
```

If the `Mode` starts with `d`, then `Start-WiFiRoamWatcher.ps1` is a directory, not a PowerShell script file.

In that case, re-extract the ZIP file or download the release again.

---

## Fix 2: Unblock downloaded files

Run this from inside the extracted Wi-Fi Roam Watcher folder:

```powershell
Get-ChildItem -Recurse -File | Unblock-File
```

Then start the script again:

```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "& '.\Start-WiFiRoamWatcher.ps1'"
```

Or:

```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -File ".\Start-WiFiRoamWatcher.ps1"
```

---

## Fix 3: Check file permissions

Run:

```powershell
icacls .\Start-WiFiRoamWatcher.ps1
```

If your user does not have read access, grant read permission:

```powershell
icacls .\Start-WiFiRoamWatcher.ps1 /grant "$env:USERNAME:R"
```

Then run the script again:

```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -File ".\Start-WiFiRoamWatcher.ps1"
```

---

## Fix 4: Move the tool to a simple folder

If the script still does not start correctly, copy the Wi-Fi Roam Watcher folder to a simpler path, for example:

```text
C:\Tools\WifiRoamWatcher
```

If you are already inside the extracted Wi-Fi Roam Watcher folder, run:

```powershell
mkdir C:\Tools -Force

Copy-Item "." "C:\Tools\WifiRoamWatcher" -Recurse -Force

cd C:\Tools\WifiRoamWatcher

Get-ChildItem -Recurse -File | Unblock-File

powershell.exe -ExecutionPolicy Bypass -NoProfile -File ".\Start-WiFiRoamWatcher.ps1"
```

---

## Administrator note

Wi-Fi Roam Watcher can run without Administrator rights for normal monitoring.

However, full WLAN HTML report collection requires PowerShell to be opened as Administrator.

Without Administrator rights, the script still captures the basic diagnostic text files and skips the WLAN HTML report cleanly.

---

## Extra diagnostics

If the issue continues, collect the following output and include it when reporting the problem:

```powershell
dir -Force

Get-Item .\Start-WiFiRoamWatcher.ps1 -Force | Format-List *

icacls .\Start-WiFiRoamWatcher.ps1
```
