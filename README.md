# workshop-orchestration

CyberArk PAS REST API Workshop Orchestration

## deploy.ps1

### Inputs

* Number of people attending workshop

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

## config.ps1

Stay tuned...

## teardown.ps1

Stay tuned...


## Maintainer

Joe Garcia - [@infamousjoeg](https://github.com/infamousjoeg)

[![Buy me a coffee][buymeacoffee-shield]][buymeacoffee]

[buymeacoffee]: https://www.buymeacoffee.com/infamousjoeg
[buymeacoffee-shield]: https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png

## License

MIT
