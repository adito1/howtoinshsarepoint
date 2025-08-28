

# Define variables
$clientId = "YOUR_CLIENT_ID"
$tenantId = "YOUR_TENANT_ID"
$clientSecret = "YOUR_CLIENT_SECRET"
$filePath = "C:\Path\To\Your\smallFile.zip"
$siteId = "YOUR_SITE_ID" 
<#
You can get the site id using SPO API
https://<YourTenant>.sharepoint.com/sites/test1/_api/site/id
#>
$documentLibraryName = "doclib1"
$folder = "folder"

$fileName = [System.IO.Path]::GetFileName($filePath)
$graphScope = "https://graph.microsoft.com/.default"

# Get access token
$tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Body @{
    client_id     = $clientId
    scope         = $graphScope
    client_secret = $clientSecret
    grant_type    = "client_credentials"
}
$accessToken = $tokenResponse.access_token

#get the drive id for document library with "name": "doclib1"
$driveResponse = Invoke-RestMethod -Method Get -Uri "https://graph.microsoft.com/v1.0/sites/${siteId}/drives" -Headers @{
    "Authorization" = "Bearer $accessToken"
}
$driveId = ($driveResponse.value | Where-Object { $_.name -eq $documentLibraryName }).id

$uploadUrl = "https://graph.microsoft.com/v1.0/sites/${siteId}/drives/${driveId}/items/root:/${folder}/${fileName}:/content"

# Read the content of the file
$fileContent = [System.IO.File]::ReadAllBytes($filePath)

# Prepare headers
$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Content-Type"  = "application/octet-stream"
}

# Upload the file
$response = Invoke-RestMethod -Uri $uploadUrl -Method Put -Headers $headers -Body $fileContent

Write-Host "Upload complete."