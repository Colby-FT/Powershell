function Add-DateRangeToFileName {
    <#
    .SYNOPSIS
        Renames files by appending the earliest and latest dates found inside.
    
    .DESCRIPTION
        Scans file content for dates. Prioritizes ISO 8601 (yyyy-MM-ddTHH:mm:ssZ)
        common in Azure/Entra logs, then falls back to U.S. numeric formats.
        Includes strict validation to prevent false positives from GUIDs or versions.
    
    .PARAMETER Path
        Path to the file(s). Supports pipeline input.
    
    .PARAMETER DateFormat
        The format for the date in the new filename. Default: M-d-yy.
    
    .EXAMPLE
        Get-ChildItem -Path "C:\FT\TestHere\*" | Add-DateRangeToFileName -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName')]
        [string[]]$Path,

        [Parameter(Position = 1)]
        [string]$DateFormat = 'M-d-yy'
    )

    Begin {
        Write-Verbose "[$($MyInvocation.InvocationName)] Initializing date parser."

        # Pattern 1: ISO 8601 with optional time (Azure/Entra log format)
        # Matches: 2026-07-14T06:59:59Z or 2026-07-14
        $IsoPattern = '\b(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})(?:T\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{2}:\d{2})?)?\b'

        # Pattern 2: U.S. numeric (M/d/yyyy or MM/dd/yy)
        # Enforces word boundaries to avoid matching inside GUIDs
        $UsPattern = '\b(?<month>\d{1,2})/(?<day>\d{1,2})/(?<year>\d{4})\b'

        # Pattern 3: U.S. short year (M/d/yy)
        $UsShortPattern = '\b(?<month>\d{1,2})/(?<day>\d{1,2})/(?<year>\d{2})\b'
    }

    Process {
        foreach ($CurrentPath in $Path) {
            try {
                $FileInfo = Get-Item -Path $CurrentPath -ErrorAction Stop
                if ($FileInfo -isnot [System.IO.FileInfo]) { continue }

                Write-Verbose "[$($MyInvocation.InvocationName)] Scanning: $($FileInfo.Name)"
                
                $Content = [System.IO.File]::ReadAllText($FileInfo.FullName)
                $FoundDates = [System.Collections.Generic.List[datetime]]::new()

                # Try ISO 8601 first (highest confidence)
                $IsoMatches = [regex]::Matches($Content, $IsoPattern)
                foreach ($Match in $IsoMatches) {
                    $Year  = [int]$Match.Groups['year'].Value
                    $Month = [int]$Match.Groups['month'].Value
                    $Day   = [int]$Match.Groups['day'].Value

                    # Sanity check: valid month/day ranges
                    if ($Month -lt 1 -or $Month -gt 12) { continue }
                    if ($Day -lt 1 -or $Day -gt 31) { continue }
                    if ($Year -lt 2000 -or $Year -gt 2100) { continue }

                    try {
                        $ParsedDate = [datetime]::new($Year, $Month, $Day)
                        $FoundDates.Add($ParsedDate)
                    }
                    catch {
                        Write-Verbose "Invalid ISO date: $Year-$Month-$Day"
                    }
                }

                # If no ISO dates found, try U.S. formats
                if ($FoundDates.Count -eq 0) {
                    $UsMatches = [regex]::Matches($Content, $UsPattern)
                    foreach ($Match in $UsMatches) {
                        $Year  = [int]$Match.Groups['year'].Value
                        $Month = [int]$Match.Groups['month'].Value
                        $Day   = [int]$Match.Groups['day'].Value

                        if ($Month -lt 1 -or $Month -gt 12) { continue }
                        if ($Day -lt 1 -or $Day -gt 31) { continue }

                        try {
                            $ParsedDate = [datetime]::new($Year, $Month, $Day)
                            $FoundDates.Add($ParsedDate)
                        }
                        catch {
                            Write-Verbose "Invalid U.S. date: $Month/$Day/$Year"
                        }
                    }

                    $UsShortMatches = [regex]::Matches($Content, $UsShortPattern)
                    foreach ($Match in $UsShortMatches) {
                        $Year  = [int]$Match.Groups['year'].Value + 2000
                        $Month = [int]$Match.Groups['month'].Value
                        $Day   = [int]$Match.Groups['day'].Value

                        if ($Month -lt 1 -or $Month -gt 12) { continue }
                        if ($Day -lt 1 -or $Day -gt 31) { continue }
                        if ($Year -lt 2000 -or $Year -gt 2100) { continue }

                        try {
                            $ParsedDate = [datetime]::new($Year, $Month, $Day)
                            $FoundDates.Add($ParsedDate)
                        }
                        catch {
                            Write-Verbose "Invalid U.S. short date: $Month/$Day/$Year"
                        }
                    }
                }

                if ($FoundDates.Count -eq 0) {
                    Write-Warning "No valid dates found in: $($FileInfo.Name)"
                    continue
                }

                # Calculate Range
                $Sorted = $FoundDates | Sort-Object -Unique
                $Earliest = $Sorted[0].ToString($DateFormat)
                $Latest   = $Sorted[-1].ToString($DateFormat)

                $DateString = if ($Earliest -eq $Latest) { $Earliest } else { "$Earliest`_$Latest" }
                
                # Check if already renamed
                if ($FileInfo.BaseName -like "*_$DateString") {
                    Write-Verbose "File '$($FileInfo.Name)' already contains the correct date range."
                    continue
                }

                $NewName = "$($FileInfo.BaseName)_$DateString$($FileInfo.Extension)"
                
                if ($PSCmdlet.ShouldProcess($FileInfo.FullName, "Rename to $NewName")) {
                    Rename-Item -Path $FileInfo.FullName -NewName $NewName -ErrorAction Stop
                }
            }
            catch {
                $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new(
                    $_.Exception, "FileProcessError", [System.Management.Automation.ErrorCategory]::InvalidOperation, $CurrentPath
                ))
            }
        }
    }
}