function Test-AppInstalled {
    param(
        [Parameter(Mandatory)]
        [string]$AppName
    )

    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    $found = $false

    foreach ($path in $paths) {
        $apps = Get-ChildItem $path -ErrorAction SilentlyContinue | ForEach-Object {
            Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
        }
        if ($apps | Where-Object { $_.DisplayName -like "*$AppName*" }) {
            $found = $true
            break
        }
    }

    return $found
}
