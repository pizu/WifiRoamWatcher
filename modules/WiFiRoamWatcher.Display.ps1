function Show-WiFiRoamWatcherScreen {
    param(
        [string]$Version,
        [string]$MonitorMode,
        [string]$TargetSsid,
        [object]$InterfaceInfo,
        [array]$AllNodes,
        [int]$ApCount,
        [array]$AliasFiles,
        [string]$LogFile,
        [string]$ConfigFile,
        [string]$LastBssid,
        [string]$LastAlias,
        [object]$LastSignal,
        [object]$LastRssi,
        [object]$LastChannel,
        [int]$LastApCount
    )

    Clear-Host

    $aliasText = "None configured"
    if ($AliasFiles -and @($AliasFiles).Count -gt 0) {
        $aliasText = ($AliasFiles -join ", ")
    }

    $activeBssidText = $InterfaceInfo.BSSID

    if ($InterfaceInfo.State -ieq "connected" -and -not (Test-ValidWifiBssid -Bssid $InterfaceInfo.BSSID)) {
        $activeBssidText = "$($InterfaceInfo.BSSID) (invalid/pending)"
    }

    Write-Host "Wi-Fi Roam Watcher v$Version" -ForegroundColor Yellow
    Write-Host "Mode: $MonitorMode" -ForegroundColor Yellow
    Write-Host "Monitoring SSID: $TargetSsid" -ForegroundColor Yellow
    Write-Host "Connected SSID: $($InterfaceInfo.SSID)" -ForegroundColor Cyan
    Write-Host "Connection State: $($InterfaceInfo.State)" -ForegroundColor Cyan
    Write-Host "Active BSSID: $activeBssidText" -ForegroundColor Cyan
    Write-Host "Active Signal: $($InterfaceInfo.Signal)%" -ForegroundColor Cyan
    Write-Host "Active RSSI: $(Format-Rssi -Rssi $InterfaceInfo.RSSI)" -ForegroundColor Cyan
    Write-Host "Band: $($InterfaceInfo.Band) | Channel: $($InterfaceInfo.Channel) | Radio: $($InterfaceInfo.Radio)" -ForegroundColor Cyan
    Write-Host "RX: $($InterfaceInfo.RxRate) Mbps | TX: $($InterfaceInfo.TxRate) Mbps" -ForegroundColor Cyan
    Write-Host "Visible AP count: $ApCount" -ForegroundColor Magenta
    Write-Host "Alias files: $aliasText" -ForegroundColor DarkGray
    Write-Host "Config file: $ConfigFile" -ForegroundColor DarkGray
    Write-Host "Log file: $LogFile" -ForegroundColor DarkGray
    Write-Host ""

    if ($AllNodes) {
        $AllNodes |
            Sort-Object Signal -Descending |
            Format-Table `
                @{L='SSID';E={$_.SSID}},
                @{L='Alias';E={$_.Alias}},
                @{L='BSSID';E={$_.BSSID}},
                @{L='Signal';E={"$($_.Signal)%"}},
                @{L='Channel';E={$_.Channel}},
                @{L='Status';E={$_.Status}} -AutoSize
    }
    else {
        Write-Host "No BSSID entries found for SSID: $TargetSsid" -ForegroundColor Red
    }

    Write-Host ""

    $connectedNode = $AllNodes |
        Where-Object { $_.Status -eq "CONNECTED" } |
        Select-Object -First 1

    if ($connectedNode) {
        $currentAlias = if ($connectedNode.Alias) { $connectedNode.Alias } else { "No Alias" }

        Write-Host "Current Connected MAC: $($connectedNode.BSSID) [$currentAlias] ($($connectedNode.Signal)%, RSSI: $(Format-Rssi -Rssi $InterfaceInfo.RSSI)) Chan: $($connectedNode.Channel)" -ForegroundColor Green
    }
    elseif ($InterfaceInfo.State -ieq "connected" -and -not (Test-ValidWifiBssid -Bssid $InterfaceInfo.BSSID)) {
        Write-Host "Current Connected MAC: pending/invalid from Windows: $($InterfaceInfo.BSSID)" -ForegroundColor DarkYellow
    }
    else {
        Write-Host "Current Connected MAC: NONE" -ForegroundColor Red
    }

    Write-Host "Last Logged MAC: $LastBssid [$LastAlias] ($LastSignal%, RSSI: $(Format-Rssi -Rssi $LastRssi)) Chan: $LastChannel" -ForegroundColor Cyan
    Write-Host "Last AP count: $LastApCount" -ForegroundColor Magenta
    Write-Host "Press CTRL+C to stop." -ForegroundColor DarkGray
}
