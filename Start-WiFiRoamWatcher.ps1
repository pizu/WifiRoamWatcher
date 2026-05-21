# ------------------------------------------------------------
# Wi-Fi Roam Watcher - Main startup script
# ------------------------------------------------------------

# ------------------------------------------------------------
# Windows-only compatibility check
# ------------------------------------------------------------
if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    Write-Host "This script only works on Windows." -ForegroundColor Red
    Write-Host "Reason: it uses Windows netsh wlan commands." -ForegroundColor Yellow
    exit
}

if ($PSVersionTable.PSVersion.Major -lt 3) {
    Write-Host "This script requires PowerShell 3.0 or newer." -ForegroundColor Red
    Write-Host "Recommended: Windows PowerShell 5.1 or PowerShell 7.x on Windows." -ForegroundColor Yellow
    exit
}

if (-not (Get-Command netsh.exe -ErrorAction SilentlyContinue)) {
    Write-Host "netsh.exe was not found." -ForegroundColor Red
    Write-Host "This script requires Windows netsh wlan support." -ForegroundColor Yellow
    exit
}

# ------------------------------------------------------------
# Base paths
# ------------------------------------------------------------
$scriptFolder = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$moduleFolder = Join-Path $scriptFolder "modules"
$configFile = Join-Path $scriptFolder "config.cfg"
$versionFile = Join-Path $scriptFolder "VERSION.txt"

# ------------------------------------------------------------
# Script version
# ------------------------------------------------------------
# VERSION.txt is the single source of truth for the package version.
# If the file is missing or empty, the script continues using "unknown".
$scriptVersion = "unknown"

if (Test-Path $versionFile) {
    try {
        $versionText = (Get-Content -Path $versionFile -TotalCount 1 -ErrorAction Stop).Trim()

        if (-not [string]::IsNullOrWhiteSpace($versionText)) {
            $scriptVersion = $versionText
        }
    }
    catch {
        $scriptVersion = "unknown"
    }
}

# ------------------------------------------------------------
# Load module files
# ------------------------------------------------------------
$requiredModuleFiles = @(
    "WiFiRoamWatcher.Common.ps1",
    "WiFiRoamWatcher.Config.ps1",
    "WiFiRoamWatcher.Diagnostics.ps1",
    "WiFiRoamWatcher.Aliases.ps1",
    "WiFiRoamWatcher.Netsh.ps1",
    "WiFiRoamWatcher.Display.ps1"
)

foreach ($moduleName in $requiredModuleFiles) {
    $modulePath = Join-Path $moduleFolder $moduleName

    if (-not (Test-Path $modulePath)) {
        Write-Host "Missing module file: $modulePath" -ForegroundColor Red
        Write-Host "Please make sure the modules folder contains all required .ps1 files." -ForegroundColor Yellow
        exit
    }

    . $modulePath
}

# ------------------------------------------------------------
# Confirm required functions loaded correctly
# ------------------------------------------------------------
$requiredFunctions = @(
    "Normalize-Bssid",
    "Test-ValidWifiBssid",
    "Format-Rssi",
    "Get-LogTimestamp",
    "Write-WiFiRoamWatcherLog",
    "Select-WiFiRoamWatcherTargetSsid",
    "Read-WiFiRoamWatcherConfig",
    "Resolve-WiFiRoamWatcherPath",
    "Get-ConfigBoolean",
    "Get-ConfigInteger",
    "Invoke-WiFiRoamWatcherLogMaintenance",
    "Invoke-WiFiRoamWatcherDiagnosticCapture",
    "Get-AliasFilesFromConfig",
    "Load-ApAliases",
    "Get-ApAlias",
    "Get-CurrentWifiInterface",
    "Get-VisibleWifiBssids",
    "Show-WiFiRoamWatcherScreen"
)

foreach ($functionName in $requiredFunctions) {
    if (-not (Get-Command $functionName -CommandType Function -ErrorAction SilentlyContinue)) {
        Write-Host "Required function was not loaded: $functionName" -ForegroundColor Red
        Write-Host "Check that all files in the modules folder were copied correctly." -ForegroundColor Yellow
        exit
    }
}

# ------------------------------------------------------------
# Load config
# ------------------------------------------------------------
$config = Read-WiFiRoamWatcherConfig -Path $configFile -ScriptFolder $scriptFolder

