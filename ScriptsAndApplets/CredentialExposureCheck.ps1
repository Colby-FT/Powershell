#Requires -Version 5.1

<#
.SYNOPSIS
    Credential Exposure Check - Malicious Code Execution Response.

.DESCRIPTION
    Read-only reconnaissance script for incident response on an isolated endpoint
    suspected of credential-stealer malware. Enumerates common credential stores
    and reports which ones contain data, including the actual account URLs, usernames,
    and service domains where extractable.

    Uses System.Data.SQLite (.NET provider) when available for proper SQLite parsing,
    with a regex-based fallback that extracts URLs/usernames from raw bytes. Neither
    method decrypts passwords or cookie values — only plaintext metadata is read.

    Output:
      - Console: Human-readable, color-coded summary via Write-Host.
      - File: Summary written to a .txt file automatically.

.PARAMETER Quiet
    Suppresses console output. The summary is still written to the .txt file.

.PARAMETER EnableLogging
    Enables file-based logging to $script:Config.LogPath.

.PARAMETER OutputPath
    Path for the summary .txt file. Defaults to a timestamped file in the script directory.

.EXAMPLE
    .\CredentialExposureCheck.ps1
    .\CredentialExposureCheck.ps1 -Quiet
    .\CredentialExposureCheck.ps1 -OutputPath "C:\Reports\findings.txt"
    .\CredentialExposureCheck.ps1 -EnableLogging -Verbose

.NOTES
    Author: ColbyC
    Version: 4.5
    Created: 2026-08-04
#>

[CmdletBinding()]
param (
    [Parameter()]
    [switch]$Quiet,

    [Parameter()]
    [switch]$EnableLogging,

    [Parameter()]
    [string]$OutputPath
)

#####################
#region Variables
#####################

$script:Config = [ordered]@{
    LogPath       = "$PSScriptRoot\Logs"
    EnableLogging = $EnableLogging.IsPresent
}

$script:Findings = [System.Collections.Generic.List[pscustomobject]]::new()
$script:TempDir  = Join-Path $env:TEMP "CredCheck_$(Get-Random)"

# Default output file: timestamped txt in the script directory
if (-not $OutputPath) {
    $TimeStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $OutputPath = "$PSScriptRoot\CredentialExposureCheck_${TimeStamp}_$($env:COMPUTERNAME)_$($env:USERNAME).txt"
}
$script:OutputPath = $OutputPath

# Buffer for the summary text that goes to the .txt file
$script:SummaryText = [System.Collections.Generic.List[string]]::new()

#endregion Variables

#####################
#region Functions
#####################

function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,

        [Parameter(Position = 1)]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry  = "[$Timestamp] [$Level] $Message"

    switch ($Level) {
        'Warning' { Write-Warning $Message }
        'Error'   { Write-Error $Message }
        default   { Write-Verbose $Message }
    }

    if ($script:Config.EnableLogging -and $script:Config.LogPath) {
        if (-not (Test-Path -Path $script:Config.LogPath)) {
            New-Item -ItemType Directory -Path $script:Config.LogPath -Force | Out-Null
        }
        $LogEntry | Out-File -FilePath "$($script:Config.LogPath)\CredentialExposureCheck.log" -Append
    }
}

function Write-Check {
    <#
    .SYNOPSIS
        Writes to console only when -Quiet is not set. Wrapper for Write-Host.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Message,

        [Parameter()]
        [System.ConsoleColor]$ForegroundColor = [System.ConsoleColor]::Gray,

        [Parameter()]
        [switch]$NoNewline
    )

    if (-not $Quiet) {
        if ($NoNewline) {
            Write-Host $Message -ForegroundColor $ForegroundColor -NoNewline
        } else {
            Write-Host $Message -ForegroundColor $ForegroundColor
        }
    }
}

function Write-Summary {
    <#
    .SYNOPSIS
        Writes a line to both the console (via Write-Check) and the summary text buffer.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Message,

        [Parameter()]
        [System.ConsoleColor]$ForegroundColor = [System.ConsoleColor]::Gray
    )

    Write-Check -Message $Message -ForegroundColor $ForegroundColor
    $script:SummaryText.Add($Message)
}

