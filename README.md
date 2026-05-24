# Wi-Fi Roam Watcher v1.2

Wi-Fi Roam Watcher is a Windows PowerShell tool for monitoring Wi-Fi roaming behaviour from a client laptop.

It uses built-in Windows `netsh wlan` commands to track the connected SSID, AP/BSSID, optional AP aliases, signal, RSSI, channel, band, radio type, RX/TX rates, visible AP count, roaming events, disconnect/reconnect events, and client-side Wi-Fi diagnostic evidence.

## What is new in v1.1

- Added zero-BSSID handling for cases where Windows reports the connected AP/BSSID as `00:00:00:00:00:00`.
- Added automatic diagnostic bundle creation when zero-BSSID is detected.
- Added `modules\WiFiRoamWatcher.Diagnostics.ps1`.
- Added Administrator-aware WLAN report capture.
- Added `wlanreport_wait_seconds` so the script waits for `wlan-report-latest.html` to finish before copying it.
- Added AP count debounce to reduce noisy AP count changes from partial Windows scan results.
- Kept AP alias support from v1.0, including alias display, alias logging, and live alias-file reload.

## How to run

Open PowerShell in the extracted folder and run:

```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\Start-WiFiRoamWatcher.ps1
```

For PowerShell 7:

```powershell
pwsh.exe -ExecutionPolicy Bypass -NoProfile -File .\Start-WiFiRoamWatcher.ps1
```

For full WLAN HTML report collection, run PowerShell as Administrator.

Press `CTRL+C` to stop.

## Troubleshooting

If PowerShell shows an error such as:

```text
Access to the path '.\Start-WiFiRoamWatcher.ps1' is denied.
```

see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Roadmap

Future ideas and planned improvements are tracked in [ROADMAP.md](ROADMAP.md).

## Startup options

When the script starts, choose one of these options:

```text
1. Auto - monitor any SSID I am connected to
2. Use current connected SSID
3. Enter SSID manually
Q. Quit
```

Option 1 follows whichever SSID the laptop is currently connected to. If the laptop disconnects and later connects to another SSID, the monitor follows the new connected SSID.

Option 2 locks the monitor to the SSID connected at startup.

Option 3 lets the user type an SSID manually.

## Folder layout

```text
Wi-Fi Roam Watcher\
│
├── Start-WiFiRoamWatcher.ps1
├── config.cfg
├── README.md
├── TROUBLESHOOTING.md
├── VERSION.txt
├── ap_aliases.csv.example
│
└── modules\
    ├── WiFiRoamWatcher.Aliases.ps1
    ├── WiFiRoamWatcher.Common.ps1
    ├── WiFiRoamWatcher.Config.ps1
    ├── WiFiRoamWatcher.Diagnostics.ps1
    ├── WiFiRoamWatcher.Netsh.ps1
    └── WiFiRoamWatcher.Display.ps1
```

The `diagnostics\` folder is created automatically when a diagnostic capture is needed.

## config.cfg

Default config:

```ini
# ==============================================================================
# Wi-Fi Roam Watcher v1.1 Configuration
# ==============================================================================
#
# Notes:
# - Lines starting with # are comments.
# - Use key=value format.
# - Do not wrap values in quotes.
# - Leave folder/path values blank to use the same folder as Start-WiFiRoamWatcher.ps1.
# - Relative paths are resolved from the script folder.
#

# ------------------------------------------------------------------------------
# AP ALIASES
# ------------------------------------------------------------------------------
# Optional friendly names for AP/BSSID values.
#
# CSV format:
#   Match,Alias
#   00:a7:42:f5:5e:2f,Example-AP-Name
#
# ap_alias_list_path:
#   Folder containing the alias CSV files.
#   Blank = script folder.
#
# ap_alias_list:
#   Comma-separated list of alias CSV files.
#   Blank = disable aliases.
#
# Examples:
#   ap_alias_list=ap_aliases.csv
#   ap_alias_list=floor1_aps.csv,floor2_aps.csv
#
ap_alias_list_path=
ap_alias_list=ap_aliases.csv

