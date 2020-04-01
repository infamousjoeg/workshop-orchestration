# workshop-orchestration

CyberArk PAS REST API Workshop Orchestration

## Requirements

* CyberArk PAS Core minimum version: 10.8
  * LDAP Integration configured in CyberArk PAS Core
  * The built-in Administrator user to run deploy.ps1 and teardown.ps1
  * Valid SSL on Password Vault Web Access (PVWA)
    * _Turning off validation is not supported currently_
* Microsoft PowerShell minimum version: 5.0

## deploy.ps1

### Inputs

* See [config.xml](#configxml)

### Outputs

* Active Directory User Object
  * `User1`, etc.
* Active Directory Account Password
  * Randomized using `System.Web.Security.Membership` from [.NET Framework](https://docs.microsoft.com/en-us/dotnet/api/system.web.security.membership?view=netframework-4.8) and immediately encrypted into `SecureString` before adding to variable into memory.
  * Password complexity is minimized for easier human input during the workshop.
    * 8 characters.
    * 3 required non-char (integer, symbol).
* Active Directory User Membership to CyberArk Users Security Group
  * As defined in [config.ps1](config.ps1).
* CyberArk EPVUser Licensed User Account
  * LDAP integration with CyberArk consumes an EPVUser license and creates an LDAP-based identity within PrivateArk.
* CyberArk Safe
  * Safe Name: `RESTAPIWorkshop1`, etc.
  * Description: `REST API Workshop Safe for User 1`, etc.
  * Managing CPM: `PasswordManager`
  * Number of Versions Retention: `1`
    * This is for easier teardown of the workshop environments.
* CyberArk User Account Added as CyberArk Safe Owner
  * Active Directory User added to CyberArk Safe with the following permissions:
    * `UseAccounts                             = $True`
    * `RetrieveAccounts                        = $True`
    * `ListAccounts                            = $True`
    * `AddAccounts                             = $True`
    * `UpdateAccountContent                    = $True`
    * `UpdateAccountProperties                 = $True`
    * `InitiateCPMAccountManagementOperations  = $True`
    * `SpecifyNextAccountContent               = $True`
    * `RenameAccounts                          = $True`
    * `DeleteAccounts                          = $True`
    * `UnlockAccounts                          = $True`
    * `ManageSafe                              = $False`
    * `ManageSafeMembers                       = $False`
    * `BackupSafe                              = $False`
    * `ViewAuditLog                            = $True`
    * `ViewSafeMembers                         = $True`
    * `RequestsAuthorizationLevel              = 0`
    * `AccessWithoutConfirmation               = $True`
    * `CreateFolders                           = $False`
    * `DeleteFolders                           = $False`
    * `MoveAccountsAndFolders                  = $False`
* CyberArk Application Identity
  * `RESTAPIWorkshop1`, etc.
  * Access Permitted From: `9`
  * Access Permitted To: `17`
    * Access is permitted `9am to 5pm`
  * Authentication Methods:
    * Machine Address Whitelisted: `0.0.0.0`
* Mock Account Objects Created in CyberArk Safe
  * Account names are retrieved from [MOCK_DATA.csv](MOCK_DATA.csv).
  * Automatic management of account objects is not enabled.

## config.xml

* `AttendeeCount`
  * The number of attendees/users to create environments for.
* `CSVExportPath`
  * The local filesystem path to export Workshop Details to for users.
* `BaseURL`
  * The PVWA address where the PAS Web Service is hosted.
  * e.g. `https://pvwa.example.com`
* `AuthType`
  * The authentication type (`cyberark`, `ldap`, `radius`, `windows`) to use when authenticating to the PAS REST API.
* `Domain`
  * The Active Directory domain name 
  * e.g. `joegarcia.dev`
* `UsersPath`
  * The path to the Organizational Unit (OU) or Container (CN) to create the Active Directory user object within.
  * e.g. `CN=Users,DC=joegarcia,DC=dev`
* `CyberArkUsers`
  * The name of the security group that is mapped to the CyberArk Users role within PrivateArk Client.  This is the security group that grants users access to login via PVWA.
* `ManagingCPM`
  * This would remain `PasswordManager` unless specifically changed during installation or it is necessary to target an additional CPM than the default.
* `PlatformID`
  * The out-of-the-box platform for `Windows Domain Accounts` is `WinDomain`.  If you copied `WinDomain` and created your own, reference that PlatformID instead.
  * Automatic management of the account will be disabled, so any `PlatformID` can be used.

## teardown.ps1

### Inputs

See [config.xml](#configxml).

### Outputs

* Removal of:
  * Active Directory User Object
  * CyberArk Account Objects within Safe
  * CyberArk EPVUser Licensed User from Safe Ownership
  * CyberArk Application Identity

Unfortunately, the safe will need to be removed 24 hours after [teardown.ps1](teardown.ps1) is ran due to retention policy of 1 day.

## Maintainer

Joe Garcia - [@infamousjoeg](https://github.com/infamousjoeg)

[![Buy me a coffee][buymeacoffee-shield]][buymeacoffee]

[buymeacoffee]: https://www.buymeacoffee.com/infamousjoeg
[buymeacoffee-shield]: https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png

## License

MIT
