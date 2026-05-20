function Get-AliasFilesFromConfig {
    param(
        [string]$AliasListPath,
        [string]$AliasList
    )

    $files = @()

    if ([string]::IsNullOrWhiteSpace($AliasList)) {
        return $files
    }

    foreach ($item in ($AliasList -split ',')) {
        $name = $item.Trim()

        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        $expanded = [Environment]::ExpandEnvironmentVariables($name)

        if ([System.IO.Path]::IsPathRooted($expanded)) {
            $files += $expanded
        }
        else {
            $files += (Join-Path $AliasListPath $expanded)
        }
    }

    return $files
}

function Load-ApAliases {
    param(
        [array]$Paths
    )

    $allAliases = @()

    if ($null -eq $Paths -or @($Paths).Count -eq 0) {
        return $allAliases
    }

    foreach ($path in $Paths) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }

        if (-not (Test-Path $path)) {
            continue
        }

        try {
            $firstLine = Get-Content -Path $path -TotalCount 1
            $rows = @()

            if ($firstLine -match "`t") {
                $rows = Import-Csv -Path $path -Delimiter "`t"
            }
            elseif ($firstLine -match ";") {
                $rows = Import-Csv -Path $path -Delimiter ";"
            }
            else {
                $rows = Import-Csv -Path $path
            }

            foreach ($row in $rows) {
                $allAliases += $row
            }
        }
        catch {
            # Ignore bad alias files so monitoring can continue.
        }
    }

    return $allAliases
}

function Get-ApAlias {
    param(
        [string]$Bssid,
        [array]$Aliases
    )

    if (-not $Bssid) {
        return ""
    }

    foreach ($entry in $Aliases) {
        $matchText = ""

        if ($entry.PSObject.Properties.Name -contains "Match") {
            $matchText = [string]$entry.Match
        }

        if ([string]::IsNullOrWhiteSpace($matchText)) {
            continue
        }

        $matchText = ($matchText -replace '-', ':').ToLower().Trim()

        if ($Bssid.ToLower().Contains($matchText)) {
            if ($entry.PSObject.Properties.Name -contains "Alias") {
                return ([string]$entry.Alias).Trim()
            }
        }
    }

    return ""
}
