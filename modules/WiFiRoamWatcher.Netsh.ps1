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
    $activeName = "UNKNOWN"
    $activeDescription = "UNKNOWN"
    $activeGuid = "UNKNOWN"
    $activeMacAddress = "UNKNOWN"

    foreach ($line in $interfaceOutput) {
        if ($line -match '^\s*Name\s*:\s*(?<name>.+?)\s*$') {
            $activeName = $Matches['name'].Trim()
            continue
        }

        if ($line -match '^\s*Description\s*:\s*(?<description>.+?)\s*$') {
            $activeDescription = $Matches['description'].Trim()
            continue
        }

        if ($line -match '^\s*GUID\s*:\s*(?<guid>.+?)\s*$') {
            $activeGuid = $Matches['guid'].Trim()
            continue
        }

        if ($line -match '^\s*Physical address\s*:\s*(?<mac>[0-9a-f]{2}[:-][0-9a-f]{2}[:-][0-9a-f]{2}[:-][0-9a-f]{2}[:-][0-9a-f]{2}[:-][0-9a-f]{2})') {
            $activeMacAddress = ($Matches['mac'] -replace '-', ':').ToLower()
            continue
        }

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
        Name    = $activeName
        Description = $activeDescription
        GUID    = $activeGuid
        MacAddress = $activeMacAddress
        Raw     = $interfaceOutput
    }
}


function Get-WiFiRoamWatcherManagementObjects {
    param(
        [string]$ClassName
    )

    try {
        if (Get-Command Get-CimInstance -CommandType Cmdlet -ErrorAction SilentlyContinue) {
            return @(Get-CimInstance -ClassName $ClassName -ErrorAction Stop)
        }
    }
    catch {
        # Fall back to Get-WmiObject below when Get-CimInstance is unavailable or fails.
    }

    try {
        if (Get-Command Get-WmiObject -CommandType Cmdlet -ErrorAction SilentlyContinue) {
            return @(Get-WmiObject -Class $ClassName -ErrorAction Stop)
        }
    }
    catch {
        # Return an empty list if Windows management queries are unavailable.
    }

    return @()
}

function Format-WiFiRoamWatcherDriverDate {
    param(
        [object]$DriverDate
    )

    if ($null -eq $DriverDate -or [string]::IsNullOrWhiteSpace([string]$DriverDate)) {
        return "UNKNOWN"
    }

    try {
        if ($DriverDate -is [datetime]) {
            return $DriverDate.ToString("yyyy-MM-dd")
        }
    }
    catch {
        # Continue with string handling below.
    }

    $dateText = ([string]$DriverDate).Trim()

    try {
        if ($dateText -match '^\d{14}\.\d{6}[+-]\d{3}$') {
            $parsedDate = [System.Management.ManagementDateTimeConverter]::ToDateTime($dateText)
            return $parsedDate.ToString("yyyy-MM-dd")
        }
    }
    catch {
        # If the date cannot be parsed, return the original driver date string.
    }

    return $dateText
}

