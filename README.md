# Wi-Fi Roam Watcher v1.0

Wi-Fi Roam Watcher is a Windows PowerShell tool for watching Wi-Fi roaming behaviour from a client laptop.

It uses native Windows `netsh wlan` commands to show the currently connected SSID, AP/BSSID, signal, connected RSSI, channel, radio type, RX/TX rate, visible AP count, disconnect/reconnect events, roaming events, and optional AP aliases.

---

## Features

- Monitor Wi-Fi roaming from a Windows client device.
- Startup menu with three monitoring modes:
  - Auto - monitor any SSID the laptop is connected to
  - Use current connected SSID
  - Enter SSID manually
- Detect and log AP/BSSID roaming events.
- Detect and log disconnect/reconnect events.
- Show real RSSI for the connected AP.
- Show visible AP/BSSID list for the monitored SSID.
- Track visible AP count changes.
- Optional AP alias support using one or more CSV files.
- Live alias reload with alias update logging.
- Configurable settings using `config.cfg`.
- Configurable log path and log filename.
- Daily log rotation support.
- Log retention support using values such as `1d`, `2d`, `1w`, and `1m`.
- Windows-only compatibility checks.
- Version is read from `VERSION.txt`.

---

## Requirements

This tool is Windows-only.

Recommended:

- Windows PowerShell 5.1
- PowerShell 7.x on Windows

Required:

- Windows OS
- Wi-Fi adapter
- `netsh.exe`
- PowerShell 3.0 or newer

No external PowerShell modules are required.

---

## How to Run

Open PowerShell in the script folder and run:

```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\Start-WiFiRoamWatcher.ps1
```

For PowerShell 7:

```powershell
pwsh.exe -ExecutionPolicy Bypass -NoProfile -File .\Start-WiFiRoamWatcher.ps1
```

Press `CTRL+C` to stop the monitor.

---

## Startup Options

When the script starts, choose one of these options:

```text
1. Auto - monitor any SSID I am connected to
2. Use current connected SSID
3. Enter SSID manually
Q. Quit
```

### Option 1 - Auto

Auto mode monitors whatever SSID the laptop is currently connected to.

If the laptop disconnects and later connects to another SSID, the monitor follows the new connected SSID.

Use this when you want to monitor the laptop's Wi-Fi connection in general.

### Option 2 - Use current connected SSID

This locks the monitor to the SSID that the laptop is connected to at startup.

Use this when troubleshooting one specific SSID.

### Option 3 - Enter SSID manually

This allows you to type the SSID name manually.

Use this when you want to monitor an SSID that is visible but not currently connected.

---

## Folder Layout

```text
Wi-Fi Roam Watcher\
│
├── Start-WiFiRoamWatcher.ps1
├── config.cfg
├── README.md
├── VERSION.txt
│
└── modules\
    ├── WiFiRoamWatcher.Common.ps1
    ├── WiFiRoamWatcher.Config.ps1
    ├── WiFiRoamWatcher.Aliases.ps1
    ├── WiFiRoamWatcher.Netsh.ps1
    └── WiFiRoamWatcher.Display.ps1
```

---

## config.cfg

The script uses `config.cfg` for configurable options.

Default config:

```ini
ap_alias_list_path=
ap_alias_list=
log_path=
log_filename=wifi_roam_watcher.log
log_rotation=true
log_retention=1d
```

### Configuration Options

#### ap_alias_list_path

```ini
ap_alias_list_path=
```

Folder containing alias CSV files.

If empty, the script folder is used.

Example:

```ini
ap_alias_list_path=C:\WiFiAliases
```

#### ap_alias_list

```ini
ap_alias_list=
```

Comma-separated list of alias CSV files.

There is no default alias file. If this is empty, no aliases are loaded.

Example:

```ini
ap_alias_list=floor1.csv,floor2.csv
```

#### log_path

```ini
log_path=
```

Folder where logs are stored.

If empty, the script folder is used.

Example:

```ini
log_path=C:\Logs\WiFiRoamWatcher
```

#### log_filename

```ini
log_filename=wifi_roam_watcher.log
```

Name of the active log file.

#### log_rotation

```ini
log_rotation=true
```

Enables or disables daily log rotation.

Valid values:

```text
true
false
```

#### log_retention

```ini
log_retention=1d
```

Controls how long rotated logs are kept.

Examples:

```ini
log_retention=1d
log_retention=2d
log_retention=1w
log_retention=1m
```

Meaning:

```text
1d = 1 day
2d = 2 days
1w = 1 week
1m = 1 month
```

---

## Alias CSV Files

Alias files are optional and must be listed in `config.cfg`.

CSV format:

```csv
Match,Alias
00:a7:42:f5:5e:2f,Office-AP
f0:7f:06:cd:30:4f,MeetingRoom-AP
cd:30,Partial-Match-Example
```

Full BSSID matches are recommended.

Partial matches work, but they can match more than one AP if the text is not unique.

