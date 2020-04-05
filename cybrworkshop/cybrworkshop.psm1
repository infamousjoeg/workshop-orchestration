[CmdletBinding()]
param()

Get-ChildItem $PSScriptRoot\ -Recurse -Filter "*.ps1" -Exclude "*.ps1xml" |

    ForEach-Object {

        Try {

            # Dot Source each file
            . $_.FullName

        }

        Catch {

            Write-Error "Failed to import function $($_.FullName)"

        }

    }