function Get-WiFiRoamWatcherClientInfo {
    param(
        [object]$InterfaceInfo
    )

    $hostname = $env:COMPUTERNAME

    if ([string]::IsNullOrWhiteSpace($hostname)) {
        try {
            $hostname = [System.Net.Dns]::GetHostName()
        }
        catch {
            $hostname = "UNKNOWN"
        }
    }

    $interfaceName = "UNKNOWN"
    $adapterDescription = "UNKNOWN"
    $adapterGuid = "UNKNOWN"
    $macAddress = "UNKNOWN"

    if ($null -ne $InterfaceInfo) {
        if (-not [string]::IsNullOrWhiteSpace([string]$InterfaceInfo.Name)) {
            $interfaceName = ([string]$InterfaceInfo.Name).Trim()
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$InterfaceInfo.Description)) {
            $adapterDescription = ([string]$InterfaceInfo.Description).Trim()
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$InterfaceInfo.GUID)) {
            $adapterGuid = ([string]$InterfaceInfo.GUID).Trim()
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$InterfaceInfo.MacAddress)) {
            $macAddress = (([string]$InterfaceInfo.MacAddress).Trim() -replace '-', ':').ToLower()
        }
    }

    $driverProvider = "UNKNOWN"
    $driverVersion = "UNKNOWN"
    $driverDate = "UNKNOWN"

    $networkAdapter = $null
    $networkAdapters = Get-WiFiRoamWatcherManagementObjects -ClassName "Win32_NetworkAdapter"

    if ($networkAdapters.Count -gt 0) {
        if (-not [string]::IsNullOrWhiteSpace($adapterGuid) -and $adapterGuid -ne "UNKNOWN") {
            $networkAdapter = $networkAdapters |
                Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.GUID) -and ([string]$_.GUID).Trim() -ieq $adapterGuid } |
                Select-Object -First 1
        }

        if ($null -eq $networkAdapter -and -not [string]::IsNullOrWhiteSpace($macAddress) -and $macAddress -ne "UNKNOWN") {
            $networkAdapter = $networkAdapters |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace([string]$_.MACAddress) -and
                    ((([string]$_.MACAddress).Trim() -replace '-', ':').ToLower() -eq $macAddress)
                } |
                Select-Object -First 1
        }

        if ($null -eq $networkAdapter -and -not [string]::IsNullOrWhiteSpace($interfaceName) -and $interfaceName -ne "UNKNOWN") {
            $networkAdapter = $networkAdapters |
                Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.NetConnectionID) -and ([string]$_.NetConnectionID).Trim() -ieq $interfaceName } |
                Select-Object -First 1
        }

        if ($null -eq $networkAdapter -and -not [string]::IsNullOrWhiteSpace($adapterDescription) -and $adapterDescription -ne "UNKNOWN") {
            $networkAdapter = $networkAdapters |
                Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.Description) -and ([string]$_.Description).Trim() -ieq $adapterDescription } |
                Select-Object -First 1
        }
    }

    if ($null -ne $networkAdapter) {
        if (-not [string]::IsNullOrWhiteSpace([string]$networkAdapter.NetConnectionID)) {
            $interfaceName = ([string]$networkAdapter.NetConnectionID).Trim()
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$networkAdapter.Description)) {
            $adapterDescription = ([string]$networkAdapter.Description).Trim()
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$networkAdapter.MACAddress)) {
            $macAddress = (([string]$networkAdapter.MACAddress).Trim() -replace '-', ':').ToLower()
        }

        $signedDrivers = Get-WiFiRoamWatcherManagementObjects -ClassName "Win32_PnPSignedDriver"
        $signedDriver = $null

        if ($signedDrivers.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$networkAdapter.PNPDeviceID)) {
            $pnpDeviceId = ([string]$networkAdapter.PNPDeviceID).Trim()

            $signedDriver = $signedDrivers |
                Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.DeviceID) -and ([string]$_.DeviceID).Trim() -ieq $pnpDeviceId } |
                Select-Object -First 1
        }

        if ($null -eq $signedDriver -and $signedDrivers.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($adapterDescription) -and $adapterDescription -ne "UNKNOWN") {
            $signedDriver = $signedDrivers |
                Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.DeviceName) -and ([string]$_.DeviceName).Trim() -ieq $adapterDescription } |
                Select-Object -First 1
        }

        if ($null -ne $signedDriver) {
            if (-not [string]::IsNullOrWhiteSpace([string]$signedDriver.DriverProviderName)) {
                $driverProvider = ([string]$signedDriver.DriverProviderName).Trim()
            }

            if (-not [string]::IsNullOrWhiteSpace([string]$signedDriver.DriverVersion)) {
                $driverVersion = ([string]$signedDriver.DriverVersion).Trim()
            }

            if (-not [string]::IsNullOrWhiteSpace([string]$signedDriver.DriverDate)) {
                $driverDate = Format-WiFiRoamWatcherDriverDate -DriverDate $signedDriver.DriverDate
            }
        }
    }

    return [PSCustomObject]@{
        Hostname = $hostname
        InterfaceName = $interfaceName
        AdapterDescription = $adapterDescription
        MacAddress = $macAddress
        DriverProvider = $driverProvider
        DriverVersion = $driverVersion
        DriverDate = $driverDate
    }
}

function Format-WiFiRoamWatcherClientInfoLogLine {
    param(
        [object]$ClientInfo
    )

    if ($null -eq $ClientInfo) {
        return "CLIENT_INFO: Hostname: UNKNOWN | Interface: UNKNOWN | Adapter: UNKNOWN | Wi-Fi MAC: UNKNOWN | Driver Provider: UNKNOWN | Driver Version: UNKNOWN | Driver Date: UNKNOWN"
    }

    return "CLIENT_INFO: Hostname: $($ClientInfo.Hostname) | Interface: $($ClientInfo.InterfaceName) | Adapter: $($ClientInfo.AdapterDescription) | Wi-Fi MAC: $($ClientInfo.MacAddress) | Driver Provider: $($ClientInfo.DriverProvider) | Driver Version: $($ClientInfo.DriverVersion) | Driver Date: $($ClientInfo.DriverDate)"
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
    $activeBssidIsValid = Test-ValidWifiBssid -Bssid $ActiveBssid
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
                    $status = if ($activeBssidIsValid -and ($currentBssid -eq $ActiveBssid) -and ($ActiveSsid -eq $TargetSsid)) { "CONNECTED" } else { "" }
                    $alias = Get-ApAlias -Bssid $currentBssid -Aliases $Aliases

                    [PSCustomObject]@{
                        SSID    = $TargetSsid
                        Alias   = $alias
                        BSSID   = $currentBssid
                        Signal  = $currentSignal
                        Channel = $channel
                        Status  = $status
                        Source  = "SCAN"
                    }
                }
            }
        }
    })

    $connectedFromScan = $allNodes |
        Where-Object { $_.Status -eq "CONNECTED" } |
        Select-Object -First 1

    if (-not $connectedFromScan -and $activeBssidIsValid -and $ActiveSsid -eq $TargetSsid) {
        $alias = Get-ApAlias -Bssid $ActiveBssid -Aliases $Aliases

        $allNodes += [PSCustomObject]@{
            SSID    = $TargetSsid
            Alias   = $alias
            BSSID   = $ActiveBssid
            Signal  = $ActiveSignal
            Channel = $ActiveChannel
            Status  = "CONNECTED"
            Source  = "INTERFACE_FALLBACK"
        }
    }

    return $allNodes
}
