function Read-WiFiRoamWatcherConfig {
    param(
        [string]$Path,
        [string]$ScriptFolder
    )

    if (-not (Test-Path $Path)) {
        @(
            "# ==============================================================================",
            "# Wi-Fi Roam Watcher v1.1 Configuration",
            "# ==============================================================================",
            "#",
            "# Notes:",
            "# - Lines starting with # are comments.",
            "# - Use key=value format.",
            "# - Do not wrap values in quotes.",
            "# - Leave folder/path values blank to use the same folder as Start-WiFiRoamWatcher.ps1.",
            "# - Relative paths are resolved from the script folder.",
            "#",
            "",
            "# ------------------------------------------------------------------------------",
            "# AP ALIASES",
            "# ------------------------------------------------------------------------------",
            "# Optional friendly names for AP/BSSID values.",
            "#",
            "# CSV format:",
            "#   Match,Alias",
            "#   00:a7:42:f5:5e:2f,Example-AP-Name",
            "#",
            "# ap_alias_list_path:",
            "#   Folder containing the alias CSV files.",
            "#   Blank = script folder.",
            "#",
            "# ap_alias_list:",
            "#   Comma-separated list of alias CSV files.",
            "#   Blank = disable aliases.",
            "#",
            "# Examples:",
            "#   ap_alias_list=ap_aliases.csv",
            "#   ap_alias_list=mst_exchange_aps.csv,ap_aliases.csv",
            "#",
            "ap_alias_list_path=",
            "ap_alias_list=mst_exchange_aps.csv,ap_aliases.csv",
            "",
            "# ------------------------------------------------------------------------------",
            "# LOGGING",
            "# ------------------------------------------------------------------------------",
            "# log_path:",
            "#   Folder where the active log file and rotated logs are stored.",
            "#   Blank = script folder.",
            "#",
            "# log_filename:",
            "#   Active log filename.",
            "#",
            "# log_rotation:",
            "#   true  = rotate the log when a new day starts.",
            "#   false = keep writing to the same log file.",
            "#",
            "# log_retention:",
            "#   How long to keep rotated log files.",
            "#   Supported units: d = days, w = weeks, m = months.",
            "#   Examples: 1d, 7d, 2w, 1m",
            "#",
            "log_path=",
            "log_filename=wifi_roam_watcher.log",
            "log_rotation=true",
            "log_retention=1d",
            "",
            "# ------------------------------------------------------------------------------",
            "# DIAGNOSTIC CAPTURE",
            "# ------------------------------------------------------------------------------",
            "# diagnostics_enabled:",
            "#   true  = allow diagnostic bundles to be created.",
            "#   false = disable diagnostic bundles.",
            "#",
            "# diagnostics_path:",
            "#   Folder where diagnostic bundles are saved.",
            "#   Relative paths are based on the script folder.",
            "#",
            "# zero_bssid_diagnostics:",
            "#   true  = capture evidence if Windows reports the connected BSSID as",
            "#           00:00:00:00:00:00.",
            "#   false = suppress the zero-BSSID event but do not create a diagnostic bundle.",
            "#",
            "# zero_bssid_diagnostic_cooldown_seconds:",
            "#   Minimum time between repeated zero-BSSID diagnostic captures.",
            "#",
            "# wlanreport_duration_days:",
            "#   Used by: netsh wlan show wlanreport duration=N",
            "#",
            "# wlanreport_wait_seconds:",
            "#   How long to wait for wlan-report-latest.html to be generated before copying it.",
            "#",
            "# Important:",
            "# - Windows requires Administrator rights for netsh wlan show wlanreport.",
            "# - Without Administrator rights, the script still captures interfaces.txt,",
            "#   networks-bssid.txt, and drivers.txt, then skips the WLAN HTML report cleanly.",
            "#",
            "diagnostics_enabled=true",
            "diagnostics_path=diagnostics",
            "zero_bssid_diagnostics=true",
            "zero_bssid_diagnostic_cooldown_seconds=300",
            "wlanreport_duration_days=3",
            "wlanreport_wait_seconds=90",
            "",
            "# ------------------------------------------------------------------------------",
            "# AP COUNT CHANGE DEBOUNCE",
            "# ------------------------------------------------------------------------------",
            "# Windows can sometimes return partial scan results from:",
            "#   netsh wlan show networks mode=bssid",
            "#",
            "# ap_count_debounce_samples:",
            "#   Number of repeated samples required before logging an AP count change.",
            "#   Higher value = less noisy AP_COUNT logs.",
            "#",
            "ap_count_debounce_samples=3"
        ) | Set-Content -Path $Path -Encoding UTF8
    }

    $defaults = @{
        ap_alias_list_path = ""
        ap_alias_list      = ""
        log_path           = ""
        log_filename       = "wifi_roam_watcher.log"
        log_rotation                             = "true"
        log_retention                            = "1d"
        diagnostics_enabled                      = "true"
        diagnostics_path                         = "diagnostics"
        zero_bssid_diagnostics                  = "true"
        zero_bssid_diagnostic_cooldown_seconds  = "300"
        wlanreport_duration_days                = "3"
        wlanreport_wait_seconds                 = "90"
        ap_count_debounce_samples               = "3"
    }

    $settings = @{}
    foreach ($key in $defaults.Keys) {
        $settings[$key] = $defaults[$key]
    }

    try {
        foreach ($line in Get-Content -Path $Path) {
            $trimmed = ([string]$line).Trim()

            if ([string]::IsNullOrWhiteSpace($trimmed)) {
                continue
            }

            if ($trimmed.StartsWith("#")) {
                continue
            }

            if ($trimmed -notmatch "=") {
                continue
            }

            $parts = $trimmed -split "=", 2
            $key = $parts[0].Trim().ToLower()
            $value = ""

            if ($parts.Count -gt 1) {
                $value = $parts[1].Trim()
            }

            if ($settings.ContainsKey($key)) {
                $settings[$key] = $value
            }
        }
    }
    catch {
        # If config parsing fails, keep defaults.
    }

    return [PSCustomObject]@{
        ap_alias_list_path = $settings["ap_alias_list_path"]
        ap_alias_list      = $settings["ap_alias_list"]
        log_path           = $settings["log_path"]
        log_filename       = $settings["log_filename"]
        log_rotation                            = $settings["log_rotation"]
        log_retention                           = $settings["log_retention"]
        diagnostics_enabled                     = $settings["diagnostics_enabled"]
        diagnostics_path                        = $settings["diagnostics_path"]
        zero_bssid_diagnostics                 = $settings["zero_bssid_diagnostics"]
        zero_bssid_diagnostic_cooldown_seconds = $settings["zero_bssid_diagnostic_cooldown_seconds"]
        wlanreport_duration_days               = $settings["wlanreport_duration_days"]
        wlanreport_wait_seconds                = $settings["wlanreport_wait_seconds"]
        ap_count_debounce_samples              = $settings["ap_count_debounce_samples"]
    }
}

