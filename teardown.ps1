Import-Module psPAS
Import-Module ActiveDirectory

# Set the script path to a variable in case it is run from another path
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Import XML Configuration Settings from config.xml
try {
    [xml]$configFile = Get-Content "${scriptDir}\config.xml"
} catch {
    Write-Error $_
    Write-Error "config.xml is not present in the script directory." -ErrorAction Stop
}

# Test config.xml Values
if ($configFile.Settings.AttendeeCount -le 0 -or !$configFile.Settings.AttendeeCount) {
    Write-Error "Settings.AttendeeCount in config.xml must be greater than zero." -ErrorAction Stop
}
if (!$configFile.Settings.API.BaseURL -or $configFile.Settings.API.BaseURL -notmatch "[http|https]") {
    Write-Error "Settings.API.BaseURL must be a valid URL beginning with https:// or http:// in config.xml." -ErrorAction Stop
}
if (!$configFile.Settings.API.AuthType -or $configFile.Settings.API.AuthType.ToLower() -notmatch "[cyberark|ldap|windows|radius]") {
    Write-Error "Settings.API.AuthType must match cyberark, ldap, windows, or radius in config.xml." -ErrorAction Stop
}

Write-Host "==> Starting teardown" -ForegroundColor Green
Write-Host ""

# Logon to PAS REST API
Write-Host "==> Creating REST API session" -ForegroundColor Yellow
try {
    New-PASSession -BaseURI $configFile.Settings.API.BaseURL -Type $configFile.Settings.API.AuthType -Credential $(Get-Credential)
} catch {
    Write-Error $_
    Write-Error "There was a problem creating an API session with CyberArk PAS." -ErrorAction SilentlyContinue
}

# Set count for do...until loop to 0
$count = 0

do {
    # Increase counter by one
    $count++
    # Set loop variables
    $adUsername = "User${count}"
    $pasSafeName = "SafeRESTAPIWorkshop${count}"
    $pasAppID = "AppRESTAPIWorkshop${count}"
    
    # Remove user object in Active Directory
    Write-Host "==> Removing Active Directory User Object ${adUsername}" -ForegroundColor Yellow
    try {
        Remove-ADUser -Identity $adUsername -Confirm:$False | Out-Null
    } catch {
        Write-Error $_
        Write-Error "Active Directory User Object ${adUsername} could not be removed." -ErrorAction SilentlyContinue
    }

    # Remove safe from EPV
    Write-Host "==> Removing safe ${pasSafeName}" -ForegroundColor Yellow
    try {
        Remove-PASSafe -SafeName $pasSafeName | Out-Null
    } catch {
        Write-Error $_
        Write-Error "CyberArk Safe ${pasSafeName} could not be deleted." -ErrorAction SilentlyContinue
    }

    # Remove application from EPV
    Write-Host "==> Removing $pasAppID Application ID" -ForegroundColor Yellow
    try {
        Remove-PASApplication -AppID $pasAppID | Out-Null
    } catch {
        Write-Error $_
        Write-Error "CyberArk Application ID ${pasAppID} could not be deleted." -ErrorAction SilentlyContinue
    }

} until ($count -eq $configFile.Settings.AttendeeCount)

Write-Host "==> Removing LDAP Directory Mapping of D-RESTAPIWorkshop_Users"
try {
    Get-PASDirectoryMapping -DirectoryName $configFile.Settings.ActiveDirectory.Domain -MappingID RESTAPIWorkshop | Remove-PASDirectoryMapping
} catch {
    Write-Error $_
    Write-Error "Could not remove LDAP Directory Mapping of D-RESTAPIWorkshop_Users" -ErrorAction SilentlyContinue
}

Write-Host "==> Removing CyberArk Users Security Group for Workshop"
try {
    Remove-ADGroup -Identity D-RESTAPIWorkshop_Users -Confirm:$False
} catch {
    Write-Error $_
    Write-Error "Could not remove CyberArk Users security group D-RESTAPIWorkshop_Users in Active Directory." -ErrorAction SilentlyContinue
}

Write-Host "==> Closed REST API session" -ForegroundColor Yellow
# Logoff the PAS REST API
Close-PASSession

Write-Host ""
Write-Host "==> Teardown complete" -ForegroundColor Green