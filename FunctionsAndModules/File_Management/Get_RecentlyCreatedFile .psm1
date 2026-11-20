function Get-RecentlyCreatedFile {
    <#
    .SYNOPSIS
        Finds files created/modified on the system drive within a time window.

    .DESCRIPTION
        Recursively scans the entire system drive (C:\ by default) for files
        whose CreationTime or LastWriteTime falls inside the supplied window
        (default: last 24 hours).

    .PARAMETER Start
        Start of the window. Defaults to 24 hours ago.

    .PARAMETER End
        End of the window. Defaults to now.

    .PARAMETER Drive
        Drive root to scan. Defaults to $env:SystemDrive.

    .PARAMETER Depth
        Max recursion depth. Defaults to 6 to bound scan time.

    .EXAMPLE
        Get-RecentlyCreatedFile
        Get-RecentlyCreatedFile -Start (Get-Date).AddHours(-12)
        Get-RecentlyCreatedFile -Start '2026-07-28 14:00' -End '2026-07-29 14:00'
        Get-RecentlyCreatedFile -Drive 'D:\' -Depth 4
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [datetime]$Start = (Get-Date).AddDays(-1),

        [Parameter(Position = 1)]
        [datetime]$End = (Get-Date),

        [Parameter(Position = 2)]
        [string]$Drive = $env:SystemDrive,

        [Parameter(Position = 3)]
        [int]$Depth = 6
    )

    $Root = Join-Path $Drive '\'
    Write-Information "=== Recently Created/Modified Files : $Start -> $End ===" -InformationAction Continue
    Write-Information "Scanning: $Root (depth $Depth)" -InformationAction Continue

    if (-not (Test-Path $Root)) {
        Write-Warning "Drive root not found: $Root"
        return
    }

    $count = 0
    try {
        Get-ChildItem -Path $Root -Recurse -File -Depth $Depth -ErrorAction SilentlyContinue |
            Where-Object { ($_.CreationTime -gt $Start -and $_.CreationTime -le $End) -or
                           ($_.LastWriteTime -gt $Start -and $_.LastWriteTime -le $End) } |
            ForEach-Object {
                $count++
                Write-Information ("{0}  {1}  ({2} bytes)  C:{3}  W:{4}" -f `
                    $_.FullName, $_.Length, $_.Length, $_.CreationTime, $_.LastWriteTime) `
                    -InformationAction Continue
            }
    }
    catch {
        Write-Error $_
        return
    }

    if ($count -eq 0) {
        Write-Warning "No files found in window."
    }
    else {
        Write-Information "Total files: $count" -InformationAction Continue
    }
}