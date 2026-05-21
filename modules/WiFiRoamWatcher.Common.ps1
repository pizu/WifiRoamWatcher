function Normalize-Bssid {
    param(
        [string]$Text
    )

    if ($Text -match '(?<mac>[0-9A-Fa-f]{2}([-:][0-9A-Fa-f]{2}){5})') {
        return ($Matches['mac'] -replace '-', ':').ToLower()
    }

    return $null
}


function Test-ValidWifiBssid {
    param(
        [string]$Bssid
    )

    if ([string]::IsNullOrWhiteSpace($Bssid)) {
        return $false
    }

    $normalised = ($Bssid.Trim() -replace '-', ':').ToLower()

    if ($normalised -eq "none") {
        return $false
    }

    if ($normalised -eq "unknown") {
        return $false
    }

    if ($normalised -eq "00:00:00:00:00:00") {
        return $false
    }

    if ($normalised -notmatch '^[0-9a-f]{2}(:[0-9a-f]{2}){5}$') {
        return $false
    }

    return $true
}

function Format-Rssi {
    param(
        [object]$Rssi
    )

    if ($null -eq $Rssi -or [string]::IsNullOrWhiteSpace([string]$Rssi)) {
        return "Unknown"
    }

    return "$Rssi dBm"
}

function Get-LogTimestamp {
    return (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

function Write-WiFiRoamWatcherLog {
    param(
        [string]$Path,
        [string]$Message
    )

    $folder = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($folder) -and -not (Test-Path $folder)) {
        New-Item -Path $folder -ItemType Directory -Force | Out-Null
    }

    Add-Content -Path $Path -Value $Message
}

function Select-WiFiRoamWatcherTargetSsid {
    param(
        [string]$CurrentSsid,
        [string]$Version
    )

    while ($true) {
        Clear-Host

        Write-Host "Wi-Fi Roam Watcher Startup v$Version" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Current connected SSID: $CurrentSsid" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1. Auto - monitor any SSID I am connected to"
        Write-Host "2. Use current connected SSID"
        Write-Host "3. Enter SSID manually"
        Write-Host "Q. Quit"
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice.ToUpper()) {
            "1" {
                $initialTarget = "AUTO"

                if (-not [string]::IsNullOrWhiteSpace($CurrentSsid) -and $CurrentSsid -ne "UNKNOWN") {
                    $initialTarget = $CurrentSsid
                }

                return [PSCustomObject]@{
                    Mode       = "Auto"
                    TargetSsid = $initialTarget
                }
            }

            "2" {
                if ([string]::IsNullOrWhiteSpace($CurrentSsid) -or $CurrentSsid -eq "UNKNOWN") {
                    Write-Host "No connected SSID detected." -ForegroundColor Red
                    Start-Sleep -Seconds 2
                }
                else {
                    return [PSCustomObject]@{
                        Mode       = "Current"
                        TargetSsid = $CurrentSsid
                    }
                }
            }

            "3" {
                $manual = Read-Host "Enter SSID to monitor"

                if (-not [string]::IsNullOrWhiteSpace($manual)) {
                    return [PSCustomObject]@{
                        Mode       = "Manual"
                        TargetSsid = $manual.Trim()
                    }
                }

                Write-Host "SSID cannot be empty." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }

            "Q" {
                return $null
            }

            default {
                Write-Host "Invalid option." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}