# ------------------------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------------------------
# log_path:
#   Folder where the active log file and rotated logs are stored.
#   Blank = script folder.
#
# log_filename:
#   Active log filename.
#
# log_rotation:
#   true  = rotate the log when a new day starts.
#   false = keep writing to the same log file.
#
# log_retention:
#   How long to keep rotated log files.
#   Supported units: d = days, w = weeks, m = months.
#   Examples: 1d, 7d, 2w, 1m
#
log_path=
log_filename=wifi_roam_watcher.log
log_rotation=true
log_retention=1d

# ------------------------------------------------------------------------------
# DIAGNOSTIC CAPTURE
# ------------------------------------------------------------------------------
# diagnostics_enabled:
#   true  = allow diagnostic bundles to be created.
#   false = disable diagnostic bundles.
#
# diagnostics_path:
#   Folder where diagnostic bundles are saved.
#   Relative paths are based on the script folder.
#
# zero_bssid_diagnostics:
#   true  = capture evidence if Windows reports the connected BSSID as
#           00:00:00:00:00:00.
#   false = suppress the zero-BSSID event but do not create a diagnostic bundle.
#
# zero_bssid_diagnostic_cooldown_seconds:
#   Minimum time between repeated zero-BSSID diagnostic captures.
#
# wlanreport_duration_days:
#   Used by: netsh wlan show wlanreport duration=N
#
# wlanreport_wait_seconds:
#   How long to wait for wlan-report-latest.html to be generated before copying it.
#
# Important:
# - Windows requires Administrator rights for netsh wlan show wlanreport.
# - Without Administrator rights, the script still captures interfaces.txt,
#   networks-bssid.txt, and drivers.txt, then skips the WLAN HTML report cleanly.
#
diagnostics_enabled=true
diagnostics_path=diagnostics
zero_bssid_diagnostics=true
zero_bssid_diagnostic_cooldown_seconds=300
wlanreport_duration_days=3
wlanreport_wait_seconds=90