Alias files are reloaded while the script runs. If a visible AP gets a new alias, changes alias, or loses its alias, the script logs an `ALIAS_UPDATE` event.

---

## Log Rotation

When rotation is enabled, the active log is renamed when it belongs to a previous day.

Example:

```text
wifi_roam_watcher.log
```

becomes:

```text
wifi_roam_watcher_20260520.log
```

If that file already exists, a time suffix is added:

```text
wifi_roam_watcher_20260520_091500.log
```

The script writes a rotation message into the old log before renaming it and into the new log after rotation.

---

## Log Event Types

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
LOG_ROTATE    Log file was rotated.
LOG_RETENTION Old rotated log file was deleted.
ERROR         Script caught an error but continued running.
```

Example log entries:

```text
[2026-05-20 09:20:01] STARTUP: Wi-Fi Roam Watcher v1.0 | Monitoring SSID [GOCorp]
[2026-05-20 09:20:05] START: Current connection 00:a7:42:f5:5e:2f [Office-AP] | Signal: 92% | RSSI: -42 dBm | Chan: 100 | APs seen: 2
[2026-05-20 09:25:44] ROAMED: From 00:a7:42:f5:5e:2f [Office-AP] | Signal: 92% | RSSI: -42 dBm | Chan: 100 -> To f0:7f:06:cd:30:4f [MeetingRoom-AP] | Signal: 96% | RSSI: -36 dBm | Chan: 132 | APs seen: 2
[2026-05-20 09:35:10] DISCONNECTED: Lost connection to monitored SSID | Previous SSID: GOCorp | Previous AP: f0:7f:06:cd:30:4f [MeetingRoom-AP] | Last Signal: 88% | Last RSSI: -43 dBm | Last Chan: 132
[2026-05-20 09:35:20] RECONNECTED: Connected to monitored SSID GOCorp | AP: 00:a7:42:f5:5e:2f [Office-AP] | Signal: 92% | RSSI: -42 dBm | Chan: 100 | Previous AP: f0:7f:06:cd:30:4f [MeetingRoom-AP] | APs seen: 2
```

---

## Netsh Commands Used

Wi-Fi Roam Watcher uses two Windows `netsh wlan` commands.

### Current Wi-Fi Connection

```powershell
netsh wlan show interfaces all
```

This reads the current Wi-Fi connection and provides:

- Current connection state
- Connected SSID
- Connected BSSID/AP MAC
- Signal percentage
- Real connected RSSI
- Band
- Channel
- Radio type
- Receive rate
- Transmit rate

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

### Visible Wi-Fi Networks and BSSIDs

```powershell
netsh wlan show networks mode=bssid
```

This scans visible SSIDs and BSSIDs/APs.

The script uses it to list visible APs for the monitored SSID and to get:

- BSSID/AP MAC address
- Signal percentage
- Band
- Channel
- Radio type where available

Example fields used:

```text
SSID 1 : MySSID
    BSSID 1                 : 00:a7:42:f5:5e:2f
         Signal             : 92%
         Radio type         : 802.11ac
         Band               : 5 GHz
         Channel            : 100
```

Important: real RSSI is only taken from `netsh wlan show interfaces all` for the connected AP.

The visible AP list from `netsh wlan show networks mode=bssid` provides signal percentage, not real RSSI per BSSID.

This avoids displaying estimated or fake RSSI values for scanned APs.

---

## Quick User Steps

1. Extract the folder.
2. Open PowerShell in the extracted folder.
3. Run:

```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\Start-WiFiRoamWatcher.ps1
```

4. Select option `1`, `2`, or `3`.
5. Optionally configure aliases and logging in `config.cfg`.
6. Press `CTRL+C` to stop.

---

## Troubleshooting

### Script does not start because of execution policy

Run it with:

```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\Start-WiFiRoamWatcher.ps1
```

### Missing module error

Make sure the `modules` folder exists and contains:

```text
WiFiRoamWatcher.Common.ps1
WiFiRoamWatcher.Config.ps1
WiFiRoamWatcher.Aliases.ps1
WiFiRoamWatcher.Netsh.ps1
WiFiRoamWatcher.Display.ps1
```

### No SSID detected

Check the Wi-Fi connection manually:

```powershell
netsh wlan show interfaces all
```

### No BSSID entries found

Check if the SSID is visible:

```powershell
netsh wlan show networks mode=bssid
```

Make sure the SSID name is typed exactly as shown by Windows.

### RSSI shows Unknown

The Wi-Fi driver or Windows version may not expose the `Rssi` field.

The script will still show signal percentage.

### Aliases not showing

Check:

1. `config.cfg` has `ap_alias_list=` configured.
2. The alias CSV file exists.
3. The CSV has the correct header:

```csv
Match,Alias
```

4. The BSSID or partial BSSID matches what appears in the script output.

---

## Notes

- This tool is Windows-only.
- It uses native Windows `netsh wlan` commands.
- It does not require any external PowerShell modules.
- RSSI is intentionally shown only for the connected AP.
- Visible APs show signal percentage, not RSSI.
