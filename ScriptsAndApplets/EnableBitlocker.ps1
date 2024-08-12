<#
.SYNOPSIS
Enables Bitlocker on all drives

.DESCRIPTION
See in line comments below on haw to change from enabling bitlocker on all internal drives to enabling on all internal and external drives
#>

#####################
#####Functions######
###################
function Set-ProjectFolder {
    <#
    .SYNOPSIS
    Create a project folder

    .DESCRIPTION
    The default (with no parameters) is to create C:\FT

    .PARAMETER baseDir
    .PARAMETER taskDir
    .PARAMETER changeDir

    .EXAMPLE
    Set-ProjectFolder
    Creates C:\FT

    .EXAMPLE
    Set-ProjectFolder -taskDir "WorkWork" -changeDir
    Creates C:\FT\WorkWork and changes to that directory

    .EXAMPLE
    Set-ProjectFolder -taskDir "Work\Work" -changeDir
    Creates C:\FT\Work\Work and changes to that directory

    #>
    param (
        [string]$baseDir = "$env:SystemDrive\FT",
        [string]$taskDir,
        [switch]$changeDir
    )
    process {
        #If the path doesn't exist - Make it. 
        if (!(test-path $basedir)){
            #New-Item -Path "$baseDir" -ItemType "directory"
            mkdir "$basedir"
        }
        #Check if task dir is needed
        if (!([string]::isnullorempty($taskDir))){
            if (!(test-path "$baseDir\$taskDir")){
                #New-Item -Path "$baseDir\$taskDir" -ItemType "directory"
                mkdir "$baseDir\$taskDir"
            }
        }
    }
    end {
        #Set working dir
        if($changeDir){
            if (!([string]::isnullorempty($taskDir))){
                Set-Location "$baseDir\$taskDir"
            }
            else{
                Set-Location "$baseDir"
            }
        }
    }
}

#####################
#####Formatting#####
###################

####Set a window title and foreground color
$uiConfig = (Get-Host).UI.RawUI
$uiConfig.WindowTitle = "Definitely Not Something Evil"
$uiConfig.ForegroundColor = "DarkCyan"

Write-Host ""
Write-Host "===========================================================" -ForeGroundColor Cyan
Write-Host "|                                                         |" -ForeGroundColor Cyan
Write-Host "|                 Enable Bitlocker                        |" -ForeGroundColor Cyan
Write-Host "|                                                         |" -ForeGroundColor Cyan
Write-Host "|                Written By: Colby C                      |" -ForeGroundColor Cyan
Write-Host "|                                                         |" -ForeGroundColor Cyan
Write-Host "===========================================================" -ForeGroundColor Cyan
Write-Host ""

#######################
#####Do The Thing#####
#####################

#Create folder and file for outputing keys. Remember to save this file somewhere off the computer
Set-ProjectFolder -changeDir
New-Item -Path . -Name "keys.txt" -ItemType "file"

<# Un-comment this block to include removable drives
# Get all drives
$Drives = Get-BitLockerVolume
$OsDrive = $Drives | Where-Object {$_.VolumeType -eq "OperatingSystem"}
$NonOsDrives = $Drives | Where-Object {$_.VolumeType -ne "OperatingSystem"}#>

# Comment this block if you are using the above block
#Get only internal drives
$Drives = Get-BitLockerVolume;
$OsDrive = $Drives | Where-Object { $_ -match $env:SystemDrive};
$IntDrives = [System.IO.DriveInfo]::getdrives() | Where-Object {$_.DriveType -ne 'Network' -and $_.DriveType -ne 'Removable'};
$IntDrives = $IntDrives.name;
$IntDrives = $IntDrives -replace '\\$','';
$NonOsDrives = $IntDrives | Where-Object { $_ -ne $env:SystemDrive };
$NonOsDrives = $Drives | Where-Object { $_ -like $NonOsDrives };

