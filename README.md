# Wi-Fi Roam Watcher

Wi-Fi Roam Watcher is a Windows PowerShell tool for monitoring Wi-Fi roaming behaviour from a client laptop.

It uses built-in Windows `netsh wlan` commands to show the current Wi-Fi connection, track roaming between BSSIDs/APs, log signal and RSSI changes, detect disconnect/reconnect events, and optionally collect diagnostic evidence.

Current version: **v1.2.1**

## Features

- Monitor the currently connected Wi-Fi SSID.
- Track connected AP/BSSID, optional AP alias, signal, RSSI, channel, band, radio type, RX rate, and TX rate.
- Detect roaming events between APs/BSSIDs.
- Detect disconnect and reconnect events.
- Track visible AP count for the monitored SSID.
- Log signal and RSSI changes with before/after values.
- Support optional AP alias CSV files.
- Reload AP aliases while the script is running.
- Support configurable refresh interval.
- Support optional diagnostic bundle creation.
- Support daily log rotation and log retention.

## Requirements

- Windows
- Windows PowerShell 5.1 or PowerShell 7
- Built-in Windows `netsh wlan` command

Normal monitoring does not require Administrator rights.

Administrator rights are only needed when collecting the full Windows WLAN HTML report as part of a diagnostic bundle.

## Quick start

1. Download and extract the project.
2. Open PowerShell in the extracted folder.
3. Run the script:

```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\Start-WiFiRoamWatcher.ps1
```

For PowerShell 7:

```powershell
pwsh.exe -ExecutionPolicy Bypass -NoProfile -File .\Start-WiFiRoamWatcher.ps1
```

Press `CTRL+C` to stop the monitor.

## Startup options

When the script starts, choose one of these options:

```text
1. Auto - monitor any SSID I am connected to
2. Use current connected SSID
3. Enter SSID manually
Q. Quit
```

### Option 1: Auto

Follows whichever SSID the laptop is currently connected to.

If the laptop disconnects and later connects to another SSID, the monitor follows the new connected SSID.

### Option 2: Use current connected SSID

Locks the monitor to the SSID connected at startup.

### Option 3: Enter SSID manually

Lets you type the SSID to monitor.

## Folder layout

```text
Wi-Fi Roam Watcher\
│
├── Start-WiFiRoamWatcher.ps1
├── config.cfg
├── README.md
├── CHANGELOG.md
├── ROADMAP.md
├── TROUBLESHOOTING.md
├── VERSION.txt
├── ap_aliases.csv.example
│
├── .github\
│   └── workflows\
│
└── modules\
    ├── WiFiRoamWatcher.Aliases.ps1
    ├── WiFiRoamWatcher.Common.ps1
    ├── WiFiRoamWatcher.Config.ps1
    ├── WiFiRoamWatcher.Diagnostics.ps1
    ├── WiFiRoamWatcher.Display.ps1
    └── WiFiRoamWatcher.Netsh.ps1
```

The `diagnostics\` folder is created automatically when a diagnostic capture is needed.

## Configuration

The main configuration file is:

```text
config.cfg
```

The file uses simple `key=value` settings.

Rules:

- Lines starting with `#` are comments.
- Do not wrap values in quotes.
- Leave folder/path values blank to use the same folder as `Start-WiFiRoamWatcher.ps1`.
- Relative paths are resolved from the script folder.

Example:

```ini
ap_alias_list_path=
ap_alias_list=ap_aliases.csv

log_path=
log_filename=wifi_roam_watcher.log
log_rotation=true
log_retention=1d

refresh_interval_seconds=2

diagnostics_enabled=true
diagnostics_path=diagnostics
zero_bssid_diagnostics=true
zero_bssid_diagnostic_cooldown_seconds=300
wlanreport_duration_days=3
wlanreport_wait_seconds=90

ap_count_debounce_samples=3
```

### Common settings

| Setting | Purpose |
|---|---|
| `ap_alias_list_path` | Folder containing AP alias CSV files. Blank means script folder. |
| `ap_alias_list` | Comma-separated alias CSV files. Blank disables aliases. |
| `log_path` | Folder where logs are stored. Blank means script folder. |
| `log_filename` | Active log filename. |
| `log_rotation` | Enables or disables daily log rotation. |
| `log_retention` | How long rotated logs are kept, for example `1d`, `7d`, `2w`, or `1m`. |
| `refresh_interval_seconds` | How often Wi-Fi status is refreshed. Default is `2`. |
| `diagnostics_enabled` | Enables or disables diagnostic bundle creation. |
| `diagnostics_path` | Folder where diagnostic bundles are saved. |
| `zero_bssid_diagnostics` | Enables diagnostic capture when Windows reports an invalid connected BSSID. |
| `zero_bssid_diagnostic_cooldown_seconds` | Minimum time between repeated zero-BSSID diagnostic captures. |
| `wlanreport_duration_days` | Duration used for `netsh wlan show wlanreport duration=N`. |
| `wlanreport_wait_seconds` | How long to wait for the WLAN HTML report before copying it. |
| `ap_count_debounce_samples` | Repeated AP count samples required before logging an AP count change. |

