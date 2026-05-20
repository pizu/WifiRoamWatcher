# Wi-Fi Roam Watcher v1.0

Wi-Fi Roam Watcher is a Windows PowerShell tool for watching Wi-Fi roaming behaviour from a client laptop. It uses Windows `netsh wlan` commands to show the currently connected AP/BSSID, signal, connected RSSI, channel, radio type, RX/TX rate, visible AP count, disconnect/reconnect events, roaming events, and optional AP aliases.

## How to run

Open PowerShell in the extracted folder and run:

```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\Start-WiFiRoamWatcher.ps1
```

For PowerShell 7:

```powershell
pwsh.exe -ExecutionPolicy Bypass -NoProfile -File .\Start-WiFiRoamWatcher.ps1
```

Press `CTRL+C` to stop.

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
├── README.txt
├── VERSION.txt
│
└── modules\
    ├── WiFiRoamWatcher.Common.ps1
    ├── WiFiRoamWatcher.Config.ps1
    ├── WiFiRoamWatcher.Aliases.ps1
    ├── WiFiRoamWatcher.Netsh.ps1
    └── WiFiRoamWatcher.Display.ps1
```

## config.cfg

Default config:

```ini
ap_alias_list_path=
ap_alias_list=
log_path=
log_filename=wifi_roam_watcher.log
log_rotation=true
log_retention=1d
```

`ap_alias_list_path=` is the folder containing alias CSV files. If empty, the script folder is used.

`ap_alias_list=` is a comma-separated list of alias CSV files. There is no default alias file. If this is empty, no aliases are loaded.

Example:

```ini
ap_alias_list_path=C:\WiFiAliases
ap_alias_list=floor1.csv,floor2.csv
```

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

## Alias CSV files

Alias files are optional and must be listed in `config.cfg`.

CSV format:

```csv
Match,Alias
00:a7:42:f5:5e:2f,Office-AP
f0:7f:06:cd:30:4f,MeetingRoom-AP
cd:30,Partial-Match-Example
```

Full BSSID matches are recommended. Partial matches work, but they can match more than one AP if the text is not unique.

Alias files are reloaded while the script runs. If a visible AP gets a new alias, changes alias, or loses its alias, the script logs an `ALIAS_UPDATE` event.

## Log rotation

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
LOG_ROTATE    Log file was rotated.
LOG_RETENTION Old rotated log file was deleted.
ERROR         Script caught an error but continued running.
```

## Netsh commands used

Wi-Fi Roam Watcher uses these Windows commands:

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

This scans visible SSIDs and BSSIDs/APs. The script uses it to list visible APs for the monitored SSID and to get BSSID, signal percentage, band, channel, and radio type where available.

Important: real RSSI is only taken from `netsh wlan show interfaces all` for the connected AP. The visible AP list from `netsh wlan show networks mode=bssid` provides signal percentage, not real RSSI per BSSID.

## Quick user steps

1. Extract the folder.
2. Run `Start-WiFiRoamWatcher.ps1` using the command above.
3. Select option 1, 2, or 3.
4. Optionally configure aliases and logging in `config.cfg`.
5. Check `wifi_roam_watcher.log` for events.
6. Press `CTRL+C` to stop.
