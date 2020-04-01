Import-Module psPAS
Import-Module ActiveDirectory

# Set the script path to a variable in case it is run from another path
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Cleanup pre-existing exported CSV
Remove-Item -Path $configFile.Settings.CSVExportPath -ErrorAction SilentlyContinue | Out-Null

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
try {
    New-Item -Type file $configFile.Settings.CSVExportPath | Out-Null
} catch {
    Write-Error $_
    Write-Error "Settings.CSVExportPath must be a valid file path within config.xml."
    Write-Error "If the path exists, please check NTFS permissions." -ErrorAction Stop
}
if (!$configFile.Settings.API.BaseURL -or $configFile.Settings.API.BaseURL -notmatch "[http|https]") {
    Write-Error "Settings.API.BaseURL must be a valid URL beginning with https:// or http:// in config.xml." -ErrorAction Stop
}
if (!$configFile.Settings.API.AuthType -or $configFile.Settings.API.AuthType.ToLower() -notmatch "[cyberark|ldap|windows|radius]") {
    Write-Error "Settings.API.AuthType must match cyberark, ldap, windows, or radius in config.xml." -ErrorAction Stop
}
if (!$configFile.Settings.ActiveDirectory.Domain) {
    Write-Error "Settings.ActiveDirectory.Domain must be present in config.xml."
}
if (!$configFile.Settings.ActiveDirectory.UsersPath) {
    Write-Error "Settings.ActiveDirectory.UsersPath must be present in config.xml."
}
if (!$configFile.Settings.ActiveDirectory.GroupsPath) {
    Write-Error "Settings.ActiveDirectory.GroupsPath must be present in config.xml."
}
if (!$configFile.Settings.CyberArk.ManagingCPM) {
    Write-Error "Settings.CyberArk.ManagingCPM must be present in config.xml."
}
if (!$configFile.Settings.CyberArk.PlatformID) {
    Write-Error "Settings.CyberArk.PlatformID must be present in config.xml."
}

Write-Host "==> Starting deployment" -ForegroundColor Green
Write-Host ""

Write-Host "==> Creating CyberArk Users Security Group for Workshop"
# Create hash table of parameters to splat into New-ADGroup cmdlet
$newADGroup = @{
    Name = "D-RESTAPIWorkshop_Users"
    SamAccountName = "D-RESTAPIWorkshop_Users"
    GroupCategory = "Security"
    GroupScope = "Global"
    DisplayName = "D-RESTAPIWorkshop_Users"
    Path = $configFile.Settings.ActiveDirectory.GroupsPath
    Description = "CyberArk Users group for REST API Workshop"
}
try {
    # Create Active Directory Security Group for New LDAP Mapping in PAS
    New-ADGroup @newADGroup
} catch {
    Write-Error $_
    Write-Error "Could not create CyberArk Users security group in Active Directory." -ErrorAction Stop
}

# Logon to PAS REST API
Write-Host "==> Creating REST API session" -ForegroundColor Yellow
try {
    New-PASSession -BaseURI $configFile.Settings.API.BaseURL -Type $configFile.Settings.API.AuthType -Credential $(Get-Credential)
} catch {
    Write-Error $_
    Write-Error "There was a problem creating an API session with CyberArk PAS." -ErrorAction Stop
}

Write-Host "==> Creating New LDAP Mapping for Workshop CyberArk Users Group"
# Create hash table of parameters to splat into New-PASDirectoryMapping cmdlet
$newPASDirectoryMapping = @{
    DirectoryName = $configFile.Settings.ActiveDirectory.Domain
    LDAPBranch = $configFile.Settings.ActiveDirectory.GroupsPath
    DomainGroups = "D-RESTAPIWorkshop_Users"
    MappingName = "RESTAPIWorkshop"
    MappingAuthorizations = "AddSafes"
}
try {
    # Create new LDAP Directory Mapping in PAS for the workshop's Users security group
    New-PASDirectoryMapping @newPASDirectoryMapping
} catch {
    Write-Error $_
    Write-Error "Could not create new LDAP directory mapping for D-RESTAPIWorkshop_Users." -ErrorAction Stop
}

# Set count for do...until loop to 0
$count = 0