function Get-CleanAccount {
    <#
    .SYNOPSIS
        Cleans and normalizes a single account/service string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Account
    )

    $Clean = $Account.Trim()

    # Strip "(email) " prefix
    $Clean = $Clean -replace '^\(email\)\s*', ''

    # Strip doubled URLs: "https://x.com/https://x.com/" -> "https://x.com/"
    $Clean = $Clean -replace '^(https?://[^|]+?)\1+', '$1'

    # Also handle the "URL | username" format where URL is doubled
    if ($Clean -match '^(https?://[^\s|]+)(https?://.+)(\s\|\s.+)$') {
        $Clean = $Matches[1] + $Matches[3]
    }

    # Strip trailing garbage from cookie domains.
    # Only strip if the string is NOT a URL and NOT a Credential Manager target,
    # AND the trailing text looks like a cookie name (starts with lowercase letter
    # and is at least 2 chars to avoid stripping a single TLD character).
    if ($Clean -notmatch '^(https?://|Domain:|LegacyGeneric:|MicrosoftAccount:|WindowsLive:|TERMSRV)') {
        if ($Clean -match '^(\.??[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}(?:\.[a-zA-Z]{2,})?)([a-z][a-zA-Z0-9]+)$') {
            $DomainPart = $Matches[1]
            $Rest = $Matches[2]
            # Only strip if the "rest" is at least 2 characters (a cookie name)
            if ($Rest.Length -ge 2) {
                $Clean = $DomainPart
            }
        }
    }

    return $Clean
}

function Add-Finding {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Category,

        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter()]
        [string]$Store,

        [Parameter()]
        [string]$Profile,

        [Parameter(Mandatory)]
        [ValidateSet('Found', 'NotFound', 'Error')]
        [string]$Status,

        [Parameter()]
        [string]$Note,

        [Parameter()]
        [string[]]$Accounts
    )

    # Clean and deduplicate accounts
    $CleanAccounts = @()
    if ($Accounts) {
        $CleanAccounts = @($Accounts | ForEach-Object { Get-CleanAccount -Account $_ } | Where-Object {
            $_ -and
            $_.Trim() -ne '' -and
            $_ -notmatch '<BLOB' -and
            $_ -notmatch 'sqlite_' -and
            $_ -notmatch 'CREATE TABLE' -and
            $_ -notmatch 'CREATE INDEX' -and
            $_ -notmatch 'foreign_key' -and
            $_ -notmatch '^\s*NDEX' -and
            $_ -notmatch '^\s*TABLE' -and
            $_ -notmatch '^\s*ate_time' -and
            $_ -notmatch '^\s*R,' -and
            $_ -notmatch 'passwordhttps' -and
            $_ -notmatch 'passwordv\d' -and
            $_.Length -lt 200
        } | Sort-Object -Unique)
    }

    $AccountsStr = if ($CleanAccounts.Count -gt 0) { $CleanAccounts -join "`n" } else { '' }

    $Record = [pscustomobject]@{
        Category  = $Category
        Source    = $Source
        Store     = $Store
        Profile   = $Profile
        Status    = $Status
        Note      = $Note
        Accounts  = $AccountsStr
        Host      = $env:COMPUTERNAME
        User      = $env:USERNAME
        CheckedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }

    $script:Findings.Add($Record)
}

function Get-SqliteProvider {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $null = [System.Reflection.Assembly]::LoadWithPartialName('System.Data.SQLite')
        $null = [System.Data.SQLite.SQLiteConnection]
        return $true
    }
    catch {
        try {
            Add-Type -AssemblyName 'System.Data.SQLite' -ErrorAction Stop
            return $true
        } catch {
            return $false
        }
    }
}

function Read-SqliteViaProvider {
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string]$Query
    )

    $Rows = [System.Collections.Generic.List[array]]::new()

    try {
        $ConnectionString = "Data Source=$FilePath;Version=3;Read Only=True;"
        $Conn = New-Object System.Data.SQLite.SQLiteConnection($ConnectionString)
        $Conn.Open()

        $Cmd = $Conn.CreateCommand()
        $Cmd.CommandText = $Query

        $Reader = $Cmd.ExecuteReader()
        while ($Reader.Read()) {
            $Row = @()
            for ($i = 0; $i -lt $Reader.FieldCount; $i++) {
                $Row += $Reader.GetValue($i)
            }
            $Rows.Add($Row)
        }

        $Reader.Close()
        $Conn.Close()
    }
    catch {
        Write-Log -Message "[Read-SqliteViaProvider] Error: $_" -Level Warning
    }

    return @($Rows)
}

