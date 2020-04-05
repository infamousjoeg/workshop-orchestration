function Write-Color {
	<#
	.SYNOPSIS
	Write-Output in a specified foreground color.

	.DESCRIPTION
    Captures the current foreground color of the console, turns the foreground color to the color specified, 
    uses Write-Output to output the message, and then reverts the console to the previous foreground color set.

	.PARAMETER Message
    The output to print using Write-Output in the color specified in the -Color parameter.
    
    .PARAMETER Color
    The foreground color to set when sending the -Message parameter to Write-Output.

    .EXAMPLE
	Write-Color "==> Start this thing" -Color Green

    Write a message in the foreground color green.
    
    Write-Color "==> Updated status message about this thing"

    Write a message in the foreground color yellow.

    Write-Color "==> Wrote detailed output to a place about this thing" -Color Cyan

    Write a message in the foreground color cyan.
	#>
	param
	(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Yellow", "Green", "Red", "Cyan")]
        [string]$Color = "Yellow"
	)

	Begin { 

        # Get current Console color
        $defaultColor = $host.ui.RawUI.ForegroundColor

    }

	Process {

        try {
            # Write output in the color specified by -Color parameter
            $host.ui.RawUI.ForegroundColor = $Color
            Write-Output "${Message}"
            # Change output color back to what was set prior to Write-Color
            $host.ui.RawUI.ForegroundColor = $defaultColor
        } catch {
            Write-Error $_ -ErrorAction Stop
        }

	}

	End { }

}