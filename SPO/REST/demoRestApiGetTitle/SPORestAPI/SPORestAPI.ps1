<#
./ExtractNuGetPackage.ps1 -packageName "Microsoft.SharePointOnline.CSOM" -version "16.1.24301.12000" -url "https://www.nuget.org/api/v2/package"
./ExtractNuGetPackage.ps1 -packageName "Microsoft.Identity.Client" -version "4.54.0" -url "https://www.nuget.org/api/v2/package"
#>


#./Create-SelfSignedCertificate.ps1 -CommonName "testCert1" -StartDate 2025-01-01 -EndDate 2025-12-31 

#pass: "testms"


# Parameters

$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

$tenantId = ""
$clientId = ""
$siteUrl = "https://<yourTenant>.sharepoint.com/sites/test1"
$certPath = Join-Path $scriptDir "\testCert1.pfx"
$certPassword = ConvertTo-SecureString "testms" -AsPlainText -Force
$restUrl = "$siteUrl/_api/web?`$select=Title"


# get the access token using MSAL
try {
    $dllPath = Join-Path $scriptDir "\dlls"

    Add-Type -Path "$dllPath\Microsoft.Identity.Client.dll"
    Add-Type -Path "$dllPath\Microsoft.IdentityModel.Abstractions.dll"

    # Load certificate
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $certPassword)

    # Acquire token using MSAL
    $authority = "https://login.microsoftonline.com/$tenantId"
    $scope = [string[]]@("https://$tenantId.sharepoint.com/.default")


    $msal = [Microsoft.Identity.Client.ConfidentialClientApplicationBuilder]::Create($clientId).
    WithCertificate($cert).
    WithAuthority($authority).
    Build()

    $authResult = $msal.AcquireTokenForClient($scope).ExecuteAsync().Result
    $accessToken = $authResult.AccessToken
    Write-Host "Access Token acquired successfully" -ForegroundColor Green
}
catch {
    Write-Host "Error acquiring token: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}




# Set up headers for REST API call
$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Accept"        = "application/json;odata=verbose"
    "Content-Type"  = "application/json;odata=verbose"
}

try {
    Write-Host "Making REST API call to: $restUrl" -ForegroundColor Yellow
    
    # Make the REST API call
    $response = Invoke-RestMethod -Uri $restUrl -Method Get -Headers $headers
    
    # Extract and display the site title
    $siteTitle = $response.d.Title
    Write-Host "Site Title: $siteTitle" -ForegroundColor Green
    
    # Display the full response for debugging (optional)
    Write-Host "`nFull Response:" -ForegroundColor Cyan
    $response.d | ConvertTo-Json -Depth 3
}
catch {
    Write-Host "Error occurred while making REST API call:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    Write-Host "Status Description: $($_.Exception.Response.StatusDescription)" -ForegroundColor Red
}
