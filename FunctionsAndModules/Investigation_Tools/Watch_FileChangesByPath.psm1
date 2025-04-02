function Watch-FileChangesByPath {
    <#
    .SYNOPSIS
    Monitors and retrieves file changes in a specified directory, including subdirectories.

    .DESCRIPTION
    This function uses the .NET `System.IO.FileSystemWatcher` class to monitor a directory for changes. 
    It captures events such as file creation, modification, deletion, and renaming, and outputs these events to the console in real time.

    .PARAMETER Path
    The directory path to monitor. This must be a valid and accessible directory.

    .EXAMPLE
    Watch-FileChangesByPath -Path "C:\Temp"
    Monitors file changes in the C:\Temp directory and its subdirectories. Outputs events such as file creation, modification, deletion, and renaming.

    .EXAMPLE
    Watch-FileChangesByPath -Path "D:\Projects"
    Monitors file changes in the D:\Projects directory. Useful for tracking changes in project files during development.

    .NOTES
    - This function runs indefinitely until manually stopped (e.g., by pressing Ctrl+C).
    - Ensure you have appropriate permissions to access the specified directory.
    - The function cleans up registered events and disposes of the `FileSystemWatcher` object when stopped.

    .COMPONENT
    System.IO.FileSystemWatcher

    .LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.io.filesystemwatcher
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    begin {
        # Validate the directory exists
        if (-not (Test-Path -Path $Path)) {
            Write-Error "The specified path '$Path' does not exist."
            return
        }
    }
    
    process {
        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path = $Path
        $watcher.IncludeSubdirectories = $true
        $watcher.EnableRaisingEvents = $true

        Write-Host "FileSystemWatcher configured for path: $Path"
        Write-Host "IncludeSubdirectories: $($watcher.IncludeSubdirectories)"
        Write-Host "EnableRaisingEvents: $($watcher.EnableRaisingEvents)"

        $changedEvent = Register-ObjectEvent $watcher Changed -SourceIdentifier FileChanged -Action {
            Write-Host "File changed: $($Event.SourceEventArgs.FullPath)"
        }

        $createdEvent = Register-ObjectEvent $watcher Created -SourceIdentifier FileCreated -Action {
            Write-Host "File created: $($Event.SourceEventArgs.FullPath)"
        }

        $deletedEvent = Register-ObjectEvent $watcher Deleted -SourceIdentifier FileDeleted -Action {
            Write-Host "File deleted: $($Event.SourceEventArgs.FullPath)"
        }

        $renamedEvent = Register-ObjectEvent $watcher Renamed -SourceIdentifier FileRenamed -Action {
            Write-Host "File renamed: $($Event.SourceEventArgs.OldFullPath) to $($Event.SourceEventArgs.FullPath)"
        }

        Write-Host "Events registered. Monitoring changes in '$Path'. Press Ctrl+C to stop."

        while ($true) {
            Start-Sleep -Seconds 1
        }
    }

    end {
        # Cleanup: Unregister events and dispose of the watcher
        Unregister-Event -SourceIdentifier FileChanged -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier FileCreated -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier FileDeleted -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier FileRenamed -ErrorAction SilentlyContinue
        $watcher.Dispose()
        Write-Host "Stopped monitoring changes in '$Path'."
    }
}