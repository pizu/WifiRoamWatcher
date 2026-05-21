function Get-WiFiRoamWatcherShortReason {
    param(
        [string]$Reason
    )

    # Keep capture folder names short to avoid Windows PowerShell 5.1 MAX_PATH issues.
    switch -Regex ($Reason) {
        '^zero-bssid$'            { return 'zbs' }
        default {
            $safeReason = $Reason -replace '[^A-Za-z0-9_\-]+', '_'
            if ([string]::IsNullOrWhiteSpace($safeReason)) {
                return 'diag'
            }
            return $safeReason.Substring(0, [Math]::Min(24, $safeReason.Length))
        }
    }
}

function Test-WiFiRoamWatcherIsAdministrator {
    # netsh wlan show wlanreport must be run from an elevated prompt.
    # This helper lets the diagnostics module skip that part cleanly when the script is not elevated.
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Invoke-WiFiRoamWatcherNetshCapture {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$OutputFile
    )

    $netshExe = Join-Path $env:SystemRoot "System32\netsh.exe"
    $output = & $netshExe @Arguments 2>&1

    "COMMAND: netsh $($Arguments -join ' ')" | Out-File -LiteralPath $OutputFile -Encoding UTF8 -ErrorAction Stop
    "" | Out-File -LiteralPath $OutputFile -Append -Encoding UTF8 -ErrorAction Stop
    $output | Out-File -LiteralPath $OutputFile -Append -Encoding UTF8 -ErrorAction Stop

    return $output
}

function Wait-WiFiRoamWatcherWlanReport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportPath,

        [Parameter(Mandatory = $true)]
        [datetime]$StartedAt,

        [int]$TimeoutSeconds = 90
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $lastLength = -1
    $stableCount = 0

    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $ReportPath) {
            $item = Get-Item -LiteralPath $ReportPath -ErrorAction SilentlyContinue

            if ($item -and $item.Length -gt 0 -and $item.LastWriteTime -ge $StartedAt.AddSeconds(-10)) {
                if ($item.Length -eq $lastLength) {
                    $stableCount++
                }
                else {
                    $stableCount = 0
                    $lastLength = $item.Length
                }

                # Two stable reads means the file is very likely finished being written.
                if ($stableCount -ge 2) {
                    return $item
                }
            }
        }

        Start-Sleep -Seconds 2
    }

    if (Test-Path -LiteralPath $ReportPath) {
        return (Get-Item -LiteralPath $ReportPath -ErrorAction SilentlyContinue)
    }

    return $null
}

