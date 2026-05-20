function Read-WiFiRoamWatcherConfig {
    param(
        [string]$Path,
        [string]$ScriptFolder
    )

    if (-not (Test-Path $Path)) {
        @(
            "# Wi-Fi Roam Watcher configuration",
            "# Leave paths empty to use the same folder as Start-WiFiRoamWatcher.ps1.",
            "# No alias file is used by default. Add CSV names to ap_alias_list to enable aliases.",
            "ap_alias_list_path=",
            "ap_alias_list=",
            "log_path=",
            "log_filename=wifi_roam_watcher.log",
            "log_rotation=true",
            "log_retention=1d"
        ) | Set-Content -Path $Path -Encoding UTF8
    }

    $defaults = @{
        ap_alias_list_path = ""
        ap_alias_list      = ""
        log_path           = ""
        log_filename       = "wifi_roam_watcher.log"
        log_rotation       = "true"
        log_retention      = "1d"
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
        log_rotation       = $settings["log_rotation"]
        log_retention      = $settings["log_retention"]
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