function Read-SqliteViaRegex {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [ValidateSet('Logins', 'Cookies')]
        [string]$Mode
    )

    $Results = @()

    try {
        $Bytes = [System.IO.File]::ReadAllBytes($FilePath)
        $Text = [System.Text.Encoding]::UTF8.GetString($Bytes)

        if ($Mode -eq 'Logins') {
            $UrlMatches = [regex]::Matches($Text, 'https?://[a-zA-Z0-9\-._~:/?#\[\]@!$&''()*+,;=%]+')
            $Urls = @($UrlMatches | ForEach-Object { $_.Value } | Sort-Object -Unique)

            $EmailMatches = [regex]::Matches($Text, '[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}')
            $Emails = @($EmailMatches | ForEach-Object { $_.Value } | Sort-Object -Unique)

            foreach ($Url in $Urls) {
                $Results += "$Url"
            }
            foreach ($Email in $Emails) {
                if ($Email -notmatch 'sqlite|schema|index|w3\.org|password') {
                    $Results += "(email) $Email"
                }
            }
        }
        elseif ($Mode -eq 'Cookies') {
            $DomainMatches = [regex]::Matches($Text, '(?:^|[^\w])(\.{0,2}(?:[a-zA-Z0-9\-]+\.)+[a-zA-Z]{2,})(?:[^\w]|$)')
            $Domains = @($DomainMatches | ForEach-Object {
                $m = $_.Value.Trim()
                $m = $m -replace '^[^\w]+', '' -replace '[^\w]+$', ''
                $m
            } | Where-Object {
                $_ -and
                $_ -notmatch 'sqlite|schema|w3\.org|xmlns' -and
                $_ -notmatch '^\.' -and
                $_.Length -lt 60
            } | Sort-Object -Unique)

            $Results += $Domains
        }
    }
    catch {
        Write-Log -Message "[Read-SqliteViaRegex] Error reading $FilePath : $_" -Level Warning
    }

    return $Results
}

function Get-ChromiumLogins {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    $Results = @()

    if (-not (Test-Path -Path $FilePath)) { return @() }

    try {
        if (-not (Test-Path -Path $script:TempDir)) {
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
        }
        $TempFile = Join-Path $script:TempDir "LoginData_$(Get-Random).db"
        Copy-Item -Path $FilePath -Destination $TempFile -Force -ErrorAction Stop

        $HasProvider = Get-SqliteProvider

        if ($HasProvider) {
            $Rows = Read-SqliteViaProvider -FilePath $TempFile `
                -Query "SELECT origin_url, username_value FROM logins WHERE origin_url IS NOT NULL AND origin_url != ''"

            foreach ($Row in $Rows) {
                $Url = $Row[0]
                $Username = $Row[1]
                if ($Url -and $Url -ne '') {
                    $DisplayUser = if ($Username) { $Username } else { '(no username saved)' }
                    $Results += "$Url | $DisplayUser"
                }
            }
        } else {
            $Results = Read-SqliteViaRegex -FilePath $TempFile -Mode 'Logins'
        }

        Remove-Item -Path $TempFile -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Log -Message "[Get-ChromiumLogins] Error reading $FilePath : $_" -Level Warning
    }

    return $Results
}

function Get-ChromiumCookies {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    $Results = @()

    if (-not (Test-Path -Path $FilePath)) { return @() }

    try {
        if (-not (Test-Path -Path $script:TempDir)) {
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
        }
        $TempFile = Join-Path $script:TempDir "Cookies_$(Get-Random).db"
        Copy-Item -Path $FilePath -Destination $TempFile -Force -ErrorAction Stop

        $HasProvider = Get-SqliteProvider

        if ($HasProvider) {
            $Rows = Read-SqliteViaProvider -FilePath $TempFile `
                -Query "SELECT DISTINCT host_key FROM cookies WHERE host_key IS NOT NULL AND host_key != ''"

            foreach ($Row in $Rows) {
                $CookieHost = $Row[0]
                if ($CookieHost -and $CookieHost -ne '') {
                    $Results += $CookieHost
                }
            }
        } else {
            $Results = Read-SqliteViaRegex -FilePath $TempFile -Mode 'Cookies'
        }

        Remove-Item -Path $TempFile -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Log -Message "[Get-ChromiumCookies] Error reading $FilePath : $_" -Level Warning
    }

    return ($Results | Sort-Object -Unique)
}

function Get-FirefoxLogins {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    $Results = @()

    if (-not (Test-Path -Path $FilePath)) { return @() }

    try {
        $Content = Get-Content -Path $FilePath -Raw -ErrorAction Stop
        $Json = $Content | ConvertFrom-Json -ErrorAction Stop

        if ($Json.logins) {
            foreach ($Login in $Json.logins) {
                if ($Login.hostname) {
                    $Results += $Login.hostname
                }
            }
        }
    }
    catch {
        Write-Log -Message "[Get-FirefoxLogins] Error reading $FilePath : $_" -Level Warning
    }

    return $Results
}

