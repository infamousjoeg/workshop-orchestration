Import-Module psPAS
Import-Module ActiveDirectory

$envCount = Read-Host "Enter the number of people attending workshop"
$count = 0
$workshopUserInfo = @{}

Write-Host "==> Starting deployment" -ForegroundColor Green
Write-Host ""
Write-Host "==> Creating REST API session" -ForegroundColor Yellow
New-PASSession -BaseURI https://cyberark.joegarcia.dev -Type LDAP -Credential $(Get-Credential) | Out-Null

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
        Path                    = "CN=Users,DC=joegarcia,DC=dev"
        SamAccountName          = $adUsername
    }
    Write-Host "==> Creating Active Directory User Object ${adUsername}" -ForegroundColor Yellow
    New-ADUser @newADUser

    Write-Host "==> Setting Password for ${adUsername}" -ForegroundColor Yellow
    Set-ADAccountPassword -Identity $adUsername -NewPassword $adSecurePassword

    Write-Host "==> Add ${adUsername} to P-CyberArk_Vault_Users" -ForegroundColor Yellow
    Add-ADGroupMember -Identity "P-CyberArk_Vault_Users" -Members $adUsername

    Write-Host "==> Creating REST API session as ${adUsername} to apply EPVUser license" -ForegroundColor Yellow
    New-PASSession -BaseURI https://cyberark.joegarcia.dev -Type LDAP -Credential $apiPSCredential | Close-PASSession
    Write-Host "==> Closed REST API session as ${adUsername}" -ForegroundColor Yellow

    Write-Host "==> Adding safe ${pasSafeName}" -ForegroundColor Yellow
    Add-Safe -SafeName $pasSafeName -Description "REST API Workshop Safe for User ${count}" -ManagingCPM "PasswordManager" -NumberOfVersionsRetention 1

    $addSafeMember = @{
        SafeName                                = $pasSafeName
        MemberName                              = $adUsername
        SearchIn                                = "joegarcia.dev"
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
            address = "joegarcia.dev"
            username = $account
            platformID = "WinDomain"
            SafeName = $pasSafeName
            automaticManagementEnabled = $False
        }
        Write-Host "==> Adding account object for ${account} to ${pasSafeName}" -ForegroundColor Yellow
        Add-PASAccount @addAccount
    }

} until ($count -eq $envCount)

Write-Host "==> Closed REST API session" -ForegroundColor Yellow
Close-PASSession

Write-Host ""
Write-Host "==> Deployment complete" -ForegroundColor Green

# Export $workshopUserInfo hash table to CSV