$logFolder = Resolve-WiFiRoamWatcherPath -ConfiguredPath $config.log_path -DefaultPath $scriptFolder
$aliasFolder = Resolve-WiFiRoamWatcherPath -ConfiguredPath $config.ap_alias_list_path -DefaultPath $scriptFolder

if (-not (Test-Path $logFolder)) {
    New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
}

$logFileName = $config.log_filename
if ([string]::IsNullOrWhiteSpace($logFileName)) {
    $logFileName = "wifi_roam_watcher.log"
}

$logFile = Join-Path $logFolder $logFileName
$logRotationEnabled = Get-ConfigBoolean -Value $config.log_rotation -DefaultValue $true

Invoke-WiFiRoamWatcherLogMaintenance `
    -LogFile $logFile `
    -RotationEnabled $logRotationEnabled `
    -RetentionSpec $config.log_retention

$aliasFiles = Get-AliasFilesFromConfig `
    -AliasListPath $aliasFolder `
    -AliasList $config.ap_alias_list

# ------------------------------------------------------------
# Last known connected AP details
# ------------------------------------------------------------
$global:lastBssid = "NONE"
$global:lastAlias = "UNKNOWN"
$global:lastSignal = $null
$global:lastRssi = $null
$global:lastChannel = "UNKNOWN"

# ------------------------------------------------------------
# Last known visible AP count
# ------------------------------------------------------------
$global:lastApCount = -1
$global:pendingApCount = $null
$global:pendingApCountSeen = 0

# ------------------------------------------------------------
# Last known connection state
# ------------------------------------------------------------
$global:lastConnectionState = "UNKNOWN"
$global:lastConnectedSsid = "UNKNOWN"

# ------------------------------------------------------------
# Last known invalid-BSSID diagnostic state
# ------------------------------------------------------------
$global:lastInvalidBssidDiagnosticTime = $null
$global:invalidBssidWarningActive = $false

# ------------------------------------------------------------
# Last known alias state per BSSID
# ------------------------------------------------------------
# Alias files can be edited while the script runs.
# The first scan creates a baseline; later changes are logged.
$global:lastAliasByBssid = @{}
$global:aliasBaselineReady = $false

# ------------------------------------------------------------
# Startup menu
# ------------------------------------------------------------
$currentAtStartup = Get-CurrentWifiInterface
$selection = Select-WiFiRoamWatcherTargetSsid -CurrentSsid $currentAtStartup.SSID -Version $scriptVersion

if ($null -eq $selection -or [string]::IsNullOrWhiteSpace($selection.Mode)) {
    Write-Host "No SSID selected. Exiting." -ForegroundColor Red
    exit
}

$monitorMode = $selection.Mode
$target = $selection.TargetSsid

if ($monitorMode -ne "Auto" -and [string]::IsNullOrWhiteSpace($target)) {
    Write-Host "No SSID selected. Exiting." -ForegroundColor Red
    exit
}

Write-WiFiRoamWatcherLog -Path $logFile -Message "[$(Get-LogTimestamp)] STARTUP: Wi-Fi Roam Watcher v$scriptVersion | Mode: $monitorMode | Monitoring SSID [$target] | Config: $configFile"

# ------------------------------------------------------------
# Main monitor loop
# ------------------------------------------------------------
while ($true) {
    try {
        # Reload config every loop so log, alias, and diagnostic settings can be changed while running.
        $config = Read-WiFiRoamWatcherConfig -Path $configFile -ScriptFolder $scriptFolder

        $newLogFolder = Resolve-WiFiRoamWatcherPath -ConfiguredPath $config.log_path -DefaultPath $scriptFolder
        $newLogFileName = $config.log_filename
        if ([string]::IsNullOrWhiteSpace($newLogFileName)) {
            $newLogFileName = "wifi_roam_watcher.log"
        }

        if (-not (Test-Path $newLogFolder)) {
            New-Item -Path $newLogFolder -ItemType Directory -Force | Out-Null
        }

        $newLogFile = Join-Path $newLogFolder $newLogFileName
        if ($newLogFile -ne $logFile) {
            Write-WiFiRoamWatcherLog -Path $logFile -Message "[$(Get-LogTimestamp)] LOG_CONFIG: Log file changed to $newLogFile"
            $logFile = $newLogFile
            Write-WiFiRoamWatcherLog -Path $logFile -Message "[$(Get-LogTimestamp)] LOG_CONFIG: New log file active for Wi-Fi Roam Watcher v$scriptVersion"
        }

        $logRotationEnabled = Get-ConfigBoolean -Value $config.log_rotation -DefaultValue $true
        Invoke-WiFiRoamWatcherLogMaintenance `
            -LogFile $logFile `
            -RotationEnabled $logRotationEnabled `
            -RetentionSpec $config.log_retention

        # Diagnostic and debounce settings are re-read every loop.
        $diagnosticsEnabled = Get-ConfigBoolean -Value $config.diagnostics_enabled -DefaultValue $true
        $zeroBssidDiagnosticsEnabled = Get-ConfigBoolean -Value $config.zero_bssid_diagnostics -DefaultValue $true
        $diagnosticRoot = Resolve-WiFiRoamWatcherPath -ConfiguredPath $config.diagnostics_path -DefaultPath $scriptFolder
        $zeroBssidDiagnosticCooldownSeconds = Get-ConfigInteger -Value $config.zero_bssid_diagnostic_cooldown_seconds -DefaultValue 300 -MinimumValue 30 -MaximumValue 86400
        $wlanReportDurationDays = Get-ConfigInteger -Value $config.wlanreport_duration_days -DefaultValue 3 -MinimumValue 1 -MaximumValue 30
        $wlanReportWaitSeconds = Get-ConfigInteger -Value $config.wlanreport_wait_seconds -DefaultValue 90 -MinimumValue 5 -MaximumValue 600
        $apCountDebounceSamples = Get-ConfigInteger -Value $config.ap_count_debounce_samples -DefaultValue 3 -MinimumValue 1 -MaximumValue 100

        # Alias settings are re-read every loop so CSV changes can be picked up without restarting.
        $aliasFolder = Resolve-WiFiRoamWatcherPath -ConfiguredPath $config.ap_alias_list_path -DefaultPath $scriptFolder
        $aliasFiles = Get-AliasFilesFromConfig `
            -AliasListPath $aliasFolder `
            -AliasList $config.ap_alias_list

        $apAliases = Load-ApAliases -Paths $aliasFiles

        # Read current connected Wi-Fi interface.
        $interfaceInfo = Get-CurrentWifiInterface

        # Auto mode follows whatever SSID the laptop is currently connected to.
        $currentState = ([string]$interfaceInfo.State).Trim()
        $currentSsid = ([string]$interfaceInfo.SSID).Trim()
        $currentBssid = ([string]$interfaceInfo.BSSID).Trim().ToLower()

        $currentLooksConnected = (
            $currentState -ieq "connected" -and
            -not [string]::IsNullOrWhiteSpace($currentSsid) -and
            $currentSsid -ne "UNKNOWN"
        )


        $currentHasValidBssid = Test-ValidWifiBssid -Bssid $currentBssid
        $currentIsConnected = ($currentLooksConnected -and $currentHasValidBssid)

        if ($monitorMode -eq "Auto") {
            if ($currentLooksConnected) {
                if ([string]::IsNullOrWhiteSpace($target) -or $target -eq "AUTO" -or $target -ne $currentSsid) {
                    $oldTarget = $target
                    $target = $currentSsid

                    if (-not [string]::IsNullOrWhiteSpace($oldTarget) -and $oldTarget -ne "AUTO") {
                        Write-WiFiRoamWatcherLog -Path $logFile -Message "[$(Get-LogTimestamp)] AUTO_SSID: Monitoring SSID changed from [$oldTarget] to [$target]"
                    }
                }
            }
            elseif ([string]::IsNullOrWhiteSpace($target)) {
                $target = "AUTO"
            }
        }

        $scanTarget = $target
        if ($monitorMode -eq "Auto" -and -not $currentIsConnected -and ($scanTarget -eq "AUTO" -or [string]::IsNullOrWhiteSpace($scanTarget))) {
            $allNodes = @()
        }
        else {
            # Read visible AP/BSSID list for the selected/current SSID.
            $allNodes = Get-VisibleWifiBssids `
                -TargetSsid $scanTarget `
                -ActiveBssid $interfaceInfo.BSSID `
                -ActiveSsid $interfaceInfo.SSID `
                -ActiveSignal $interfaceInfo.Signal `
                -ActiveChannel $interfaceInfo.Channel `
                -Aliases $apAliases
        }

        # Count visible APs.
        $apCount = @($allNodes).Count

        # Current timestamp for logs.
        $timestamp = Get-LogTimestamp

        # Detect the Windows/driver condition where the interface says it is connected,
        # but the connected BSSID is empty, invalid, or 00:00:00:00:00:00.
        $invalidBssidForMonitoredSsid = $false

        if ($currentLooksConnected -and (-not $currentHasValidBssid)) {
            if ($monitorMode -eq "Auto" -or $currentSsid -ieq $target) {
                $invalidBssidForMonitoredSsid = $true
            }
        }

        if ($invalidBssidForMonitoredSsid) {
            $now = Get-Date
            $shouldCaptureDiagnostic = $false

            if ($diagnosticsEnabled -and $zeroBssidDiagnosticsEnabled) {
                if ($null -eq $global:lastInvalidBssidDiagnosticTime) {
                    $shouldCaptureDiagnostic = $true
                }
                elseif (($now - $global:lastInvalidBssidDiagnosticTime).TotalSeconds -ge $zeroBssidDiagnosticCooldownSeconds) {
                    $shouldCaptureDiagnostic = $true
                }
            }

            if ($shouldCaptureDiagnostic) {
                Write-WiFiRoamWatcherLog -Path $logFile -Message "[$timestamp] DIAG: Invalid connected BSSID [$currentBssid] detected for SSID [$currentSsid]. Capturing Wi-Fi diagnostics..."

                try {
                    $diag = Invoke-WiFiRoamWatcherDiagnosticCapture `
                        -Reason "zero-bssid" `
                        -DiagnosticRoot $diagnosticRoot `
                        -WlanReportDurationDays $wlanReportDurationDays `
                        -WlanReportWaitSeconds $wlanReportWaitSeconds

                    Write-WiFiRoamWatcherLog -Path $logFile -Message "[$timestamp] DIAG: Wi-Fi diagnostics saved to: $($diag.CaptureDir)"

                    if ($diag.WlanReportStatus -eq "skipped-not-admin") {
                        Write-WiFiRoamWatcherLog -Path $logFile -Message "[$timestamp] DIAG: WLAN HTML report skipped because PowerShell is not running as Administrator."
                    }
                    elseif ($diag.WlanReportStatus -eq "copied") {
                        Write-WiFiRoamWatcherLog -Path $logFile -Message "[$timestamp] DIAG: WLAN HTML report copied to: $($diag.WlanReportPath)"
                    }
                    elseif ($diag.WlanReportStatus -eq "not-found") {
                        Write-WiFiRoamWatcherLog -Path $logFile -Message "[$timestamp] DIAG_WARN: WLAN HTML report was not found after waiting $wlanReportWaitSeconds seconds."
                    }
                }
                catch {
                    Write-WiFiRoamWatcherLog -Path $logFile -Message "[$timestamp] DIAG_ERROR: Failed to capture Wi-Fi diagnostics: $($_.Exception.Message)"
                }

                $global:lastInvalidBssidDiagnosticTime = $now
            }

            if (-not $global:invalidBssidWarningActive) {
                Write-WiFiRoamWatcherLog -Path $logFile -Message "[$timestamp] WARN: Connected SSID [$currentSsid] returned invalid BSSID [$currentBssid]. Treating BSSID as pending and suppressing START/ROAM/DISCONNECT logs until a valid BSSID is reported."
                $global:invalidBssidWarningActive = $true
            }
        }
        else {
            if ($global:invalidBssidWarningActive) {
                Write-WiFiRoamWatcherLog -Path $logFile -Message "[$timestamp] INFO: Connected BSSID is valid again: [$currentBssid] for SSID [$currentSsid]."
            }

            $global:invalidBssidWarningActive = $false
        }

        # Find connected AP from visible AP list.
        $connectedNode = $allNodes |
            Where-Object { $_.Status -eq "CONNECTED" } |
            Select-Object -First 1

        # ------------------------------------------------------------
        # Alias update detection
        # ------------------------------------------------------------
        foreach ($node in @($allNodes)) {
            if ($null -eq $node -or [string]::IsNullOrWhiteSpace([string]$node.BSSID)) {
                continue
            }

            $aliasBssid = ([string]$node.BSSID).ToLower()
            $newAlias = ""

            if ($node.Alias) {
                $newAlias = ([string]$node.Alias).Trim()
            }

            $oldAlias = ""
            $hasKnownAliasState = $global:lastAliasByBssid.ContainsKey($aliasBssid)

            if ($hasKnownAliasState) {
                $oldAlias = [string]$global:lastAliasByBssid[$aliasBssid]
            }

            if ($global:aliasBaselineReady -and $hasKnownAliasState) {
                if ([string]::IsNullOrWhiteSpace($oldAlias) -and -not [string]::IsNullOrWhiteSpace($newAlias)) {
                    Write-WiFiRoamWatcherLog -Path $logFile -Message "[$timestamp] ALIAS_UPDATE: BSSID $aliasBssid now has alias [$newAlias] | SSID: $($node.SSID) | Signal: $($node.Signal)% | Chan: $($node.Channel) | Status: $($node.Status)"
                }
                elseif (-not [string]::IsNullOrWhiteSpace($oldAlias) -and -not [string]::IsNullOrWhiteSpace($newAlias) -and $oldAlias -ne $newAlias) {
                    Write-WiFiRoamWatcherLog -Path $logFile -Message "[$timestamp] ALIAS_UPDATE: BSSID $aliasBssid alias changed from [$oldAlias] to [$newAlias] | SSID: $($node.SSID) | Signal: $($node.Signal)% | Chan: $($node.Channel) | Status: $($node.Status)"
                }
                elseif (-not [string]::IsNullOrWhiteSpace($oldAlias) -and [string]::IsNullOrWhiteSpace($newAlias)) {
                    Write-WiFiRoamWatcherLog -Path $logFile -Message "[$timestamp] ALIAS_UPDATE: BSSID $aliasBssid alias removed. Previous alias was [$oldAlias] | SSID: $($node.SSID) | Signal: $($node.Signal)% | Chan: $($node.Channel) | Status: $($node.Status)"
                }
            }

            $global:lastAliasByBssid[$aliasBssid] = $newAlias
        }

        if (-not $global:aliasBaselineReady) {
            $global:aliasBaselineReady = $true
        }

        if ($monitorMode -eq "Auto") {
            $currentIsConnectedToTarget = $currentIsConnected
        }
        else {
            $currentIsConnectedToTarget = (
                $currentState -ieq "connected" -and
                $currentHasValidBssid -and
                $currentSsid -ieq $target
            )
        }

        # ------------------------------------------------------------
        # Disconnect / reconnect detection
        # ------------------------------------------------------------
        # Used to avoid duplicate START/ROAM/SIGNAL logs on the same loop as a RECONNECTED event.
        $skipConnectedChangeLog = $false

        if ($invalidBssidForMonitoredSsid) {
            $skipConnectedChangeLog = $true
        }
        elseif ($global:lastConnectionState -eq "UNKNOWN") {
            if ($currentIsConnectedToTarget) {
                $global:lastConnectionState = "connected"
                $global:lastConnectedSsid = $interfaceInfo.SSID
            }
            else {
                Write-WiFiRoamWatcherLog -Path $logFile -Message "[$timestamp] START: Not connected to monitored SSID | Mode: $monitorMode | Current SSID: $($interfaceInfo.SSID) | State: $($interfaceInfo.State) | Monitoring SSID: $target | Visible APs: $apCount"

                $global:lastConnectionState = "disconnected"
                $global:lastConnectedSsid = "UNKNOWN"
                $skipConnectedChangeLog = $true
            }
        }
        elseif ($global:lastConnectionState -eq "connected" -and -not $currentIsConnectedToTarget) {
            Write-WiFiRoamWatcherLog -Path $logFile -Message "[$timestamp] DISCONNECTED: Lost connection to monitored SSID | Mode: $monitorMode | Previous SSID: $global:lastConnectedSsid | Previous AP: $global:lastBssid [$global:lastAlias] | Last Signal: $global:lastSignal% | Last RSSI: $(Format-Rssi -Rssi $global:lastRssi) | Last Chan: $global:lastChannel | Last visible AP count: $global:lastApCount | Current SSID: $($interfaceInfo.SSID) | Current State: $($interfaceInfo.State) | Monitoring SSID: $target"

            $global:lastConnectionState = "disconnected"
            $skipConnectedChangeLog = $true
        }
        elseif ($global:lastConnectionState -ne "connected" -and $currentIsConnectedToTarget) {
            $previousBssid = $global:lastBssid
            $previousAlias = $global:lastAlias
            $previousSignal = $global:lastSignal
            $previousRssi = $global:lastRssi
            $previousChannel = $global:lastChannel

            $reconnectAlias = "No Alias"

            if ($connectedNode -and $connectedNode.Alias) {
                $reconnectAlias = $connectedNode.Alias
            }
            elseif ($interfaceInfo.BSSID -ne "NONE") {
                $aliasFromInterface = Get-ApAlias -Bssid $interfaceInfo.BSSID -Aliases $apAliases

                if (-not [string]::IsNullOrWhiteSpace($aliasFromInterface)) {
                    $reconnectAlias = $aliasFromInterface
                }
            }

            Write-WiFiRoamWatcherLog -Path $logFile -Message "[$timestamp] RECONNECTED: Connected to monitored SSID $($interfaceInfo.SSID) | Mode: $monitorMode | AP: $($interfaceInfo.BSSID) [$reconnectAlias] | Signal: $($interfaceInfo.Signal)% | RSSI: $(Format-Rssi -Rssi $interfaceInfo.RSSI) | Chan: $($interfaceInfo.Channel) | Previous AP before disconnect: $previousBssid [$previousAlias] | Previous Signal: $previousSignal% | Previous RSSI: $(Format-Rssi -Rssi $previousRssi) | Previous Chan: $previousChannel | Visible APs: $apCount"

            $global:lastConnectionState = "connected"
            $global:lastConnectedSsid = $interfaceInfo.SSID

            if ($connectedNode) {
                $global:lastBssid = $connectedNode.BSSID
                $global:lastAlias = if ($connectedNode.Alias) { $connectedNode.Alias } else { "No Alias" }
                $global:lastSignal = $connectedNode.Signal
                $global:lastRssi = $interfaceInfo.RSSI
                $global:lastChannel = $connectedNode.Channel
            }
            else {
                $global:lastBssid = $interfaceInfo.BSSID
                $global:lastAlias = $reconnectAlias
                $global:lastSignal = $interfaceInfo.Signal
                $global:lastRssi = $interfaceInfo.RSSI
                $global:lastChannel = $interfaceInfo.Channel
            }

            # Reset AP-count baseline after reconnect so we do not log noisy 0 -> N changes.
            if ($apCount -gt 0) {
                $global:lastApCount = $apCount
            }

            $skipConnectedChangeLog = $true
        }

        # ------------------------------------------------------------
        # Connected AP / roam / signal logging
        # ------------------------------------------------------------
        if ($currentIsConnectedToTarget -and $connectedNode -and -not $skipConnectedChangeLog) {
            $thisMac = $connectedNode.BSSID
            $thisAlias = if ($connectedNode.Alias) { $connectedNode.Alias } else { "No Alias" }
            $thisSig = $connectedNode.Signal
            $thisRssi = $interfaceInfo.RSSI
            $thisChannel = $connectedNode.Channel

            if ($global:lastBssid -eq "NONE") {
                Write-WiFiRoamWatcherLog -Path $logFile -Message "[$timestamp] START: Current connection $thisMac [$thisAlias] | Mode: $monitorMode | SSID: $($interfaceInfo.SSID) | Signal: $thisSig% | RSSI: $(Format-Rssi -Rssi $thisRssi) | Chan: $thisChannel | APs seen: $apCount"

                $global:lastBssid = $thisMac
                $global:lastAlias = $thisAlias
                $global:lastSignal = $thisSig
                $global:lastRssi = $thisRssi
                $global:lastChannel = $thisChannel
                $global:lastConnectedSsid = $interfaceInfo.SSID
            }
            elseif ($thisMac -ne $global:lastBssid) {
                Write-WiFiRoamWatcherLog -Path $logFile -Message "[$timestamp] ROAMED: From $global:lastBssid [$global:lastAlias] | Signal: $global:lastSignal% | RSSI: $(Format-Rssi -Rssi $global:lastRssi) | Chan: $global:lastChannel -> To $thisMac [$thisAlias] | Mode: $monitorMode | SSID: $($interfaceInfo.SSID) | Signal: $thisSig% | RSSI: $(Format-Rssi -Rssi $thisRssi) | Chan: $thisChannel | APs seen: $apCount"

                $global:lastBssid = $thisMac
                $global:lastAlias = $thisAlias
                $global:lastSignal = $thisSig
                $global:lastRssi = $thisRssi
                $global:lastChannel = $thisChannel
                $global:lastConnectedSsid = $interfaceInfo.SSID
            }
            else {
                $signalChanged = $false
                $rssiChanged = $false

                if ($null -ne $thisSig -and $null -ne $global:lastSignal) {
                    if ([math]::Abs($thisSig - $global:lastSignal) -gt 5) {
                        $signalChanged = $true
                    }
                }

                if ($null -ne $thisRssi -and $null -ne $global:lastRssi) {
                    if ([math]::Abs($thisRssi - $global:lastRssi) -ge 5) {
                        $rssiChanged = $true
                    }
                }

                if ($signalChanged -or $rssiChanged) {
                    Write-WiFiRoamWatcherLog -Path $logFile -Message "[$timestamp] SIGNAL: Current $thisMac [$thisAlias] | Mode: $monitorMode | SSID: $($interfaceInfo.SSID) | From $global:lastSignal% / $(Format-Rssi -Rssi $global:lastRssi) to $thisSig% / $(Format-Rssi -Rssi $thisRssi) | Chan: $thisChannel | APs seen: $apCount"

                    $global:lastAlias = $thisAlias
                    $global:lastSignal = $thisSig
                    $global:lastRssi = $thisRssi
                    $global:lastChannel = $thisChannel
                    $global:lastConnectedSsid = $interfaceInfo.SSID
                }
            }
        }

        # ------------------------------------------------------------
        # AP count change logging
        # ------------------------------------------------------------
        # Only log AP-count changes while connected to the monitored SSID.
        # Ignore zero-count scans because Windows scan results can briefly return no APs.
        # Debounce changes so short-lived partial scan results do not spam the log.
        if ($currentIsConnectedToTarget -and (-not $invalidBssidForMonitoredSsid) -and $apCount -gt 0) {
            if ($global:lastApCount -eq -1) {
                $global:lastApCount = $apCount
                $global:pendingApCount = $null
                $global:pendingApCountSeen = 0
            }
            elseif ($apCount -eq $global:lastApCount) {
                $global:pendingApCount = $null
                $global:pendingApCountSeen = 0
            }
            else {
                if ($global:pendingApCount -eq $apCount) {
                    $global:pendingApCountSeen++
                }
                else {
                    $global:pendingApCount = $apCount
                    $global:pendingApCountSeen = 1
                }

                if ($global:pendingApCountSeen -ge $apCountDebounceSamples) {
                    Write-WiFiRoamWatcherLog -Path $logFile -Message "[$timestamp] AP_COUNT: Visible AP count changed from $global:lastApCount to $apCount while connected to $target"

                    $global:lastApCount = $apCount
                    $global:pendingApCount = $null
                    $global:pendingApCountSeen = 0
                }
            }
        }

        # ------------------------------------------------------------
        # Display
        # ------------------------------------------------------------
        Show-WiFiRoamWatcherScreen `
            -Version $scriptVersion `
            -MonitorMode $monitorMode `
            -TargetSsid $target `
            -InterfaceInfo $interfaceInfo `
            -AllNodes $allNodes `
            -ApCount $apCount `
            -AliasFiles $aliasFiles `
            -LogFile $logFile `
            -ConfigFile $configFile `
            -LastBssid $global:lastBssid `
            -LastAlias $global:lastAlias `
            -LastSignal $global:lastSignal `
            -LastRssi $global:lastRssi `
            -LastChannel $global:lastChannel `
            -LastApCount $global:lastApCount
    }
    catch {
        $timestamp = Get-LogTimestamp

        Write-WiFiRoamWatcherLog -Path $logFile -Message "[$timestamp] ERROR: $($_.Exception.Message)"

        Clear-Host
        Write-Host "Wi-Fi Roam Watcher v$scriptVersion" -ForegroundColor Yellow
        Write-Host "Error happened, but loop is continuing..." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Log file: $logFile" -ForegroundColor DarkGray
    }

    Start-Sleep -Seconds 2
}