function Get-BrowserCreds {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Browser,

        [Parameter(Mandatory)]
        [string]$ProfilePath,

        [Parameter(Mandatory)]
        [string[]]$LoginFiles,

        [Parameter(Mandatory)]
        [string[]]$CookieFiles
    )

    Write-Log -Message "[$Browser] Checking $ProfilePath" -Level Info
    Write-Check "--- $Browser ---" -ForegroundColor Yellow

    if (-not (Test-Path -Path $ProfilePath)) {
        Write-Check "  [Not Installed / No Profile Found]"
        Write-Check ""
        Add-Finding -Category 'Browser' -Source $Browser -Status 'NotFound' `
            -Note 'Browser not installed or no User Data directory found.'
        return
    }

    $ProfileDirs = @((Join-Path $ProfilePath 'Default'))
    $ExtraProfiles = @(Get-ChildItem -Path $ProfilePath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'Profile *' })
    foreach ($ep in $ExtraProfiles) {
        $ProfileDirs += $ep.FullName
    }

    $AnyFound = $false

    foreach ($ProfDir in $ProfileDirs) {
        if (-not (Test-Path -Path $ProfDir)) { continue }
        $ProfName = (Split-Path -Path $ProfDir -Leaf)

        foreach ($lf in $LoginFiles) {
            $full = Join-Path $ProfDir $lf
            if (Test-Path -Path $full) {
                $Accounts = @(Get-ChromiumLogins -FilePath $full)

                if ($Accounts.Count -gt 0) {
                    $AnyFound = $true
                    Write-Check "  [Saved Logins Found] Profile: $ProfName -> $lf"
                    Write-Check "    Saved accounts ($($Accounts.Count) entries):"
                    foreach ($acct in $Accounts) {
                        Write-Check "      $acct"
                    }
                    Write-Check "    NOTE: Passwords are encrypted on disk but stealer malware decrypts them"
                    Write-Check "    using the user's OS profile key. Treat ALL saved logins as compromised."
                    Add-Finding -Category 'Browser' -Source $Browser -Store $lf `
                        -Profile $ProfName -Status 'Found' `
                        -Note 'Saved logins present; treat as compromised. Stealer malware can decrypt.' `
                        -Accounts $Accounts
                }
            }
        }

        foreach ($cf in $CookieFiles) {
            $full = Join-Path $ProfDir $cf
            if (Test-Path -Path $full) {
                $Domains = @(Get-ChromiumCookies -FilePath $full)

                if ($Domains.Count -gt 0) {
                    $AnyFound = $true
                    Write-Check "  [Session Cookies Found] Profile: $ProfName -> $cf"
                    Write-Check "    Sites with active session cookies ($($Domains.Count) domains):"
                    foreach ($dom in $Domains) {
                        Write-Check "      $dom"
                    }
                    Write-Check "    NOTE: Session cookies allow MFA bypass. Treat all logged-in SSO/M365"
                    Write-Check "    sessions as potentially hijacked."
                    Add-Finding -Category 'Browser' -Source $Browser -Store $cf `
                        -Profile $ProfName -Status 'Found' `
                        -Note 'Session cookies present; MFA bypass risk. Treat SSO/M365 sessions as hijacked.' `
                        -Accounts $Domains
                }
            }
        }
    }

    if (-not $AnyFound) {
        Write-Check "  [Installed - No credential stores found in any profile]"
        Add-Finding -Category 'Browser' -Source $Browser -Status 'NotFound' `
            -Note 'Browser installed but no login data or cookies found in any profile.'
    }

    Write-Check ""
}

#endregion Functions

#####################
#region Header
#####################

Write-Check ""
Write-Check "============================================================" -ForegroundColor Cyan
Write-Check " CREDENTIAL EXPOSURE CHECK" -ForegroundColor Cyan
Write-Check " Run time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')" -ForegroundColor Cyan
Write-Check " Host: $env:COMPUTERNAME  | User: $env:USERNAME" -ForegroundColor Cyan
Write-Check "============================================================" -ForegroundColor Cyan
Write-Check ""

Write-Log -Message "[$($MyInvocation.MyCommand.Name)] Script started." -Level Info

if (-not (Test-Path -Path $script:TempDir)) {
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
}

#endregion Header

#####################
#region Edge
#####################

$edgeBase = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
Get-BrowserCreds -Browser "Microsoft Edge" -ProfilePath $edgeBase `
    -LoginFiles @("Login Data", "Login Data For Account") `
    -CookieFiles @("Cookies", "Network\Cookies")

#endregion Edge

#####################
#region Chrome
#####################

$chromeBase = "$env:LOCALAPPDATA\Google\Chrome\User Data"
Get-BrowserCreds -Browser "Google Chrome" -ProfilePath $chromeBase `
    -LoginFiles @("Login Data", "Login Data For Account") `
    -CookieFiles @("Cookies", "Network\Cookies")

#endregion Chrome

#####################
#region Brave
#####################

$braveBase = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
Get-BrowserCreds -Browser "Brave" -ProfilePath $braveBase `
    -LoginFiles @("Login Data", "Login Data For Account") `
    -CookieFiles @("Cookies", "Network\Cookies")

#endregion Brave

#####################
#region Firefox
#####################

Write-Check "--- Mozilla Firefox ---" -ForegroundColor Yellow
Write-Log -Message "[Firefox] Checking profiles" -Level Info

$ffRoot = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path -Path $ffRoot) {
    $ffProfiles = @(Get-ChildItem -Path $ffRoot -Directory -ErrorAction SilentlyContinue)
    $ffFound = $false

    foreach ($p in $ffProfiles) {
        $loginData = Join-Path $p.FullName "logins.json"
        $cookies   = Join-Path $p.FullName "cookies.sqlite"
        $key4      = Join-Path $p.FullName "key4.db"

        if (Test-Path -Path $loginData) {
            $ffAccounts = @(Get-FirefoxLogins -FilePath $loginData)

            if ($ffAccounts.Count -gt 0) {
                $ffFound = $true
                Write-Check "  [Saved Logins Found] Profile: $($p.Name) -> logins.json"
                Write-Check "    Saved accounts ($($ffAccounts.Count) entries):"
                foreach ($acct in $ffAccounts) {
                    Write-Check "      $acct"
                }
                if (Test-Path -Path $key4) {
                    Write-Check "    (key4.db also present - encryption key database)"
                }
                Write-Check "    NOTE: Firefox saved logins are encrypted but decryptable by stealer malware."
                Add-Finding -Category 'Browser' -Source 'Mozilla Firefox' -Store 'logins.json' `
                    -Profile $p.Name -Status 'Found' `
                    -Note 'Firefox saved logins present; decryptable by stealer malware.' `
                    -Accounts $ffAccounts
            }
        } elseif (Test-Path -Path $key4) {
            Write-Check "  [Key DB Present] Profile: $($p.Name) -> key4.db (no logins.json)"
            Write-Check "    NOTE: Key database exists but no saved logins file. Low risk."
            Add-Finding -Category 'Browser' -Source 'Mozilla Firefox' -Store 'key4.db' `
                -Profile $p.Name -Status 'Found' `
                -Note 'Key database present without logins.json. Informational; low risk.'
        }

        if (Test-Path -Path $cookies) {
            $ffCookieDomains = @(Get-ChromiumCookies -FilePath $cookies)
            if ($ffCookieDomains.Count -gt 0) {
                $ffFound = $true
                Write-Check "  [Session Cookies Found] Profile: $($p.Name) -> cookies.sqlite"
                Write-Check "    Sites with active session cookies ($($ffCookieDomains.Count) domains):"
                foreach ($dom in $ffCookieDomains) {
                    Write-Check "      $dom"
                }
                Add-Finding -Category 'Browser' -Source 'Mozilla Firefox' -Store 'cookies.sqlite' `
                    -Profile $p.Name -Status 'Found' `
                    -Note 'Firefox session cookies present; MFA bypass risk.' `
                    -Accounts $ffCookieDomains
            }
        }
    }

    if (-not $ffFound) {
        Write-Check "  [Installed - No credential stores found in any profile]"
        Add-Finding -Category 'Browser' -Source 'Mozilla Firefox' -Status 'NotFound' `
            -Note 'Firefox installed but no logins.json, key4.db, or cookies.sqlite found.'
    }
} else {
    Write-Check "  [Not Installed / No Profile Found]"
    Add-Finding -Category 'Browser' -Source 'Mozilla Firefox' -Status 'NotFound' `
        -Note 'Firefox not installed or no profiles directory found.'
}
Write-Check ""

#endregion Firefox

#####################
#region CredentialManager
#####################

Write-Check "--- Windows Credential Manager ---" -ForegroundColor Yellow
Write-Log -Message "[CredentialManager] Enumerating vault" -Level Info

$vaultCreds = & cmdkey /list 2>&1 | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }

