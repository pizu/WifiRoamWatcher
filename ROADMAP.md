# Wi-Fi Roam Watcher Roadmap

This roadmap lists the general direction and ideas being considered for future versions of Wi-Fi Roam Watcher.

Items listed here are not guaranteed unless they are linked to an issue, milestone, pull request, or release.

## v1.x Direction

The v1.x series focuses on improving the current Windows PowerShell and `netsh wlan` based implementation.

The goal is to keep v1.x simple, portable, easy to run, and useful for Wi-Fi roaming troubleshooting on Windows laptops.

### Completed in v1.2

- Improved Wi-Fi roaming visibility.
- Improved RSSI visibility and logging.
- Improved AP count change logging.
- Improved logging format and readability.
- Improved alias update readability.
- Improved README and configuration examples.
- Added manual GitHub Actions workflow trigger for validation.

### Planned / Under Consideration for v1.x

- Improve startup messages and usability.
- Improve configuration examples.
- Improve README and troubleshooting documentation.
- Keep the current lightweight PowerShell workflow.

### Not Planned for v1.x

The following items are not planned for the v1.x series:

- Major architectural changes.
- Vendor-specific driver integration.
- New advanced wireless diagnostic engine.
- New diagnostic bundle redesign.

## v2.x Ideas

The v2.x series may introduce deeper Windows wireless integration and larger internal changes.

### Under Consideration for v2.x

- Deeper Windows wireless integration.
- Improved structured Wi-Fi data collection.
- New advanced diagnostic output.
- Improved wireless troubleshooting data.
- Improved reporting beyond the current `netsh wlan` workflow.
- Possible architectural changes to support future features.

## Future / Backlog

These ideas may be considered later, but are not currently assigned to a specific version.

- Additional troubleshooting views.
- Improved report exports.
- Better summary output.
- More flexible configuration options.
- Additional documentation and examples.

## Notes

Wi-Fi Roam Watcher v1.x is focused on the current PowerShell and `netsh wlan` workflow.

Future versions may explore deeper Windows wireless integration and improved structured Wi-Fi data collection.
