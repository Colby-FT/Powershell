function New-PlainTextCredential {
    <#
    .SYNOPSIS
    Creates a PSCredential object from plain text username and password.

    .DESCRIPTION
    Converts a plain text username and password into a secure PSCredential object
    for use with remote PowerShell commands.

    .PARAMETER Username
    The username for authentication.

    .PARAMETER Password
    The password for authentication.

    .EXAMPLE
    $cred = New-PlainTextCredential -Username "admin" -Password "P@ssw0rd"
    Invoke-Command -ComputerName "Server01" -Credential $cred -ScriptBlock { Get-Service }
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Username,

        [Parameter(Mandatory)]
        [string]$Password
    )

    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    return New-Object System.Management.Automation.PSCredential ($Username, $SecurePassword)
}