# ------------------------------------------------------------------------------
# AP COUNT CHANGE DEBOUNCE
# ------------------------------------------------------------------------------
# Windows can sometimes return partial scan results from:
#   netsh wlan show networks mode=bssid
#
# ap_count_debounce_samples:
#   Number of repeated samples required before logging an AP count change.
#   Higher value = less noisy AP_COUNT logs.
#
ap_count_debounce_samples=3
```

### Logging settings

`log_path=` is the folder where logs are stored. If empty, the script folder is used.

`log_filename=` is the active log filename. The default is:

```ini
log_filename=wifi_roam_watcher.log
```

`log_rotation=true` enables daily log rotation. Use `false` to disable it.

`log_retention=` controls how long rotated logs are kept. Examples:

```ini
log_retention=1d
log_retention=2d
log_retention=1w
log_retention=1m
```


## AP aliases

AP aliases are optional. They let you display friendly AP names next to BSSIDs in the live screen and logs.

In `config.cfg`:

```ini
ap_alias_list_path=
ap_alias_list=floor1_aps.csv,floor2_aps.csv
```

`ap_alias_list_path=` is the folder containing alias CSV files. If empty, the script folder is used.

`ap_alias_list=` is a comma-separated list of CSV files. Leave it empty to disable aliases. Missing files are skipped, so you can list optional alias files safely.

CSV format:

```csv
Match,Alias
24:71:21:89:1c:ef,ZTN-D-C1A-F1-17
89:1c,ZTN-D-C1A-F1-17
```

`Match` can be a full BSSID or a partial BSSID fragment. Alias files are reloaded while the script runs, and alias changes are logged as `ALIAS_UPDATE`.

## Zero-BSSID diagnostics

v1.1 treats this connected BSSID as invalid/pending:

```text
00:00:00:00:00:00
```

This value is not treated as a real AP. When it appears, Wi-Fi Roam Watcher suppresses START, ROAM, RECONNECTED, and DISCONNECTED changes until Windows reports a valid connected BSSID again.

When zero-BSSID is detected, the script creates a timestamped diagnostic folder under:

```text
.\diagnostics\
```

Example:

```text
diagnostics\20260521_070125-zbs\
```

The diagnostic folder contains:

```text
summary.txt
interfaces.txt
networks-bssid.txt
drivers.txt
wlanreport-output.txt
wlan-yyyyMMdd_HHmmss.html
```

The script captures:

```powershell
netsh wlan show interfaces
netsh wlan show networks mode=bssid
netsh wlan show drivers
netsh wlan show wlanreport duration=N
```

Windows writes the WLAN report to its normal location:

```text
C:\ProgramData\Microsoft\Windows\WlanReport\wlan-report-latest.html
```

When the script is running as Administrator, Wi-Fi Roam Watcher copies that file into the timestamped diagnostic folder, for example:

```text
diagnostics\20260521_070125-zbs\wlan-20260521_070125.html
```

The original Windows report is not moved or deleted.

If the script is not running as Administrator, v1.1 still captures `interfaces.txt`, `networks-bssid.txt`, and `drivers.txt`, but the WLAN HTML report is skipped cleanly. The reason is written to `wlanreport-output.txt`.

### Diagnostic settings

```ini
diagnostics_enabled=true
```

Enables or disables all diagnostic bundle creation.

```ini
diagnostics_path=diagnostics
```

Sets where diagnostic bundles are stored. Relative paths are based on the script folder.

```ini
zero_bssid_diagnostics=true
```

Enables or disables diagnostic capture for invalid/zero connected BSSID events.

```ini
zero_bssid_diagnostic_cooldown_seconds=300
```

Prevents repeated diagnostic bundles every loop while the same issue is still happening.

```ini
wlanreport_duration_days=3
```

Controls the duration used by `netsh wlan show wlanreport duration=N`.

```ini
wlanreport_wait_seconds=90
```

Controls how long the script waits for `wlan-report-latest.html` to finish before copying it into the diagnostic bundle. This only applies when the script is running as Administrator.

## AP count debounce

Windows can sometimes return partial scan results from:

```powershell
netsh wlan show networks mode=bssid
```

This can make the visible AP count jump briefly, for example `10 -> 1 -> 10`.

v1.1 debounces AP count changes with:

```ini
ap_count_debounce_samples=3
```

A new AP count must be seen repeatedly before an `AP_COUNT` event is written.

## Log event types

Common log events:

```text
STARTUP       Script started.
START         First connected AP detected.
ROAMED        Client moved from one BSSID/AP to another.
SIGNAL        Signal or RSSI changed enough to log.
DISCONNECTED  Client disconnected from the monitored SSID.
RECONNECTED   Client reconnected to the monitored SSID.
AUTO_SSID     Auto mode changed the monitored SSID.
AP_COUNT      Visible AP count changed while connected.
ALIAS_UPDATE  AP alias was added, changed, or removed while visible.
DIAG          Diagnostic capture started or completed.
DIAG_WARN     Diagnostic capture completed with a warning.
DIAG_ERROR    Diagnostic capture failed.
WARN          Invalid/pending connected BSSID detected.
INFO          Invalid/pending connected BSSID recovered.
LOG_ROTATE    Log file was rotated.
LOG_RETENTION Old rotated log file was deleted.
ERROR         Script caught an error but continued running.
```

## Netsh commands used

Wi-Fi Roam Watcher uses:

```powershell
netsh wlan show interfaces all
```

This reads the current Wi-Fi connection and provides the connected SSID, BSSID, signal, real connected RSSI, band, channel, radio type, RX rate, and TX rate.

Example fields used:

```text
State                  : connected
SSID                   : MySSID
AP BSSID               : 00:a7:42:f5:5e:2f
Band                   : 5 GHz
Channel                : 100
Radio type             : 802.11ac
Receive rate (Mbps)    : 400
Transmit rate (Mbps)   : 400
Signal                 : 92%
Rssi                   : -42
```

The second command is:

```powershell
netsh wlan show networks mode=bssid
```

This scans visible SSIDs and BSSIDs/APs. The script uses it to list visible APs for the monitored SSID and to get BSSID, signal percentage, and channel.

Important: real RSSI is only taken from `netsh wlan show interfaces all` for the connected AP. The visible AP list from `netsh wlan show networks mode=bssid` provides signal percentage, not real RSSI per BSSID.

## Quick user steps

1. Extract the folder.
2. Run `Start-WiFiRoamWatcher.ps1` using the command above.
3. Select option 1, 2, or 3.
4. Optionally configure logging and diagnostics in `config.cfg`.
5. Check `wifi_roam_watcher.log` for events.
6. If zero-BSSID happens, check the generated folder under `diagnostics\`.

## Privacy note

The WLAN HTML report can contain computer names, usernames, domain details, saved Wi-Fi profiles, certificate information, IP configuration, and other environment details. Review or sanitize the report before sharing it externally.
