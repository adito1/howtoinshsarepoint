
#documentation: https://learn.microsoft.com/en-us/graph/api/drive-list?view=graph-rest-1.0&tabs=http
# Configuration to be updated by user
$clientId = ""
$tenantId = ""
$clientSecret = ""
$sharePointHostname = "" #e.g. contoso.sharepoint.com
$driveId = "b!zqMKlANNeU6CogcOink3t3pQSoHnjCREsdd9z0QS9Z0DAkenOWfHT7KZSa8EdX8S"


<#
.SYNOPSIS
Get configuration from JSON file
#>
function Get-ConfigFromJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )
    
    Write-Host "Loading configuration from: $ConfigPath"
    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    $global:clientId = $config.clientId
    $global:tenantId = $config.tenantId
    $global:clientSecret = $config.clientSecret
    $global:sharePointHostname = $config.sharePointHostname
    Write-Host "Configuration loaded successfully"
}

<#
.SYNOPSIS
Get access token from Microsoft identity provider
#>
function Get-AccessToken {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $true)]
        [string]$ClientId,
        
        [Parameter(Mandatory = $true)]
        [string]$ClientSecret
    )
    
    Write-Host "Requesting access token..."
    $graphScope = "https://graph.microsoft.com/.default"
    
    $tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Body @{
        client_id     = $clientId
        scope         = $graphScope
        client_secret = $clientSecret
        grant_type    = "client_credentials"
    }
    
    Write-Host "Access token obtained successfully"
    return $tokenResponse.access_token
}


<#
.SYNOPSIS
Get all items for a given drive ID
Documentation: https://learn.microsoft.com/en-us/graph/api/driveitem-list-children?view=graph-rest-1.0&tabs=http
#>
function Get-DriveItems {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DriveId,
        
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        
        [Parameter(Mandatory = $true)]
        [string]$GraphV1Host
    )
    
    $driveItemsUrl = "${GraphV1Host}/drives/${DriveId}/root/children"
    Write-Host "Fetching drive items from: $driveItemsUrl"
    
    $itemsResponse = Invoke-RestMethod -Method Get -Uri $driveItemsUrl -Headers @{
        "Authorization" = "Bearer $AccessToken"
    }
    
    return $itemsResponse
}


# Main script execution
Write-Host "Starting Script: Liost Drive Items for ${driveId}" -ForegroundColor Green
Write-Host "============================================"


# Configuration
$configPath = "C:\Projects\HowToInSharePoint\git\howtoinshsarepoint\GraphAPIV1\env.json"
$graphV1Host = "https://graph.microsoft.com/v1.0"

try {
    if ( (Test-Path -Path $configPath)) {
        Get-ConfigFromJson -ConfigPath $configPath
    }
    
    
    # Step 1: Get access token
    $accessToken = Get-AccessToken -TenantId $tenantId `
        -ClientId $clientId `
        -ClientSecret $clientSecret

    #step 2: Get all items for a given drive id
    
    $itemsResponse = Get-DriveItems -DriveId $driveId `
        -AccessToken $accessToken `
        -GraphV1Host $graphV1Host
    Write-Host "Drive items retrieved successfully"
    Write-Host "Items in drive ${driveId}:"
    foreach ($item in $itemsResponse.value) {
        Write-Host " - $($item.name) (ID: $($item.id))"
    }
 
    

}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}