# Check if TPM is enabled
if ((Get-Tpm).TpmEnabled) {
    #Encrypt OS Drive
    # Check if the drive is encrypted
    if ($OsDrive.VolumeStatus -eq "FullyDecrypted") {
        # Encrypt the drive with TPM protector
        Try {
            Write-Host "TPM is ready, we're going to try to encrypt"
            #Bitlocker the drive using the TPM instead of a password
            Enable-BitLocker -MountPoint $OsDrive.MountPoint -UsedSpaceOnly -SkipHardwareTest -TpmProtector -ErrorAction Stop
            Write-Host "We have enabled bitlocker succesfully"
            #Create a recovery key for the drive (The key and the password are not the same thing)
            Add-BitLockerKeyProtector -RecoveryPasswordProtector -MountPoint $OsDrive.MountPoint
            Write-Host "We have added a Bitlocker Key Protector succesfully"
            Resume-BitLocker $OsDrive.MountPoint
            Write-Host "We have resumed bitlocker protection if it was disabled by the user."
        }
        catch {
            Write-Host "Could not enable bitlocker $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "Drive" $Osdrive.mountpoint "is already encrypted"
    }

    # Loop through each Non-OS drive
    foreach ($Drive in $NonOsDrives) {
        # Check if the drive is encrypted
        if ($Drive.VolumeStatus -eq "FullyDecrypted") {
            # Encrypt the drive with TPM protector
            Try {
                Write-Host "Encrypting" $Drive.mountpoint
                # Generate a random string of 42 characters with letters and numbers fpr password
                $blpw = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 42 | % {[char]$_})
                $secureString = ConvertTo-SecureString -String $blpw -AsPlainText -Force
                #Enable bitlocker with the above password
                Enable-BitLocker -MountPoint $Drive.MountPoint -UsedSpaceOnly -Password $secureString -PasswordProtector
                Write-Host "We have enabled bitlocker succesfully"
                #Create a recovery key for the drive (The key and the password are not the same thing)
                Add-BitLockerKeyProtector -RecoveryPasswordProtector -MountPoint $Drive.MountPoint
                Write-Host "We have added a Bitlocker Key Protector succesfully"
                Resume-BitLocker $Drive.MountPoint
                Write-Host "We have resumed bitlocker protection if it was disabled by the user."
                #Record the password for this drive
                $BitlockerPw += $Drive.MountPoint + " " + $blpw
            }
            catch {
                Write-Host "Could not enable bitlocker $($_.Exception.Message)"
            }
        }
        else {
            Write-Host "Drive" $Drive.mountpoint "is already encrypted"
        }
    }
}
else {
    Write-Host "The device is not ready for bitlocker. The TPM is reporting that it is not ready for use. Reported TPM information:"
    Get-Tpm
    # exit 1
}

#Refresh drive info
$Drives = Get-BitLockerVolume
# Create an empty array to store the keys
$BitlockerKey = @()

# Loop through each drive for Recovery key
foreach ($Drive in $Drives) {
    if($Drive.KeyProtector){
        # Get the recovery key for the drive
        $RecoveryKey = ($Drive.KeyProtector | Where-Object {$_.KeyProtectorType -eq "RecoveryPassword"}).RecoveryPassword
        # Add the key to the array
        $BitlockerKey += [string]::Join(' ',$Drive, $RecoveryKey)        
    }
}
##Output password for non-OS drives (This is not the same as the recovery key)
if ($NonOsDrives){
    if ($BitlockerPw) {
        Write-Host "We're documenting the bitlocker password: $BitlockerPw"
        Add-Content -Path "keys.txt" -Value $BitlockerPw
    }
}
 
# Send to file
if ($BitlockerKey) {
    Write-Host "We're documenting the bitlocker key: $BitlockerKey"
    Add-Content -Path "keys.txt" -Value $BitlockerPw
    exit 0
}
else {
    Write-Host "We could not detect a bitlocker key. Enabling Bitlocker failed.(BitlockerKey Check)"
    exit 1
}