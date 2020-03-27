Import-Module psPAS
Import-Module ActiveDirectory

# Import XML Configuration Settings from config.xml
[xml]$configFile    = Get-Content "config.xml"
$count              = 0
$workshopUserInfo   = New-Object PSObject
$workshopCollected  = @()

# Cleanup pre-existing exported CSV
Remove-Item -Path $configFile.Settings.ExportCSVPath -ErrorAction SilentlyContinue | Out-Null

Write-Host "==> Starting deployment" -ForegroundColor Green
Write-Host ""
Write-Host "==> Creating REST API session" -ForegroundColor Yellow
New-PASSession -BaseURI $configFile.Settings.API.BaseURL -Type $configFile.Settings.API.AuthType -Credential $(Get-Credential)

do {
    # Increase counter by one
    $count++
    # Set loop variables
    $adUsername         = "User${count}"
    Add-Type -AssemblyName System.Web
    $adPassword         = [System.Web.Security.Membership]::GeneratePassword(8, 3)
    $adSecurePassword   = ConvertTo-SecureString $adPassword -AsPlainText -Force
    $apiPSCredential    = New-Object System.Management.Automation.PSCredential($adUsername, $adSecurePassword)
    Remove-Variable adSecurePassword
    $pasSafeName        = "RESTAPIWorkshop${count}"
    $pasAppID           = "RESTAPIWorkshop${count}"
    # Save details into PSObject for export to CSV later
    $workshopUserInfo | Add-Member MemberType NoteProperty -Name "username" -Value $adUsername
    $workshopUserInfo | Add-Member MemberType NoteProperty -Name "password" -Value $adPassword
    $workshopUserInfo | Add-Member MemberType NoteProperty -Name "safe" -Value $pasSafeName
    $workshopUserInfo | Add-Member MemberType NoteProperty -Name "appid" -Value $pasAppID
    $workshopCollected += $workshopUserInfo
    
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
    New-ADUser @newADUser | Out-Null

    Write-Host "==> Setting Password for ${adUsername}" -ForegroundColor Yellow
    Set-ADAccountPassword -Identity $adUsername -NewPassword $adSecurePassword | Out-Null

    Write-Host "==> Add ${adUsername} to ${configFile.Settings.ActiveDirectory.CyberArkUsers}" -ForegroundColor Yellow
    Add-ADGroupMember -Identity $configFile.Settings.ActiveDirectory.CyberArkUsers -Members $adUsername | Out-Null

    Write-Host "==> Creating REST API session as ${adUsername} to apply EPVUser license" -ForegroundColor Yellow
    New-PASSession -BaseURI $configFile.Settings.API.BaseURL -Type LDAP -Credential $apiPSCredential | Close-PASSession
    Write-Host "==> Closed REST API session as ${adUsername}" -ForegroundColor Yellow

    Write-Host "==> Adding safe ${pasSafeName}" -ForegroundColor Yellow
    $addSafe = @{
        SafeName                = $pasSafeName
        Description             = "REST API Workshop Safe for User ${count}"
        ManagingCPM             = $configFile.Settings.CyberArk.ManagingCPM
        NumberOfDaysRetention   = 1
        ErrorAction             = SilentlyContinue
    }
    Add-Safe @addSafe | Out-Null

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
    Add-PASSafeMember @addSafeMember | Out-Null

    $addApplication = @{
        AppID               = $pasAppID
        Description         = "REST API Workshop Application ID for User ${count}"
        Location            = "\Applications"
        AccessPermittedFrom = 9
        AccessPermittedTo   = 17
    }
    Write-Host "==> Creating $pasAppID Application ID" -ForegroundColor Yellow
    Add-PASApplication @addApplication | Out-Null
    Write-Host "==> Adding Machine Address for 0.0.0.0 on ${pasAppID}" -ForegroundColor Yellow
    Add-PASApplicationAuthenticationMethod -AppID $pasAppID -machineAddress "0.0.0.0" | Out-Null

    $mockAccounts = Import-Csv -Path MOCK_DATA.csv
    foreach ($account in $mockAccounts) {
        $addAccount = @{
            address                     = $configFile.Settings.ActiveDirectory.Domain
            username                    = $account.username
            platformID                  = $configFile.Settings.CyberArk.PlatformID
            SafeName                    = $pasSafeName
            automaticManagementEnabled  = $False
            secretType                  = "password"
            secret                      = ConvertTo-SecureString $([System.Web.Security.Membership]::GeneratePassword(8, 3)) -AsPlainText -Force
        }
        Write-Host "==> Adding account object for ${account} to ${pasSafeName}" -ForegroundColor Yellow
        Add-PASAccount @addAccount | Out-Null
    }

} until ($count -eq $configFile.Settings.AttendeeCount)

Write-Host "==> Closed REST API session" -ForegroundColor Yellow
Close-PASSession

Write-Host ""
Write-Host "==> Deployment complete" -ForegroundColor Green

foreach ($object in $workshopCollected) {
    Export-Csv -Path $configFile.Settings.ExportCSVPath -InputObject $object -NoTypeInformation -Force -Append
}
Write-Host "==> Wrote Workshop Details to ${configFile.Settings.ExportCSVPath}" -ForegroundColor Cyan