# Begin doing the following command block until the count var...
# ... equals the total number of attendees declared in config.xml
do {
    # Increase counter by one
    $count++
    # Set loop variables
    $adUsername         = "User${count}"
    $adPassword         = "4ut0m4t!0n${count}727"
    $pasSafeName        = "SafeRESTAPIWorkshop${count}"
    $pasAppID           = "AppRESTAPIWorkshop${count}"
    # Save details into PSObject for export to CSV later...
    # ... also set initial values for reporting workshop object creation...
    # ... to False until they are successfully completed.
    $workshopUserInfo   = New-Object PSObject
    # Attendee Details
    $workshopUserInfo | Add-Member -MemberType NoteProperty -Name Username -Value $adUsername
    $workshopUserInfo | Add-Member -MemberType NoteProperty -Name Password -Value $adPassword
    $workshopUserInfo | Add-Member -MemberType NoteProperty -Name Safe -Value $pasSafeName
    $workshopUserInfo | Add-Member -MemberType NoteProperty -Name AppID -Value $pasAppID
    # Deployment Details
    $workshopUserInfo | Add-Member -MemberType NoteProperty -Name ADUser -Value "False"
    $workshopUserInfo | Add-Member -MemberType NoteProperty -Name CreateSafe -Value "False"
    $workshopUserInfo | Add-Member -MemberType NoteProperty -Name CreateAppID -Value "False"

    # Create hash table of parameters to splat into New-ADUser cmdlet
    $newADUser = @{
        Name                    = $adUsername
        ChangePasswordAtLogon   = $False
        Description             = "REST API Workshop User ${count}"
        DisplayName             = "User ${count}"
        PasswordNeverExpires    = $True
        Enabled                 = $True
        Path                    = $configFile.Settings.ActiveDirectory.UsersPath
        SamAccountName          = $adUsername
        AccountPassword         = $(ConvertTo-SecureString $adPassword -AsPlainText -Force)
        UserPrincipalName       = "${adUsername}@${configFile.Settings.ActiveDirectory.Domain}"
    }
    Write-Host "==> Creating Active Directory User Object: ${adUsername}" -ForegroundColor Yellow
    # Create user object in Active Directory
    try {
        New-ADUser @newADUser | Out-Null
        # If successfully created, flip deployment detail from False to True
        $workshopUserInfo.ADUser = "True"
    } catch {
        # If unsuccessful, throw error messages and stop the script
        Close-PASSession
        Write-Error $_
        Write-Error "Active Directory User Object could not be created." -ErrorAction Stop
    }

    Write-Host "==> Add ${adUsername} to CyberArk Users security group" -ForegroundColor Yellow
    # Add the new AD user to the CyberArk Users security group as defined in config.xml
    try {
        Add-ADGroupMember -Identity $configFile.Settings.ActiveDirectory.CyberArkUsers -Members $adUsername | Out-Null
    } catch {
        Close-PASSession
        Write-Error $_
        Write-Error "Active Directory User Object could not be added to CyberArk Users AD Security Group." -ErrorAction Stop
    }

    Write-Host "==> Adding safe: ${pasSafeName}" -ForegroundColor Yellow
    # Create hash table of parameters to splat into Invoke-RestMethod
    $addSafe = @{
        Uri = "${configFile.Settings.API.BaseURL}/PasswordVault/api/safes"
        Method = "Post"
        ContentType = "application/json"
        # Use the already established WebSession from psPAS module
        WebSession = $(Get-PASSession).WebSession
    }
    # Create hash table of JSON body to send in request to Add Safe
    $bodyAddSafe = @{
        safe = @{
            SafeName                = $pasSafeName
            Description             = "REST API Workshop Safe for User ${count}"
            ManagingCPM             = $configFile.Settings.CyberArk.ManagingCPM
            NumberOfDaysRetention   = 0
        }
    } | ConvertTo-Json -Depth 2 # We add Depth parameter because we have a nested JSON

    try {
        # We're going to use an undocumented v2 API endpoint for Add Safe
        # This will allow us to set NumberOfDaysRetention to 0 for instant removal
        Invoke-RestMethod @addSafe -Body $bodyAddSafe
        # If successfully created, flip deployment detail from False to True
        $workshopUserInfo.CreateSafe = "True"
    } catch {
        Close-PASSession
        Write-Error $_
        Write-Error "CyberArk Safe ${pasSafeName} could not be added."
        Write-Error "Try running teardown.ps1 again to delete any orphaned safes." -ErrorAction Stop
    }

    # Create hash table of parameters to splat into Add-PASSafeMember cmdlet
    $addSafeMember = @{
        SafeName                                = $pasSafeName
        MemberName                              = $adUsername
        SearchIn                                = $configFile.Settings.ActiveDirectory.Domain
        UseAccounts                             = $True
        RetrieveAccounts                        = $True
        ListAccounts                            = $True
        AddAccounts                             = $True
        UpdateAccountContent                    = $True
        UpdateAccountProperties                 = $True
        InitiateCPMAccountManagementOperations  = $True
        SpecifyNextAccountContent               = $True
        RenameAccounts                          = $True
        DeleteAccounts                          = $True
        UnlockAccounts                          = $True
        ManageSafe                              = $True
        ManageSafeMembers                       = $True
        BackupSafe                              = $False
        ViewAuditLog                            = $True
        ViewSafeMembers                         = $True
        RequestsAuthorizationLevel              = 0
        AccessWithoutConfirmation               = $True
        CreateFolders                           = $False
        DeleteFolders                           = $False
        MoveAccountsAndFolders                  = $False
    }
    Write-Host "==> Adding ${adUsername} as Safe Owner of ${pasSafeName}" -ForegroundColor Yellow
    try {
        # Add the new AD user as a member of the safe...
        # ... this is also where the EPVUser license is consumed by the new AD user.
        Add-PASSafeMember @addSafeMember | Out-Null
    } catch {
        Write-Error $_
        Write-Error "Active Directory User could not be added to CyberArk Safe as Safe Owner." -ErrorAction Stop
    }

    # Create hash table of parameters to splat into Add-PASApplication cmdlet
    $addApplication = @{
        AppID               = $pasAppID
        Description         = "REST API Workshop Application ID for User ${count}"
        Location            = "\Applications"
        # Access is only allowed from 9am - 5pm to the Application ID credentials
        AccessPermittedFrom = 9
        AccessPermittedTo   = 17
    }
    Write-Host "==> Creating $pasAppID Application ID" -ForegroundColor Yellow
    try {
        # Add a new Application ID
        Add-PASApplication @addApplication | Out-Null
        # If successfully created, flip deployment detail from False to True
        $workshopUserInfo.CreateAppID = "True"
    } catch {
        Write-Error $_
        Write-Error "Application Identity could not be created." -ErrorAction Stop
    }
    Write-Host "==> Adding Machine Address for 0.0.0.0 on ${pasAppID}" -ForegroundColor Yellow
    try {
        # Add a machineAddress IP of 0.0.0.0 to completely open the App ID up to anyone
        Add-PASApplicationAuthenticationMethod -AppID $pasAppID -machineAddress "0.0.0.0" | Out-Null
    } catch {
        Write-Error $_
        Write-Error "Application Identity Authentication Method could not be added." -ErrorAction Stop
    }

    # Check that MOCK_DATA.csv exists in the script directory
    if ($(Test-Path -Path "${scriptDir}\MOCK_DATA.csv")) {
        # If it does, we import the CSV data
        $mockAccounts = Import-Csv -Path "${scriptDir}\MOCK_DATA.csv"
    } else {
        Write-Error "Could not find MOCK_DATA.csv in the script's directory." -ErrorAction Stop
    }

    # This foreach loop will iterate through each row of the CSV containing mock account details
    # It will create an account in the safe previously created for each row
    foreach ($account in $mockAccounts) {
        # Create hash table of parameters to splat into Add-PASAccount based on the current row...
        # ... being read in the CSV.
        $addAccount = @{
            address                     = $configFile.Settings.ActiveDirectory.Domain
            username                    = $account.username
            platformID                  = $configFile.Settings.CyberArk.PlatformID
            SafeName                    = $pasSafeName
            automaticManagementEnabled  = $False
            secretType                  = "password"
            secret                      = $(ConvertTo-SecureString $([System.Web.Security.Membership]::GeneratePassword(8, 3)) -AsPlainText -Force)
        }
        Write-Host "==> Adding account object for ${account} to ${pasSafeName}" -ForegroundColor Yellow
        try {
            # Create the account object in our previously created safe
            Add-PASAccount @addAccount | Out-Null
        } catch {
            Write-Error $_
            Write-Error "Could not create dummy user ${account.username} in CyberArk Safe." -ErrorAction Stop
        }
    }

    # All attendee and deployment details are exported to a CSV file via append.
    # This will allow us to have a full report for after all environments are deployed.
    Export-Csv -Path $configFile.Settings.CSVExportPath -InputObject $workshopUserInfo -NoTypeInformation -Force -Append -ErrorAction SilentlyContinue
    # To be on the safe side, removing the variable should clear it out for the next loop.
    Remove-Variable workshopUserInfo

} until ($count -eq $configFile.Settings.AttendeeCount)

Write-Host "==> Closed REST API session" -ForegroundColor Yellow
# Logoff the PAS REST API after completing the do...until loop.
Close-PASSession

Write-Host ""
Write-Host "==> Deployment complete" -ForegroundColor Green

Write-Host "==> Wrote Workshop Details to ${configFile.Settings.CSVExportPath}" -ForegroundColor Cyan