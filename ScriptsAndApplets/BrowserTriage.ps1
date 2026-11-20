# Run elevated. Copies History/Downloads/Cookies DBs for Chrome, Edge, and Firefox
# for every user profile, preserving timestamps, into C:\Temp\BrowserCollection\<Computer>

$Cutoff   = Get-Date "2026-11-16 00:00:00"   # exposure window start (UTC in the alert; adjust to local if needed)
$DestRoot = "C:\FT\BrowserCollection\$env:COMPUTERNAME"
New-Item -ItemType Directory -Force -Path $DestRoot | Out-Null

$UserDirs = Get-ChildItem "C:\Users" -Directory | Where-Object { Test-Path "$($_.FullName)\AppData\Local" }

foreach ($User in $UserDirs) {
    $U = $User.FullName
    $L = "$U\AppData\Local"
    $R = "$U\AppData\Roaming"

    # --- Chromium-based: Chrome and Edge ---
    $Chromium = @(
        @{ Name = "Chrome"; Path = "$L\Google\Chrome\User Data" },
        @{ Name = "Edge";   Path = "$L\Microsoft\Edge\User Data" }
    )
    foreach ($B in $Chromium) {
        if (Test-Path $B.Path) {
            # Default profile plus any "Profile N" profiles
            $Profiles = Get-ChildItem $B.Path -Directory | Where-Object { $_.Name -eq "Default" -or $_.Name -like "Profile *" }
            foreach ($P in $Profiles) {
                foreach ($File in @("History", "Downloads", "Cookies", "Top Sites")) {
                    $Src = Join-Path $P.FullName $File
                    if (Test-Path $Src) {
                        $Sub = "$DestRoot\$($B.Name)\$($P.Name)"
                        New-Item -ItemType Directory -Force -Path $Sub | Out-Null
                        Copy-Item $Src "$Sub\$File" -Force
                    }
                }
            }
        }
    }

    # --- Firefox (places.sqlite = history, cookies.sqlite = cookies) ---
    if (Test-Path "$R\Mozilla\Firefox\Profiles") {
        $FFProfiles = Get-ChildItem "$R\Mozilla\Firefox\Profiles" -Directory
        foreach ($P in $FFProfiles) {
            foreach ($File in @("places.sqlite", "cookies.sqlite", "extensions.json", "addons.json")) {
                $Src = Join-Path $P.FullName $File
                if (Test-Path $Src) {
                    $Sub = "$DestRoot\Firefox\$($P.Name)"
                    New-Item -ItemType Directory -Force -Path $Sub | Out-Null
                    Copy-Item $Src "$Sub\$File" -Force
                }
            }
        }
    }
}

# Inventory what we collected, with timestamps
Get-ChildItem $DestRoot -Recurse -File |
    Select-Object FullName, Length, CreationTime, LastWriteTime |
    Format-Table -AutoSize | Out-File "$DestRoot\_collection_inventory.txt"
Write-Host "Collection complete: $DestRoot"




####Step 2
# Quick triage: pulls readable URL strings from the copied Chrome/Edge History files
# and Firefox places.sqlite. Writes results to _triage_urls.txt on the local machine.

$DestRoot = "C:\FT\BrowserCollection\$env:COMPUTERNAME"
$Out = "$DestRoot\_triage_urls.txt"

Get-ChildItem $DestRoot -Recurse -File -Include "History", "places.sqlite" | ForEach-Object {
    $DB = $_.FullName
    # Extract URL-like strings from the raw DB bytes
    $Bytes  = [System.IO.File]::ReadAllBytes($DB)
    $Text   = [System.Text.Encoding]::ASCII.GetString($Bytes)
    $Matches = [regex]::Matches($Text, 'https?://[\x20-\x7E]{5,200}')
    $Matches | ForEach-Object { $_.Value } | Sort-Object -Unique |
        ForEach-Object { "$DB`t$_" }
} | Sort-Object -Unique | Out-File $Out -Encoding utf8

