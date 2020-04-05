function Import-ConfigXML {
	<#
	.SYNOPSIS
	Import config.xml from the given directory path.

	.DESCRIPTION
    Gets the content of config.xml located in the given directory path and adds it to an xml type variable.

	.PARAMETER Path
	The path to where the config.xml file is located.

    .EXAMPLE
	Import-ConfigXML -Path $(Split-Path -Path $MyInvocation.MyCommandDefinition -Parent)

	Import config.xml that is located in the same directory the script that ran Invoke-ConfigXML executed from.
	#>
	param
	(
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if ( !($_ | Test-Path) ) {
                Write-Error "Folder does not exist." -ErrorAction Stop
            }
            return $True
        })]
		[string]$Path
	)

	Begin {

        if ($Path -notmatch "config.xml") {
            $Path = $Path.TrimEnd("\") + "\config.xml"
        }
        if ( !($Path | Test-Path -PathType Leaf) ) {
            Write-Error "config.xml file does not exist at ${Path}." -ErrorAction Stop
        }
        
    }

	Process {

        # Import XML Configuration Settings from config.xml
        try {
            [xml]$configFile = Get-Content $Path
        } catch {
            Write-Error $_
            Write-Error "config.xml is not present in the script directory." -ErrorAction Stop
        }

        # Cleanup pre-existing exported CSV
        Remove-Item -Path $configFile.Settings.CSVExportPath -ErrorAction SilentlyContinue | Out-Null

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
        if (!$configFile.Settings.CyberArk.PlatformID) {
            Write-Error "Settings.CyberArk.PlatformID must be present in config.xml."
        }

        return $configFile

	}

	End { }

}