if ($vaultCreds) {
    $targetLines = @($vaultCreds | Where-Object { $_ -match 'Target:' } |
        ForEach-Object { ($_ -replace '^\s*Target:\s*', '').Trim() })

    if ($targetLines.Count -gt 0) {
        Write-Check "  [Stored Credentials Found] Count: $($targetLines.Count)"
        Write-Check "  Credential targets:"
        foreach ($t in $targetLines) {
            Write-Check "    $t"
        }
        Write-Check "    NOTE: Generic and domain credentials stored here are grabbed by most stealers."
        Add-Finding -Category 'CredentialManager' -Source 'Windows Credential Manager' -Store 'Vault' `
            -Status 'Found' `
            -Note "$($targetLines.Count) stored credentials found. Treat as exposed." `
            -Accounts $targetLines
    } else {
        Write-Check "  [No stored credentials]"
        Add-Finding -Category 'CredentialManager' -Source 'Windows Credential Manager' -Store 'Vault' `
            -Status 'NotFound' -Note 'No stored credentials in Credential Manager.'
    }
} else {
    Write-Check "  [Unable to enumerate / none found]"
    Add-Finding -Category 'CredentialManager' -Source 'Windows Credential Manager' -Store 'Vault' `
        -Status 'Error' -Note 'cmdkey returned no output; unable to enumerate.'
}
Write-Check ""

#endregion CredentialManager

#####################
#region WindowsVault
#####################

Write-Check "--- Windows Vault (Web Credentials) ---" -ForegroundColor Yellow
Write-Log -Message "[WindowsVault] Checking web credentials" -Level Info

$vaultPath = "$env:LOCALAPPDATA\Microsoft\Vault"
if (Test-Path -Path $vaultPath) {
    $vaultFiles = @(Get-ChildItem -Path $vaultPath -Recurse -File -ErrorAction SilentlyContinue)
    if ($vaultFiles.Count -gt 0) {
        Write-Check "  [Vault files present] Count: $($vaultFiles.Count)"
        Write-Check "    NOTE: Web credentials in the Vault are a known stealer target."
        Add-Finding -Category 'WindowsVault' -Source 'Windows Vault' -Store 'Vault' `
            -Status 'Found' `
            -Note "$($vaultFiles.Count) vault files present. Known stealer target."
    } else {
        Write-Check "  [No vault files]"
        Add-Finding -Category 'WindowsVault' -Source 'Windows Vault' -Store 'Vault' `
            -Status 'NotFound' -Note 'Vault directory exists but no files.'
    }
} else {
    Write-Check "  [No vault directory]"
    Add-Finding -Category 'WindowsVault' -Source 'Windows Vault' -Store 'Vault' `
        -Status 'NotFound' -Note 'No vault directory found.'
}
Write-Check ""

#endregion WindowsVault

#####################
#region WiFi
<#####################

Write-Check "--- Wi-Fi Profiles ---" -ForegroundColor Yellow
Write-Log -Message "[WiFi] Enumerating profiles" -Level Info

$wifi = & netsh wlan show profiles 2>&1 | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }

if ($wifi) {
    $profiles = @($wifi | Select-String -Pattern 'All User Profile\s+:\s+(.+)' |
        ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() })
    if ($profiles.Count -gt 0) {
        Write-Check "  [Wi-Fi Profiles Found] Count: $($profiles.Count)"
        foreach ($p in $profiles) {
            Write-Check "    $p"
        }
        Write-Check "    NOTE: This tool enumerated profile NAMES only (not passwords). However,"
        Write-Check "    stealer malware CAN extract the saved Wi-Fi passwords for these profiles."
        Write-Check "    Treat saved Wi-Fi credentials as exposed."
        Add-Finding -Category 'WiFi' -Source 'Wi-Fi Profiles' -Store 'Profiles' `
            -Status 'Found' `
            -Note "$($profiles.Count) Wi-Fi profiles found. Passwords extractable by malware." `
            -Accounts $profiles
    } else {
        Write-Check "  [No Wi-Fi profiles]"
        Add-Finding -Category 'WiFi' -Source 'Wi-Fi Profiles' -Store 'Profiles' `
            -Status 'NotFound' -Note 'No Wi-Fi profiles found.'
    }
} else {
    Write-Check "  [Unable to enumerate]"
    Add-Finding -Category 'WiFi' -Source 'Wi-Fi Profiles' -Store 'Profiles' `
        -Status 'Error' -Note 'netsh returned no output; unable to enumerate.'
}
Write-Check ""

