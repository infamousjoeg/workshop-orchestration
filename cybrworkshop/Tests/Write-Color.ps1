Import-Module ..\cybrworkshop.psd1

$host.ui.RawUI.ForegroundColor = "Green"
Write-Output "==> Testing Import-ConfigXML Starting"

if (Write-Color "Poop") {
    Write-Output "Pass."
}

if (Write-Color "Poop" -Color Green) {
    Write-Output "Pass."
}

if (Write-Color "Poop" -Color Yellow) {
    Write-Output "Pass."
}

if (Write-Color "Poop" -Color Red) {
    Write-Output "Pass."
}

if (Write-Color "Poop" -Color Cyan) {
    Write-Output "Pass."
}

if (!$(Write-Color "Poop" -Color Magenta)) {
    Write-Output "Pass."
}

Write-Output "==> Testing Import-ConfigXML Successful"