function Invoke-WiFiRoamWatcherDiagnosticCapture {
    param(
        [string]$Reason = "wifi-diagnostic",
        [string]$DiagnosticRoot = ".\diagnostics",
        [int]$WlanReportDurationDays = 3,
        [int]$WlanReportWaitSeconds = 90
    )

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $shortReason = Get-WiFiRoamWatcherShortReason -Reason $Reason
    $captureDir = Join-Path $DiagnosticRoot "$timestamp-$shortReason"

    New-Item -ItemType Directory -Path $captureDir -Force -ErrorAction Stop | Out-Null

    $summaryFile = Join-Path $captureDir "summary.txt"
    $isAdministrator = Test-WiFiRoamWatcherIsAdministrator
    $wlanReportStatus = "not-run"
    $wlanReportPath = ""

    "Wi-Fi Roam Watcher Diagnostic Capture" | Out-File -LiteralPath $summaryFile -Encoding UTF8 -ErrorAction Stop
    "Timestamp : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -LiteralPath $summaryFile -Append -Encoding UTF8 -ErrorAction Stop
    "Reason    : $Reason" | Out-File -LiteralPath $summaryFile -Append -Encoding UTF8 -ErrorAction Stop
    "Folder    : $captureDir" | Out-File -LiteralPath $summaryFile -Append -Encoding UTF8 -ErrorAction Stop
    "Computer  : $env:COMPUTERNAME" | Out-File -LiteralPath $summaryFile -Append -Encoding UTF8 -ErrorAction Stop
    "User      : $env:USERNAME" | Out-File -LiteralPath $summaryFile -Append -Encoding UTF8 -ErrorAction Stop
    "Admin     : $isAdministrator" | Out-File -LiteralPath $summaryFile -Append -Encoding UTF8 -ErrorAction Stop
    "" | Out-File -LiteralPath $summaryFile -Append -Encoding UTF8 -ErrorAction Stop

    # Short file names are intentional. They keep the full path below the legacy 260-character limit.
    Invoke-WiFiRoamWatcherNetshCapture `
        -Arguments @("wlan", "show", "interfaces") `
        -OutputFile (Join-Path $captureDir "interfaces.txt") | Out-Null

    Invoke-WiFiRoamWatcherNetshCapture `
        -Arguments @("wlan", "show", "networks", "mode=bssid") `
        -OutputFile (Join-Path $captureDir "networks-bssid.txt") | Out-Null

    Invoke-WiFiRoamWatcherNetshCapture `
        -Arguments @("wlan", "show", "drivers") `
        -OutputFile (Join-Path $captureDir "drivers.txt") | Out-Null

    $wlanReportOutputFile = Join-Path $captureDir "wlanreport-output.txt"

    if ($isAdministrator) {
        $wlanReportStartedAt = Get-Date

        Invoke-WiFiRoamWatcherNetshCapture `
            -Arguments @("wlan", "show", "wlanreport", "duration=$WlanReportDurationDays") `
            -OutputFile $wlanReportOutputFile | Out-Null

        $defaultWlanReportDir = Join-Path $env:ProgramData "Microsoft\Windows\WlanReport"
        $latestReportPath = Join-Path $defaultWlanReportDir "wlan-report-latest.html"
        $latestReport = Wait-WiFiRoamWatcherWlanReport `
            -ReportPath $latestReportPath `
            -StartedAt $wlanReportStartedAt `
            -TimeoutSeconds $WlanReportWaitSeconds

        if (-not $latestReport) {
            $latestReport = Get-ChildItem -Path $defaultWlanReportDir -Filter "*.html" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
        }

        if ($latestReport) {
            # Use a timestamped but short HTML name to avoid long-path failures.
            $targetReport = Join-Path $captureDir "wlan-$timestamp.html"
            Copy-Item -LiteralPath $latestReport.FullName -Destination $targetReport -Force -ErrorAction Stop

            "WLAN report copied from: $($latestReport.FullName)" | Out-File -LiteralPath $summaryFile -Append -Encoding UTF8 -ErrorAction Stop
            "WLAN report copied to  : $targetReport" | Out-File -LiteralPath $summaryFile -Append -Encoding UTF8 -ErrorAction Stop
            "WLAN report wait limit : $WlanReportWaitSeconds seconds" | Out-File -LiteralPath $summaryFile -Append -Encoding UTF8 -ErrorAction Stop
            $wlanReportStatus = "copied"
            $wlanReportPath = $targetReport
        }
        else {
            "WARNING: WLAN report HTML file was not found in $defaultWlanReportDir after waiting up to $WlanReportWaitSeconds seconds." | Out-File -LiteralPath $summaryFile -Append -Encoding UTF8 -ErrorAction Stop
            $wlanReportStatus = "not-found"
        }
    }
    else {
        "COMMAND: netsh wlan show wlanreport duration=$WlanReportDurationDays" | Out-File -LiteralPath $wlanReportOutputFile -Encoding UTF8 -ErrorAction Stop
        "" | Out-File -LiteralPath $wlanReportOutputFile -Append -Encoding UTF8 -ErrorAction Stop
        "SKIPPED: This command must be run from an elevated PowerShell or Command Prompt." | Out-File -LiteralPath $wlanReportOutputFile -Append -Encoding UTF8 -ErrorAction Stop
        "Run Start-WiFiRoamWatcher.ps1 as Administrator to collect the WLAN HTML report automatically." | Out-File -LiteralPath $wlanReportOutputFile -Append -Encoding UTF8 -ErrorAction Stop

        "WLAN report skipped: Start-WiFiRoamWatcher.ps1 is not running as Administrator." | Out-File -LiteralPath $summaryFile -Append -Encoding UTF8 -ErrorAction Stop
        "WLAN report note   : Microsoft requires netsh wlan show wlanreport to run from an elevated prompt." | Out-File -LiteralPath $summaryFile -Append -Encoding UTF8 -ErrorAction Stop
        $wlanReportStatus = "skipped-not-admin"
    }

    return [PSCustomObject]@{
        CaptureDir       = $captureDir
        Reason           = $Reason
        Timestamp        = $timestamp
        IsAdministrator  = $isAdministrator
        WlanReportStatus = $wlanReportStatus
        WlanReportPath   = $wlanReportPath
    }
}
