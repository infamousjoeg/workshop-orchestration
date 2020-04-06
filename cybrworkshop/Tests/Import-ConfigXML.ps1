Import-Module ..\cybrworkshop.psd1

$host.ui.RawUI.ForegroundColor = "Green"
Write-Output "==> Testing Import-ConfigXML Starting"

# No config.xml stated - Existing directory
if (Import-ConfigXML -Path .\) {
    Write-Output "Pass."
}

# config.xml stated - Existing directory
if (Import-ConfigXML -Path .\config.xml) {
    Write-Output "Pass."
}

# config.xml stated - No directory given
if (Import-ConfigXML -Path config.xml) {
    Write-Output "Pass."
}

# No config.xml stated - Non-existing directory
if (!$(Import-ConfigXML -Path C:\poop)) {
    Write-Output "Pass."
}

# config.xml stated - Non-existing directory
if (!$(Import-ConfigXML -Path C:\poop\config.xml)) {
    Write-Output "Pass."
}

Write-Output "==> Testing Import-ConfigXML Successful"