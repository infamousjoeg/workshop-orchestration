Import-Module psPAS
Import-Module ActiveDirectory

# Import XML Configuration Settings from config.xml
[xml]$configFile = Get-Content "config.xml"
$count = 0
$workshopUserInfo = @{}

Write-Host "==> Starting deployment" -ForegroundColor Green
Write-Host ""
Write-Host "==> Creating REST API session" -ForegroundColor Yellow
New-PASSession -BaseURI $configFile.Settings.API.BaseURL -Type $configFile.Settings.API.AuthType -Credential $(Get-Credential) | Out-Null

do {
    # Increase counter by one
    $count++
    # Set loop variables
    $adUsername = "User${count}"
    $adSecurePassword = ConvertTo-SecureString $([System.Web.Security.Membership]::GeneratePassword(8, 3)) -AsPlainText -Force
    Remove-Variable adPassword
    $apiPSCredential = New-Object System.Management.Automation.PSCredential($adUsername, $adSecurePassword)
    $pasSafeName = "RESTAPIWorkshop${count}"
    $pasAppID = "RESTAPIWorkshop${count}"
    # Save metadata into hash table for reporting later
    $workshopUserInfo.Append($adUsername, $adPassword, $pasSafeName, $pasAppID)
    
    # Create user object in Active Directory
    $newADUser = @{
        Name                    = $adUsername
        ChangePasswordAtLogon   = $False
        Description             = "REST API Workshop User ${count}"
        DisplayName             = "User ${count}"
        Enabled                 = $True
        PasswordNeverExpires    = $True
        Path                    = $configFile.Settings.ActiveDirectory.UsersPath
        SamAccountName          = $adUsername
    }
    Write-Host "==> Creating Active Directory User Object ${adUsername}" -ForegroundColor Yellow
    New-ADUser @newADUser

    Write-Host "==> Setting Password for ${adUsername}" -ForegroundColor Yellow
    Set-ADAccountPassword -Identity $adUsername -NewPassword $adSecurePassword

    Write-Host "==> Add ${adUsername} to ${configFile.Settings.ActiveDirectory.CyberArkUsers}" -ForegroundColor Yellow
    Add-ADGroupMember -Identity $configFile.Settings.ActiveDirectory.CyberArkUsers -Members $adUsername

    Write-Host "==> Creating REST API session as ${adUsername} to apply EPVUser license" -ForegroundColor Yellow
    New-PASSession -BaseURI $configFile.Settings.API.BaseURL -Type LDAP -Credential $apiPSCredential | Close-PASSession
    Write-Host "==> Closed REST API session as ${adUsername}" -ForegroundColor Yellow

    Write-Host "==> Adding safe ${pasSafeName}" -ForegroundColor Yellow
    Add-Safe -SafeName $pasSafeName -Description "REST API Workshop Safe for User ${count}" -ManagingCPM $configFile.Settings.CyberArk.ManagingCPM -NumberOfVersionsRetention 1

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
        ManageSafe                              = $False
        ManageSafeMembers                       = $False
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
    Add-PASSafeMember @addSafeMember

    $addApplication = @{
        AppID = $pasAppID
        Description = "REST API Workshop Application ID for User ${count}"
        Location = "\Applications"
        AccessPermittedFrom = 9
        AccessPermittedTo = 17
    }
    Write-Host "==> Creating $pasAppID Application ID" -ForegroundColor Yellow
    Add-PASApplication @addApplication
    Write-Host "==> Adding Machine Address for 0.0.0.0 on ${pasAppID}" -ForegroundColor Yellow
    Add-PASApplicationAuthenticationMethod -AppID $pasAppID -machineAddress "0.0.0.0"

    $mockAccounts = Import-Csv -Path MOCK_DATA.csv
    foreach ($account in $mockAccounts) {
        $addAccount = @{
            address = $configFile.Settings.ActiveDirectory.Domain
            username = $account
            platformID = $configFile.Settings.CyberArk.PlatformID
            SafeName = $pasSafeName
            automaticManagementEnabled = $False
        }
        Write-Host "==> Adding account object for ${account} to ${pasSafeName}" -ForegroundColor Yellow
        Add-PASAccount @addAccount
    }

} until ($count -eq $configFile.Settings.AttendeeCount)

Write-Host "==> Closed REST API session" -ForegroundColor Yellow
Close-PASSession

Write-Host ""
Write-Host "==> Deployment complete" -ForegroundColor Green

# Export $workshopUserInfo hash table to CSV
# $configFile.Settings.CSVExportPath