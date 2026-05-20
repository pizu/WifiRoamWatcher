function Get-CurrentWifiInterface {
    $interfaceOutput = netsh wlan show interfaces all

    $activeState = "UNKNOWN"
    $activeSsid = "UNKNOWN"
    $activeBssid = "NONE"
    $activeSignal = $null
    $activeRssi = $null
    $activeChannel = "UNKNOWN"
    $activeBand = "UNKNOWN"
    $activeRadio = "UNKNOWN"
    $activeRxRate = "UNKNOWN"
    $activeTxRate = "UNKNOWN"

    foreach ($line in $interfaceOutput) {
        if ($line -match '^\s*State\s*:\s*(?<state>.+?)\s*$') {
            $activeState = $Matches['state'].Trim()
            continue
        }

        if ($line -match '^\s*SSID\s*:\s*(?<ssid>.+?)\s*$') {
            $activeSsid = $Matches['ssid'].Trim()
            continue
        }

        if ($line -match '^\s*(AP\s+)?BSSID\s*:\s*(?<bssid>[0-9a-f]{2}[:-][0-9a-f]{2}[:-][0-9a-f]{2}[:-][0-9a-f]{2}[:-][0-9a-f]{2}[:-][0-9a-f]{2})') {
            $activeBssid = ($Matches['bssid'] -replace '-', ':').ToLower()
            continue
        }

        if ($line -match '^\s*Signal\s*:\s*(?<signal>\d+)%') {
            $activeSignal = [int]$Matches['signal']
            continue
        }

        if ($line -match '^\s*Rssi\s*:\s*(?<rssi>-?\d+)') {
            $activeRssi = [int]$Matches['rssi']
            continue
        }

        if ($line -match '^\s*Channel\s*:\s*(?<channel>\d+)') {
            $activeChannel = $Matches['channel']
            continue
        }

        if ($line -match '^\s*Band\s*:\s*(?<band>.+?)\s*$') {
            $activeBand = $Matches['band'].Trim()
            continue
        }

        if ($line -match '^\s*Radio type\s*:\s*(?<radio>.+?)\s*$') {
            $activeRadio = $Matches['radio'].Trim()
            continue
        }

        if ($line -match '^\s*Receive rate \(Mbps\)\s*:\s*(?<rx>.+?)\s*$') {
            $activeRxRate = $Matches['rx'].Trim()
            continue
        }

        if ($line -match '^\s*Transmit rate \(Mbps\)\s*:\s*(?<tx>.+?)\s*$') {
            $activeTxRate = $Matches['tx'].Trim()
            continue
        }
    }

    return [PSCustomObject]@{
        State   = $activeState
        SSID    = $activeSsid
        BSSID   = $activeBssid
        Signal  = $activeSignal
        RSSI    = $activeRssi
        Channel = $activeChannel
        Band    = $activeBand
        Radio   = $activeRadio
        RxRate  = $activeRxRate
        TxRate  = $activeTxRate
        Raw     = $interfaceOutput
    }
}

function Get-VisibleWifiBssids {
    param(
        [string]$TargetSsid,
        [string]$ActiveBssid,
        [string]$ActiveSsid,
        [object]$ActiveSignal,
        [object]$ActiveChannel,
        [array]$Aliases
    )

    if ([string]::IsNullOrWhiteSpace($TargetSsid) -or $TargetSsid -eq "AUTO") {
        return @()
    }

    $targetRegex = [regex]::Escape($TargetSsid)
    $scan = netsh wlan show networks mode=bssid

    $foundTargetSsid = $false
    $currentBssid = $null
    $currentSignal = $null

    $allNodes = @(foreach ($line in $scan) {
        if ($line -match "^\s*SSID\s+\d+\s+:\s+$targetRegex\s*$") {
            $foundTargetSsid = $true
            continue
        }

        if ($line -match "^\s*SSID\s+\d+\s+:") {
            $foundTargetSsid = $false
            continue
        }

        if ($foundTargetSsid) {
            if ($line -match "^\s*BSSID\s+\d+\s+:\s+(?<m>.+)$") {
                $currentBssid = Normalize-Bssid $Matches['m']
                $currentSignal = $null
                continue
            }

            if ($line -match "^\s*Signal\s+:\s+(?<s>\d+)%") {
                $currentSignal = [int]$Matches['s']
                continue
            }

            if ($line -match "^\s*Channel\s+:\s+(?<c>\d+)") {
                $channel = $Matches['c']

                if ($currentBssid) {
                    $status = if (($currentBssid -eq $ActiveBssid) -and ($ActiveSsid -eq $TargetSsid)) { "CONNECTED" } else { "" }
                    $alias = Get-ApAlias -Bssid $currentBssid -Aliases $Aliases

                    [PSCustomObject]@{
                        SSID    = $TargetSsid
                        Alias   = $alias
                        BSSID   = $currentBssid
                        Signal  = $currentSignal
                        Channel = $channel
                        Status  = $status
                    }
                }
            }
        }
    })

    $connectedFromScan = $allNodes |
        Where-Object { $_.Status -eq "CONNECTED" } |
        Select-Object -First 1

    if (-not $connectedFromScan -and $ActiveBssid -ne "NONE" -and $ActiveSsid -eq $TargetSsid) {
        $alias = Get-ApAlias -Bssid $ActiveBssid -Aliases $Aliases

        $allNodes += [PSCustomObject]@{
            SSID    = $TargetSsid
            Alias   = $alias
            BSSID   = $ActiveBssid
            Signal  = $ActiveSignal
            Channel = $ActiveChannel
            Status  = "CONNECTED"
        }
    }

    return $allNodes
}