#endregion WiFi
#>
#####################
#region SSHKeys
#####################

Write-Check "--- SSH Keys ---" -ForegroundColor Yellow
Write-Log -Message "[SSH] Checking ~/.ssh" -Level Info

$sshDir = "$env:USERPROFILE\.ssh"
if (Test-Path -Path $sshDir) {
    $keys = @(Get-ChildItem -Path $sshDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch 'known_hosts|authorized_keys|config' })
    if ($keys.Count -gt 0) {
        $keyNames = @($keys | ForEach-Object { $_.Name })
        Write-Check "  [SSH Keys Found] Count: $($keys.Count)"
        foreach ($k in $keyNames) {
            Write-Check "    $k"
        }
        Write-Check "    NOTE: Private keys are grabbed by stealer malware. Rotate any keys found."
        Add-Finding -Category 'SSH' -Source 'SSH Keys' -Store '.ssh' `
            -Status 'Found' `
            -Note "$($keys.Count) SSH key files found. Rotate all keys." `
            -Accounts $keyNames
    } else {
        Write-Check "  [No private keys in ~/.ssh]"
        Add-Finding -Category 'SSH' -Source 'SSH Keys' -Store '.ssh' `
            -Status 'NotFound' -Note 'No private key files found in ~/.ssh.'
    }
} else {
    Write-Check "  [No .ssh directory]"
    Add-Finding -Category 'SSH' -Source 'SSH Keys' -Store '.ssh' `
        -Status 'NotFound' -Note 'No .ssh directory found.'
}
Write-Check ""

#endregion SSHKeys

#####################
#region Git
#####################

Write-Check "--- Git Credential Stores ---" -ForegroundColor Yellow
Write-Log -Message "[Git] Checking credential stores" -Level Info

$gitCred = "$env:USERPROFILE\.git-credentials"
if (Test-Path -Path $gitCred) {
    $gitUrls = @()
    try {
        $gitContent = Get-Content -Path $gitCred -ErrorAction SilentlyContinue
        foreach ($line in $gitContent) {
            if ($line -match '^https?://') {
                $cleanUrl = $line -replace '://[^@]+@', '://'
                $gitUrls += $cleanUrl
            }
        }
    } catch {}

    Write-Check "  [.git-credentials file found] - plaintext credentials, treat as exposed"
    if ($gitUrls.Count -gt 0) {
        Write-Check "    Stored Git remotes:"
        foreach ($u in $gitUrls) {
            Write-Check "      $u"
        }
    }
    Add-Finding -Category 'Git' -Source 'Git Credentials' -Store '.git-credentials' `
        -Status 'Found' `
        -Note 'Plaintext git credentials file found. Treat as exposed.' `
        -Accounts $gitUrls
} else {
    Write-Check "  [No .git-credentials file]"
    Add-Finding -Category 'Git' -Source 'Git Credentials' -Store '.git-credentials' `
        -Status 'NotFound' -Note 'No .git-credentials file.'
}

$gitConfig = "$env:USERPROFILE\.gitconfig"
if (Test-Path -Path $gitConfig) {
    $gc = @(Get-Content -Path $gitConfig -ErrorAction SilentlyContinue)
    if ($gc -match 'credential') {
        Write-Check "  [.gitconfig has credential helper config] - review for stored tokens"
        Add-Finding -Category 'Git' -Source 'Git Config' -Store '.gitconfig' `
            -Status 'Found' `
            -Note 'Git credential helper configured. Review for stored tokens.'
    } else {
        Add-Finding -Category 'Git' -Source 'Git Config' -Store '.gitconfig' `
            -Status 'NotFound' -Note '.gitconfig present but no credential helper configured.'
    }
} else {
    Write-Check "  [No .gitconfig file]"
    Add-Finding -Category 'Git' -Source 'Git Config' -Store '.gitconfig' `
        -Status 'NotFound' -Note 'No .gitconfig file.'
}
Write-Check ""

#endregion Git

#####################
#region CloudCLI
#####################

Write-Check "--- Cloud CLI Tokens ---" -ForegroundColor Yellow
Write-Log -Message "[CloudCLI] Checking AWS and Azure tokens" -Level Info

$awsCred = "$env:USERPROFILE\.aws\credentials"
if (Test-Path -Path $awsCred) {
    $awsProfiles = @()
    try {
        $awsContent = Get-Content -Path $awsCred -ErrorAction SilentlyContinue
        foreach ($line in $awsContent) {
            if ($line -match '^\s*\[([^\]]+)\]') {
                $awsProfiles += $Matches[1]
            }
        }
    } catch {}

    Write-Check "  [AWS CLI credentials found] - $awsCred - treat access keys as exposed"
    if ($awsProfiles.Count -gt 0) {
        Write-Check "    AWS profiles:"
        foreach ($p in $awsProfiles) {
            Write-Check "      $p"
        }
    }
    Add-Finding -Category 'CloudCLI' -Source 'AWS CLI' -Store 'credentials' `
        -Status 'Found' `
        -Note 'AWS CLI credentials file found. Treat access keys as exposed.' `
        -Accounts $awsProfiles
} else {
    Write-Check "  [No AWS CLI credentials]"
    Add-Finding -Category 'CloudCLI' -Source 'AWS CLI' -Store 'credentials' `
        -Status 'NotFound' -Note 'No AWS CLI credentials file.'
}

$azureToken = "$env:USERPROFILE\.azure\accessTokens.json"
if (Test-Path -Path $azureToken) {
    $azureAccounts = @()
    try {
        $azureJson = Get-Content -Path $azureToken -Raw -ErrorAction SilentlyContinue |
            ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($azureJson) {
            foreach ($token in $azureJson) {
                $userInfo = @()
                if ($token.userId) { $userInfo += "User: $($token.userId)" }
                if ($token.user) { $userInfo += "User: $($token.user)" }
                if ($token.tenant) { $userInfo += "Tenant: $($token.tenant)" }
                if ($token.resource) { $userInfo += "Resource: $($token.resource)" }
                if ($userInfo.Count -gt 0) {
                    $azureAccounts += ($userInfo -join ' | ')
                }
            }
        }
    } catch {}

    Write-Check "  [Azure CLI tokens found] - $azureToken - treat as exposed"
    if ($azureAccounts.Count -gt 0) {
        Write-Check "    Azure token entries:"
        foreach ($a in $azureAccounts) {
            Write-Check "      $a"
        }
    }
    Add-Finding -Category 'CloudCLI' -Source 'Azure CLI' -Store 'accessTokens.json' `
        -Status 'Found' `
        -Note 'Azure CLI tokens found. Treat as exposed.' `
        -Accounts $azureAccounts
} else {
    Write-Check "  [No Azure CLI tokens]"
    Add-Finding -Category 'CloudCLI' -Source 'Azure CLI' -Store 'accessTokens.json' `
        -Status 'NotFound' -Note 'No Azure CLI tokens file.'
}
Write-Check ""

#endregion CloudCLI

#####################
#region Summary
#####################

# Build the summary text (goes to both console and .txt file)
Write-Summary ""
Write-Summary "============================================================" -ForegroundColor Cyan
Write-Summary " SUMMARY" -ForegroundColor Cyan
Write-Summary " The following is a summary of the items found in locations that are commonly exfiltrated." -ForegroundColor Green
Write-Summary " This list is intended for the user to help determine any other accounts the user should secure." -ForegroundColor Green
Write-Summary "============================================================" -ForegroundColor Cyan

$FoundCount    = ($script:Findings | Where-Object { $_.Status -eq 'Found' }).Count
$NotFoundCount = ($script:Findings | Where-Object { $_.Status -eq 'NotFound' }).Count
$ErrorCount    = ($script:Findings | Where-Object { $_.Status -eq 'Error' }).Count

<#Write-Summary " Findings: $FoundCount found | $NotFoundCount not found | $ErrorCount errors"#>
Write-Summary ""

# --- EXPOSED (Found) ---
$ExposedFindings = $script:Findings | Where-Object { $_.Status -eq 'Found' }

if ($ExposedFindings) {
    Write-Summary "POTENTIALLY EXPOSED CREDENTIALS:" -ForegroundColor Red
    Write-Summary " ------------------------------------------------------------"
    foreach ($f in $ExposedFindings) {
        $Label = $f.Source
        if ($f.Store) { $Label += " - $($f.Store)" }

        $acctLines = @()
        if ($f.Accounts -ne '') {
            $acctLines = @($f.Accounts -split "`n" | Where-Object { $_.Trim() -ne '' })
        }

        if ($acctLines.Count -gt 0) {
            Write-Summary " $Label" -ForegroundColor Yellow
            foreach ($line in $acctLines) {
                Write-Summary "   $line"
            }
            Write-Summary ""
        } else {
            Write-Summary " $Label - $($f.Note)" -ForegroundColor Yellow
            Write-Summary ""
        }
    }
}

