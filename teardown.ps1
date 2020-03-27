Import-Module psPAS
Import-Module ActiveDirectory

# Import XML Configuration Settings from config.xml
[xml]$configFile = Get-Content "config.xml"
$count = 0

Write-Host "==> Starting teardown" -ForegroundColor Green
Write-Host ""
Write-Host "==> Creating REST API session" -ForegroundColor Yellow
New-PASSession -BaseURI $configFile.Settings.API.BaseURL -Type $configFile.Settings.API.AuthType -Credential $(Get-Credential) | Out-Null

do {
    # Increase counter by one
    $count++
    # Set loop variables
    $adUsername = "User${count}"
    $pasSafeName = "RESTAPIWorkshop${count}"
    $pasAppID = "RESTAPIWorkshop${count}"
    
    # Remove user object in Active Directory
    Write-Host "==> Removing Active Directory User Object ${adUsername}" -ForegroundColor Yellow
    Remove-ADUser -Identity $adUsername | Out-Null

    Write-Host "==> Removing safe ${pasSafeName}" -ForegroundColor Yellow
    Remove-PASSafe -SafeName $pasSafeName -ErrorAction SilentlyContinue | Out-Null

    Write-Host "==> Removing ${adUsername} as Safe Owner of ${pasSafeName}" -ForegroundColor Yellow
    Remove-PASSafeMember -SafeName $pasSafeName -MemberName $adUsername -ErrorAction SilentlyContinue | Out-Null

    Write-Host "==> Removing $pasAppID Application ID" -ForegroundColor Yellow
    Remove-PASApplication -AppID $pasAppID | Out-Null

} until ($count -eq $configFile.Settings.AttendeeCount)

Write-Host "==> Closed REST API session" -ForegroundColor Yellow
Close-PASSession

Write-Host ""
Write-Host "==> Teardown complete" -ForegroundColor Green