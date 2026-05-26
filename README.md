# Wi-Fi Roam Watcher v1.2

Wi-Fi Roam Watcher is a Windows PowerShell tool for monitoring Wi-Fi roaming behaviour from a client laptop.

It uses built-in Windows `netsh wlan` commands to track the connected SSID, AP/BSSID, optional AP aliases, signal, RSSI, channel, band, radio type, RX/TX rates, visible AP count, roaming events, disconnect/reconnect events, and client-side Wi-Fi diagnostic evidence.

## What is new in v1.2

- Improved roaming event logging with clearer before/after AP, signal, RSSI, channel, and visible AP count context.
- Improved signal-change logging with signal and RSSI deltas.
- Improved AP count change logging with connected AP context.
- Improved disconnect and reconnect logging with last-known AP details.
- Improved alias update logging with `CONNECTED` and `VISIBLE` status.
- Refreshed connected AP alias display after live alias updates.
- Avoided logging the full local config file path at startup.
- Added `refresh_interval_seconds` so the monitor loop refresh interval can be configured.
- Added logging when `refresh_interval_seconds` is changed while the script is running.
- Kept the current PowerShell and `netsh wlan` workflow.

## Previous v1.1 highlights

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
├── ROADMAP.md
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
# Wi-Fi Roam Watcher v1.2 Configuration
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
# REFRESH INTERVAL
# ------------------------------------------------------------------------------
# refresh_interval_seconds:
#   How often the monitor loop refreshes Wi-Fi status.
#   Lower values react faster but run netsh more often.
#   Higher values are quieter and lighter.
#
# Notes:
# - Default is 2 seconds.
# - Minimum accepted value is 1 second.
# - This setting is re-read while the script is running.
# - When changed, a CONFIG event is written to the log.
#
refresh_interval_seconds=2

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

### Refresh interval setting

`refresh_interval_seconds=` controls how often Wi-Fi Roam Watcher refreshes the current Wi-Fi state.

The default is:

```ini
refresh_interval_seconds=2
```

A lower value reacts faster to roaming, disconnects, reconnects, signal changes, and AP count changes, but it runs the Windows `netsh` checks more often.

A higher value is lighter and quieter, but changes may be detected slightly later.

The setting is re-read while the script is running. If the value changes, the script logs a `CONFIG` event similar to:

```text
[2026-05-25 22:10:00] CONFIG: refresh_interval_seconds changed from 2 to 5
```

## AP aliases

AP aliases are optional. They let you display friendly AP names next to BSSIDs in the live screen and logs.

In `config.cfg`:

```ini
ap_alias_list_path=
ap_alias_list=ap_aliases.csv
```

`ap_alias_list_path=` is the folder containing alias CSV files. If empty, the script folder is used.

`ap_alias_list=` is a comma-separated list of CSV files. Leave it empty to disable aliases. Missing files are skipped, so you can list optional alias files safely.

CSV format:

```csv
Match,Alias
24:71:21:89:1c:ef,Example-AP-Name
89:1c,Example-AP-Name
```

`Match` can be a full BSSID or a partial BSSID fragment. Alias files are reloaded while the script runs, and alias changes are logged as `ALIAS_UPDATE`.

When aliases are updated while the script is running, v1.2 logs whether the BSSID is currently connected or only visible:

```text
[2026-05-25 21:57:31] ALIAS_UPDATE: BSSID 00:a7:42:f5:5e:2f now has alias [Example-AP-Name] | SSID: MySSID | Signal: 95% | Chan: 100 | Status: VISIBLE
[2026-05-25 21:57:31] ALIAS_UPDATE: BSSID f0:7f:06:cd:30:4f now has alias [Example-AP-Name-2] | SSID: MySSID | Signal: 94% | Chan: 132 | Status: CONNECTED
```

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
CONFIG        Runtime configuration value changed.
DIAG          Diagnostic capture started or completed.
DIAG_WARN     Diagnostic capture completed with a warning.
DIAG_ERROR    Diagnostic capture failed.
WARN          Invalid/pending connected BSSID detected.
INFO          Invalid/pending connected BSSID recovered.
LOG_ROTATE    Log file was rotated.
LOG_RETENTION Old rotated log file was deleted.
ERROR         Script caught an error but continued running.
```

## Example v1.2 log entries

Roaming event:

```text
[2026-05-25 21:41:54] ROAMED: SSID: MySSID | From: 00:a7:42:f5:5e:2f [Example-AP-Name] | Signal: 95% | RSSI: -38 dBm | Chan: 100 | To: f0:7f:06:cd:30:4f [Example-AP-Name-2] | Signal: 99% | RSSI: -40 dBm | Chan: 132 | Delta: Signal +4% | RSSI -2 dB | Visible APs: 2 | Mode: Auto
```

Signal/RSSI change event:

```text
[2026-05-25 21:44:22] SIGNAL: SSID: MySSID | AP: f0:7f:06:cd:30:4f [Example-AP-Name-2] | Signal: 99% -> 94% (-5%) | RSSI: -40 dBm -> -46 dBm (-6 dB) | Chan: 132 | Visible APs: 1 | Mode: Auto
```

AP count change event:

```text
[2026-05-25 21:59:08] AP_COUNT: SSID: MySSID | Visible APs: 2 -> 1 (-1) | Connected AP: f0:7f:06:cd:30:4f [Example-AP-Name-2] | Signal: 94% | RSSI: -38 dBm | Chan: 132 | Mode: Auto
```

Reconnect event:

```text
[2026-05-25 21:41:24] RECONNECTED: SSID: MySSID | AP: 00:a7:42:f5:5e:2f [Example-AP-Name] | Signal: 99% | RSSI: -38 dBm | Chan: 100 | Previous AP before disconnect: 00:a7:42:f5:5e:2f [Example-AP-Name] | Previous Signal: 95% | Previous RSSI: -37 dBm | Previous Chan: 100 | Delta: Signal +4% | RSSI -1 dB | Visible APs: 2 | Mode: Auto
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
4. Optionally configure logging, refresh interval, AP aliases, and diagnostics in `config.cfg`.
5. Check `wifi_roam_watcher.log` for events.
6. If zero-BSSID happens, check the generated folder under `diagnostics\`.

## Privacy note

The WLAN HTML report can contain computer names, usernames, domain details, saved Wi-Fi profiles, certificate information, IP configuration, and other environment details. Review or sanitize the report before sharing it externally.

Wi-Fi Roam Watcher v1.2 also avoids logging the full local config file path during startup.