function Resolve-WiFiRoamWatcherPath {
    param(
        [string]$ConfiguredPath,
        [string]$DefaultPath
    )

    if ([string]::IsNullOrWhiteSpace($ConfiguredPath)) {
        return $DefaultPath
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($ConfiguredPath.Trim())

    if ([System.IO.Path]::IsPathRooted($expanded)) {
        return $expanded
    }

    return (Join-Path $DefaultPath $expanded)
}

function Get-ConfigBoolean {
    param(
        [string]$Value,
        [bool]$DefaultValue = $false
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $DefaultValue
    }

    switch ($Value.Trim().ToLower()) {
        "true"  { return $true }
        "yes"   { return $true }
        "1"     { return $true }
        "on"    { return $true }
        "false" { return $false }
        "no"    { return $false }
        "0"     { return $false }
        "off"   { return $false }
        default  { return $DefaultValue }
    }
}

function Get-ConfigInteger {
    param(
        [string]$Value,
        [int]$DefaultValue,
        [int]$MinimumValue = 0,
        [int]$MaximumValue = 2147483647
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $DefaultValue
    }

    $parsed = 0

    if (-not [int]::TryParse($Value.Trim(), [ref]$parsed)) {
        return $DefaultValue
    }

    if ($parsed -lt $MinimumValue) {
        return $MinimumValue
    }

    if ($parsed -gt $MaximumValue) {
        return $MaximumValue
    }

    return $parsed
}

function Get-RetentionCutoff {
    param(
        [string]$RetentionSpec
    )

    if ([string]::IsNullOrWhiteSpace($RetentionSpec)) {
        return $null
    }

    $spec = $RetentionSpec.Trim().ToLower()

    if ($spec -notmatch '^(?<num>\d+)(?<unit>d|w|m)$') {
        return $null
    }

    $number = [int]$Matches['num']
    $unit = $Matches['unit']
    $now = Get-Date

    switch ($unit) {
        "d" { return $now.AddDays(-$number) }
        "w" { return $now.AddDays(-7 * $number) }
        "m" { return $now.AddMonths(-$number) }
    }

    return $null
}

function Invoke-WiFiRoamWatcherLogMaintenance {
    param(
        [string]$LogFile,
        [bool]$RotationEnabled,
        [string]$RetentionSpec
    )

    $logFolder = Split-Path -Path $LogFile -Parent
    $fileName = Split-Path -Path $LogFile -Leaf
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    $extension = [System.IO.Path]::GetExtension($fileName)

    if ([string]::IsNullOrWhiteSpace($extension)) {
        $extension = ".log"
    }

    if (-not (Test-Path $logFolder)) {
        New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
    }

    if ($RotationEnabled -and (Test-Path $LogFile)) {
        $logItem = Get-Item -Path $LogFile

        if ($logItem.LastWriteTime.Date -lt (Get-Date).Date) {
            $datePart = $logItem.LastWriteTime.ToString("yyyyMMdd")
            $archiveName = "{0}_{1}{2}" -f $baseName, $datePart, $extension
            $archivePath = Join-Path $logFolder $archiveName

            if (Test-Path $archivePath) {
                $timePart = Get-Date -Format "HHmmss"
                $archiveName = "{0}_{1}_{2}{3}" -f $baseName, $datePart, $timePart, $extension
                $archivePath = Join-Path $logFolder $archiveName
            }

            Add-Content -Path $LogFile -Value "[$(Get-LogTimestamp)] LOG_ROTATE: Closing old log file. Archive file: $archivePath"
            Move-Item -Path $LogFile -Destination $archivePath -Force
            Add-Content -Path $LogFile -Value "[$(Get-LogTimestamp)] LOG_ROTATE: New log file created. Previous log file: $archivePath"
        }
    }

    $cutoff = Get-RetentionCutoff -RetentionSpec $RetentionSpec
    if ($null -eq $cutoff) {
        return
    }

    $archivePattern = "{0}_*{1}" -f $baseName, $extension
    $oldLogs = Get-ChildItem -Path $logFolder -Filter $archivePattern -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff }

    foreach ($oldLog in $oldLogs) {
        try {
            $oldPath = $oldLog.FullName
            Remove-Item -Path $oldPath -Force
            Add-Content -Path $LogFile -Value "[$(Get-LogTimestamp)] LOG_RETENTION: Deleted old rotated log file: $oldPath"
        }
        catch {
            Add-Content -Path $LogFile -Value "[$(Get-LogTimestamp)] LOG_RETENTION_ERROR: Failed to delete old rotated log file: $($oldLog.FullName) | $($_.Exception.Message)"
        }
    }
}