Write-Host "Extracted URLs written to $Out"
# Then hunt for the affected-site visits and IOCs:
Select-String -Path $Out -Pattern "1688360|\.icu|track\.js"


#######Step 3
# Enumerates Chrome and Edge extensions across all profiles, flagging any whose
# folder was created or modified on/after 2026-11-16, and dumping their manifest details.
# Results print to console and are exported to _extensions.csv on the local machine.

$Cutoff = Get-Date "2026-11-16 00:00:00"
$Results = @()

$UserDirs = Get-ChildItem "C:\Users" -Directory | Where-Object { Test-Path "$($_.FullName)\AppData\Local" }

foreach ($User in $UserDirs) {
    $Browsers = @(
        @{ Name = "Chrome"; Path = "$($User.FullName)\AppData\Local\Google\Chrome\User Data" },
        @{ Name = "Edge";   Path = "$($User.FullName)\AppData\Local\Microsoft\Edge\User Data" }
    )
    foreach ($B in $Browsers) {
        if (-not (Test-Path $B.Path)) { continue }
        $Profiles = Get-ChildItem $B.Path -Directory | Where-Object { $_.Name -eq "Default" -or $_.Name -like "Profile *" }
        foreach ($P in $Profiles) {
            $ExtRoot = Join-Path $P.FullName "Extensions"
            if (-not (Test-Path $ExtRoot)) { continue }
            # Each extension lives in a folder named by ID, versioned subfolders inside
            Get-ChildItem $ExtRoot -Directory | ForEach-Object {
                $ExtID = $_.Name
                $Latest = Get-ChildItem $_.FullName -Recurse -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                $Manifest = Get-ChildItem $_.FullName -Recurse -Filter "manifest.json" | Select-Object -First 1
                $Name = $null; $Perms = $null
                if ($Manifest) {
                    try {
                        $JSON = Get-Content $Manifest.FullName -Raw | ConvertFrom-Json
                        $Name  = $JSON.name
                        $Perms = ($JSON.permissions + $JSON.host_permissions) -join ","
                    } catch {}
                }
                $Results += [PSCustomObject]@{
                    User        = $User.Name
                    Browser     = $B.Name
                    Profile     = $P.Name
                    ExtID       = $ExtID
                    Name        = $Name
                    Permissions = $Perms
                    FolderCreated = $_.CreationTime
                    LastModified = $Latest.LastWriteTime
                    NewOrModifiedSince16th = ($_.CreationTime -ge $Cutoff -or $Latest.LastWriteTime -ge $Cutoff)
                }
            }
        }
    }

    # --- Firefox: extensions.json / addons.json write times ---
    if (Test-Path "$($User.FullName)\AppData\Roaming\Mozilla\Firefox\Profiles") {
        Get-ChildItem "$($User.FullName)\AppData\Roaming\Mozilla\Firefox\Profiles" -Directory | ForEach-Object {
            foreach ($F in @("extensions.json", "addons.json")) {
                $File = Join-Path $_.FullName $F
                if ((Test-Path $File) -and (Get-Item $File).LastWriteTime -ge $Cutoff) {
                    $Results += [PSCustomObject]@{
                        User = $User.Name; Browser = "Firefox"; Profile = $_.Name
                        ExtID = "N/A"; Name = $F; Permissions = "N/A"
                        FolderCreated = (Get-Item $File).CreationTime
                        LastModified = (Get-Item $File).LastWriteTime
                        NewOrModifiedSince16th = $true
                    }
                }
            }
        }
    }
}

$Results | Sort-Object NewOrModifiedSince16th -Descending |
    Format-Table User, Browser, ExtID, Name, LastModified, NewOrModifiedSince16th -AutoSize

# Save full detail including permissions (review these — clipboard/content access is the red flag)
$Results | Export-Csv "C:\FT\BrowserCollection\$env:COMPUTERNAME\_extensions.csv" -NoTypeInformation