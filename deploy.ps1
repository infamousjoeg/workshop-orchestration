Import-Module psPAS
Import-Module ActiveDirectory

$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Import XML Configuration Settings from config.xml
[xml]$configFile    = Get-Content "config.xml"
$count              = 0
$workshopCollected  = @()

# Cleanup pre-existing exported CSV
Remove-Item -Path $configFile.Settings.CSVExportPath -ErrorAction SilentlyContinue | Out-Null

Write-Host "==> Starting deployment" -ForegroundColor Green
Write-Host ""
Write-Host "==> Creating REST API session" -ForegroundColor Yellow
try {
    New-PASSession -BaseURI $configFile.Settings.API.BaseURL -Type $configFile.Settings.API.AuthType -Credential $(Get-Credential)
} catch {
    Write-Error $_
    Write-Error "There was a problem creating an API session with CyberArk PAS." -ErrorAction Stop
}

do {
    # Increase counter by one
    $count++
    # Set loop variables
    $adUsername         = "User${count}"
    Add-Type -AssemblyName System.Web
    $adPassword         = "4ut0m4t!0n${count}727"
    $pasSafeName        = "RESTAPIWorkshop${count}"
    $pasAppID           = "RESTAPIWorkshop${count}"
    # Save details into PSObject for export to CSV later
    $workshopUserInfo   = New-Object PSObject
    $workshopUserInfo | Add-Member -MemberType NoteProperty -Name username -Value $adUsername
    $workshopUserInfo | Add-Member -MemberType NoteProperty -Name password -Value $adPassword
    $workshopUserInfo | Add-Member -MemberType NoteProperty -Name safe -Value $pasSafeName
    $workshopUserInfo | Add-Member -MemberType NoteProperty -Name appid -Value $pasAppID
    $workshopCollected += $workshopUserInfo
    Remove-Variable workshopUserInfo
    
    # Create user object in Active Directory
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
    Write-Host "==> Creating Active Directory User Object ${adUsername}" -ForegroundColor Yellow
    try {
        New-ADUser @newADUser | Out-Null
    } catch {
        Write-Error $_
        Write-Error "Active Directory User Object could not be created." -ErrorAction Stop
    }

    Write-Host "==> Add ${adUsername} to ${configFile.Settings.ActiveDirectory.CyberArkUsers}" -ForegroundColor Yellow
    try {
        Add-ADGroupMember -Identity $configFile.Settings.ActiveDirectory.CyberArkUsers -Members $adUsername | Out-Null
    } catch {
        Write-Error $_
        Write-Error "Active Directory User Object could not be added to CyberArk Users AD Security Group." -ErrorAction Stop
    }

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
    try {
        Add-PASSafeMember @addSafeMember | Out-Null
    } catch {
        Write-Error $_
        Write-Error "Active Directory User could not be added to CyberArk Safe as Safe Owner." -ErrorAction Stop
    }

    $addApplication = @{
        AppID               = $pasAppID
        Description         = "REST API Workshop Application ID for User ${count}"
        Location            = "\Applications"
        AccessPermittedFrom = 9
        AccessPermittedTo   = 17
    }
    Write-Host "==> Creating $pasAppID Application ID" -ForegroundColor Yellow
    try {
        Add-PASApplication @addApplication | Out-Null
    } catch {
        Write-Error $_
        Write-Error "Application Identity could not be created." -ErrorAction Stop
    }
    Write-Host "==> Adding Machine Address for 0.0.0.0 on ${pasAppID}" -ForegroundColor Yellow
    try {
        Add-PASApplicationAuthenticationMethod -AppID $pasAppID -machineAddress "0.0.0.0" | Out-Null
    } catch {
        Write-Error $_
        Write-Error "Application Identity Authentication Method could not be added." -ErrorAction Stop
    }

    if (Test-Path -Path "${scriptDir}\MOCK_DATA.csv") {
        $mockAccounts = Import-Csv -Path "${scriptDir}\MOCK_DATA.csv"
    } else {
        Write-Error "Could not find MOCK_DATA.csv in the script's directory." -ErrorAction Stop
    }

    foreach ($account in $mockAccounts) {
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
            Add-PASAccount @addAccount | Out-Null
        } catch {
            Write-Error $_
            Write-Error "Could not create dummy user ${account.username} in CyberArk Safe." -ErrorAction Stop
        }
    }

} until ($count -eq $configFile.Settings.AttendeeCount)

Write-Host "==> Closed REST API session" -ForegroundColor Yellow
Close-PASSession

Write-Host ""
Write-Host "==> Deployment complete" -ForegroundColor Green

foreach ($object in $workshopCollected) {
    try {
        Export-Csv -Path $configFile.Settings.CSVExportPath -InputObject $object -NoTypeInformation -Force -Append
    } catch {
        Write-Error $_
        Write-Error "Could not complete export to CSV.  Error occured on ${object.username}." -ErrorAction Stop
    }
}
Write-Host "==> Wrote Workshop Details to ${configFile.Settings.CSVExportPath}" -ForegroundColor Cyan