<#
.SYNOPSIS
    Collects browser history (Edge, Chrome, Firefox) for all local user profiles using built-in Windows SQLite.

.DESCRIPTION
    Uses winsqlite3.dll (native to Win10/11) to query browser history without external dependencies.
    Scans all local users and all browser profiles.
#>
[CmdletBinding()]
param(
    [string]$OutputPath = "C:\FT\BrowserHistory"
)

# 1. Setup P/Invoke for winsqlite3.dll
$signature = @"
[DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
public static extern int sqlite3_open([MarshalAs(UnmanagedType.LPStr)] string filename, out IntPtr db);

[DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
public static extern int sqlite3_prepare_v2(IntPtr db, [MarshalAs(UnmanagedType.LPStr)] string sql, int numBytes, out IntPtr stmt, IntPtr tail);

[DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
public static extern int sqlite3_step(IntPtr stmt);

[DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
public static extern IntPtr sqlite3_column_text(IntPtr stmt, int index);

[DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
public static extern int sqlite3_finalize(IntPtr stmt);

[DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
public static extern int sqlite3_close(IntPtr db);

[DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
public static extern int sqlite3_column_count(IntPtr stmt);

[DllImport("winsqlite3.dll", CallingConvention = CallingConvention.Cdecl)]
public static extern IntPtr sqlite3_column_name(IntPtr stmt, int index);
"@

if (-not ([System.Management.Automation.PSTypeName]'WinSQLite').Type) {
    Add-Type -MemberDefinition $signature -Name WinSQLite -Namespace WinAPI
}

# 2. Helper function to query SQLite using P/Invoke
function Get-SqliteData {
    param([string]$dbPath, [string]$query)
    
    $db = [IntPtr]::Zero
    if ([WinAPI.WinSQLite]::sqlite3_open($dbPath, [ref]$db) -ne 0) { return $null }

    $stmt = [IntPtr]::Zero
    if ([WinAPI.WinSQLite]::sqlite3_prepare_v2($db, $query, -1, [ref]$stmt, [IntPtr]::Zero) -ne 0) {
        [void][WinAPI.WinSQLite]::sqlite3_close($db)
        return $null
    }

    $results = New-Object System.Collections.Generic.List[PSObject]
    while ([WinAPI.WinSQLite]::sqlite3_step($stmt) -eq 100) { # 100 = SQLITE_ROW
        $row = New-Object PSObject
        $colCount = [WinAPI.WinSQLite]::sqlite3_column_count($stmt)
        for ($i = 0; $i -lt $colCount; $i++) {
            $name = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi([WinAPI.WinSQLite]::sqlite3_column_name($stmt, $i))
            $valPtr = [WinAPI.WinSQLite]::sqlite3_column_text($stmt, $i)
            $val = if ($valPtr -eq [IntPtr]::Zero) { $null } else { [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($valPtr) }
            $row | Add-Member -MemberType NoteProperty -Name $name -Value $val
        }
        $results.Add($row)
    }

    [void][WinAPI.WinSQLite]::sqlite3_finalize($stmt)
    [void][WinAPI.WinSQLite]::sqlite3_close($db)
    return $results
}

# 3. Setup output environment
if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

$userProfiles = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notin @("Public", "Default", "All Users") }

foreach ($user in $userProfiles) {
    Write-Host "`n>>> Processing User: $($user.Name)" -ForegroundColor Cyan
    
    $searchPaths = @(
        @{ Name = "Chrome"; Path = "$($user.FullName)\AppData\Local\Google\Chrome\User Data"; File = "History"; Query = "SELECT url, title, datetime((last_visit_time/1000000)-11644473600, 'unixepoch') AS VisitTime FROM urls" },
        @{ Name = "Edge";   Path = "$($user.FullName)\AppData\Local\Microsoft\Edge\User Data"; File = "History"; Query = "SELECT url, title, datetime((last_visit_time/1000000)-11644473600, 'unixepoch') AS VisitTime FROM urls" },
        @{ Name = "Firefox"; Path = "$($user.FullName)\AppData\Roaming\Mozilla\Firefox\Profiles"; File = "places.sqlite"; Query = "SELECT moz_places.url, moz_places.title, datetime((moz_historyvisits.visit_date/1000000), 'unixepoch') AS VisitTime FROM moz_historyvisits INNER JOIN moz_places ON moz_historyvisits.place_id = moz_places.id" }
    )

    foreach ($app in $searchPaths) {
        if (-not (Test-Path $app.Path)) { continue }

        # Find all profile folders containing the history file
        $historyFiles = Get-ChildItem -Path $app.Path -Filter $app.File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike "*System Profile*" }

        foreach ($file in $historyFiles) {
            $profileName = $file.Directory.Name
            Write-Host "Found $($app.Name) profile: $profileName"
            
            $tempFile = Join-Path $env:TEMP "$($user.Name)_$($app.Name)_$($profileName)_$timestamp.db"
            try {
                Copy-Item -Path $file.FullName -Destination $tempFile -Force -ErrorAction Stop
                $data = Get-SqliteData -dbPath $tempFile -query $app.Query
                
                if ($data) {
                    $outFileName = "$($user.Name)_$($app.Name)_$($profileName)_$timestamp.csv"
                    $data | Export-Csv -Path (Join-Path $OutputPath $outFileName) -NoTypeInformation
                    Write-Host " - Exported $($data.Count) rows to $outFileName" -ForegroundColor Green
                }
            }
            catch {
                Write-Warning " - Failed to process $($file.FullName): $_"
            }
            finally {
                if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
            }
        }
    }
}

Write-Host "`nInvestigation complete. Files saved to $OutputPath" -ForegroundColor Yellow