## Refresh interval

`refresh_interval_seconds` controls how often Wi-Fi Roam Watcher refreshes the current Wi-Fi state.

Default:

```ini
refresh_interval_seconds=2
```

Lower values detect changes faster but run `netsh` more often.

Higher values are quieter and lighter but may detect changes slightly later.

This setting is re-read while the script is running. If it changes, a `CONFIG` event is written to the log.

## AP aliases

AP aliases are optional friendly names for BSSIDs/APs.

In `config.cfg`:

```ini
ap_alias_list_path=
ap_alias_list=ap_aliases.csv
```

CSV format:

```csv
Match,Alias
24:71:21:89:1c:ef,Example-AP-Name
89:1c,Example-AP-Name
```

`Match` can be a full BSSID or a partial BSSID fragment.

Alias files are reloaded while the script runs. Alias changes are logged as `ALIAS_UPDATE`.

## Logging

Default log file:

```text
wifi_roam_watcher.log
```

Common log event types:

| Event | Meaning |
|---|---|
| `STARTUP` | Script started. |
| `START` | First connected AP detected. |
| `ROAMED` | Client moved from one BSSID/AP to another. |
| `SIGNAL` | Signal or RSSI changed enough to log. |
| `DISCONNECTED` | Client disconnected from the monitored SSID. |
| `RECONNECTED` | Client reconnected to the monitored SSID. |
| `AUTO_SSID` | Auto mode changed the monitored SSID. |
| `AP_COUNT` | Visible AP count changed while connected. |
| `ALIAS_UPDATE` | AP alias was added, changed, or removed while visible. |
| `CONFIG` | Runtime configuration value changed. |
| `DIAG` | Diagnostic capture started or completed. |
| `DIAG_WARN` | Diagnostic capture completed with a warning. |
| `DIAG_ERROR` | Diagnostic capture failed. |
| `WARN` | Invalid or pending connected BSSID detected. |
| `INFO` | Invalid or pending connected BSSID recovered. |
| `LOG_ROTATE` | Log file was rotated. |
| `LOG_RETENTION` | Old rotated log file was deleted. |
| `ERROR` | Script caught an error but continued running. |

## Diagnostics

Wi-Fi Roam Watcher can create diagnostic bundles when configured to do so.

Diagnostic bundles are saved under:

```text
diagnostics\
```

A diagnostic bundle may include:

```text
summary.txt
interfaces.txt
networks-bssid.txt
drivers.txt
wlanreport-output.txt
wlan-yyyyMMdd_HHmmss.html
```

The text files are collected using:

```powershell
netsh wlan show interfaces
netsh wlan show networks mode=bssid
netsh wlan show drivers
netsh wlan show wlanreport duration=N
```

The full WLAN HTML report requires Administrator rights.

Without Administrator rights, the script still captures the basic diagnostic text files and skips the WLAN HTML report cleanly.

## Netsh data notes

Wi-Fi Roam Watcher uses:

```powershell
netsh wlan show interfaces all
```

This provides the current connected Wi-Fi details, including connected SSID, BSSID, signal, RSSI, band, channel, radio type, RX rate, and TX rate.

It also uses:

```powershell
netsh wlan show networks mode=bssid
```

This provides visible SSIDs and BSSIDs/APs, including signal percentage and channel.

Important note:

- Real RSSI is taken from `netsh wlan show interfaces all` for the connected AP.
- The visible AP list from `netsh wlan show networks mode=bssid` provides signal percentage, not real RSSI per visible BSSID.

## Troubleshooting

For common startup and runtime issues, see:

[TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## Version history

For release history and version changes, see:

[CHANGELOG.md](CHANGELOG.md)

## Roadmap

For planned and future ideas, see:

[ROADMAP.md](ROADMAP.md)

## Privacy note

The Windows WLAN HTML report can contain computer names, usernames, domain details, saved Wi-Fi profiles, certificate information, IP configuration, and other environment details.

Review or sanitize diagnostic files before sharing them externally.
