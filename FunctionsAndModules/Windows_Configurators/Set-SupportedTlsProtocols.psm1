function Set-SupportedTlsProtocols {
    <#
    .SYNOPSIS
    Sets the SecurityProtocol property to all supported TLS/SSL protocols, similar to .NET 4.7+ auto-negotiation.

    .DESCRIPTION
    Iterates through a list of common SecurityProtocolType values and sets [Net.ServicePointManager]::SecurityProtocol to a bitwise combination of only those protocols supported by the current .NET runtime.

    .EXAMPLE
    Set-SupportedTlsProtocols
    #>
    [CmdletBinding()]
    param ()

    $values = @(3072, 12288, 768, 192, 48)
    $supportedProtocols = 0
    foreach ($value in $values) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], $value)
            $supportedProtocols = $supportedProtocols -bor $value
        } catch {
            Write-Verbose "Protocol $value is not supported."
        }
    }
    [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], $supportedProtocols)
}