<# --- CLEAN (NotFound) ---
$CleanFindings = $script:Findings | Where-Object { $_.Status -eq 'NotFound' }
if ($CleanFindings) {
    Write-Summary " CLEAN - No exposure found:" -ForegroundColor Green
    Write-Summary " ------------------------------------------------------------"
    $cleanList = @($CleanFindings | ForEach-Object { $_.Source })
    Write-Summary "   $($cleanList -join ', ')"
    Write-Summary ""
}
#>
Write-Summary "============================================================" -ForegroundColor Cyan

Write-Log -Message "[$($MyInvocation.MyCommand.Name)] Script completed. Found=$FoundCount NotFound=$NotFoundCount Errors=$ErrorCount" -Level Info

# Cleanup temp directory
if (Test-Path -Path $script:TempDir) {
    Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Write the summary to the .txt file
try {
    $OutputDir = Split-Path -Path $script:OutputPath -Parent
    if ($OutputDir -and -not (Test-Path -Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    $script:SummaryText | Out-File -FilePath $script:OutputPath -Encoding UTF8
    Write-Check ""
    Write-Check " Summary written to: $script:OutputPath" -ForegroundColor Green
}
catch {
    Write-Check ""
    Write-Check " ERROR: Failed to write summary to $script:OutputPath : $_" -ForegroundColor Red
}

#endregion Summary

# End of script