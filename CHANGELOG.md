# Changelog

All notable changes to Wi-Fi Roam Watcher are documented in this file.

## v1.2

### Added

- Added `refresh_interval_seconds` so the monitor loop refresh interval can be configured.
- Added logging when `refresh_interval_seconds` is changed while the script is running.
- Added Dependabot configuration for GitHub Actions updates.

### Improved

- Improved roaming event logging with clearer before/after AP, signal, RSSI, channel, and visible AP count context.
- Improved signal-change logging with signal and RSSI deltas.
- Improved AP count change logging with connected AP context.
- Improved disconnect and reconnect logging with last-known AP details.
- Improved alias update logging with `CONNECTED` and `VISIBLE` status.
- Refreshed connected AP alias display after live alias updates.
- Avoided logging the full local config file path at startup.
- Updated README and ROADMAP content for the current v1.2 direction.

### Notes

- Continues to use the current Windows PowerShell and `netsh wlan` workflow.

## v1.1

### Added

- Added zero-BSSID handling for cases where Windows reports the connected AP/BSSID as `00:00:00:00:00:00`.
- Added automatic diagnostic bundle creation when zero-BSSID is detected.
- Added `modules\WiFiRoamWatcher.Diagnostics.ps1`.
- Added Administrator-aware WLAN report capture.
- Added `wlanreport_wait_seconds` so the script waits for `wlan-report-latest.html` to finish before copying it.
- Added AP count debounce to reduce noisy AP count changes from partial Windows scan results.

### Improved

- Improved diagnostic handling.
- Improved configuration comments and examples.
- Improved startup and runtime guidance.
- Improved troubleshooting documentation.
- Kept AP alias support from v1.0, including alias display, alias logging, and live alias-file reload.

### Notes

- Normal monitoring can run without Administrator rights.
- Full WLAN HTML report collection requires PowerShell to be opened as Administrator.

## v1.0

### Added

- Initial public release of Wi-Fi Roam Watcher.
- Added Windows client-side Wi-Fi roaming monitoring.
- Added startup menu with monitoring modes:
  - Auto - monitor any SSID the laptop is connected to.
  - Use current connected SSID.
  - Enter SSID manually.
- Added connected SSID and AP/BSSID monitoring.
- Added signal percentage and connected RSSI logging.
- Added channel, band, radio type, RX rate, and TX rate visibility.
- Added roaming event detection.
- Added disconnect and reconnect event detection.
- Added visible AP count tracking.
- Added optional AP alias support.
- Added log file output.
- Added basic configuration through `config.cfg`.

### Notes

- Initial release focused on a lightweight PowerShell workflow using built-in Windows commands.
