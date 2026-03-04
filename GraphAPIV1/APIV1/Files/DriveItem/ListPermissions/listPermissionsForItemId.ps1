
<# 
documentation: https://learn.microsoft.com/en-us/graph/api/driveitem-list-permissions?view=graph-rest-1.0&tabs=http
API endpoint: GET /drives/{drive-id}/items/{item-id}/permissions
#>
# Configuration to be updated by user (or loaded from env.json)
$clientId = ""
$tenantId = ""
$clientSecret = ""
$driveId = "b!zqMKlANNeU6CogcOink3t3pQSoHnjCREsdd9z0QS9Z0DAkenOWfHT7KZSa8EdX8S" #e.g. b!qYyq8c3L2a9
$itemId = "01EDVSQ7HDCJBEICXN3RDZNAPOYZMI6A7" #e.g. 01ZQY2X7Z6G2Q6Y2ZVQGZV5B2L5A3E4A

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
    return $config
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
documentation: https://learn.microsoft.com/en-us/graph/api/driveitem-list-permissions?view=graph-rest-1.0&tabs=http
API endpoint: GET /drives/{drive-id}/items/{item-id}/permissions
#>
function Get-DriveItemPermissions {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DriveId,
        
        [Parameter(Mandatory = $true)]
        [string]$ItemId,
        
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        
        [Parameter(Mandatory = $true)]
        [string]$GraphV1Host
    )
    
    $permissionsUrl = "${GraphV1Host}/drives/${DriveId}/items/${ItemId}/permissions"
    Write-Host "Fetching permissions from: $permissionsUrl"
    
    $permissionsResponse = Invoke-RestMethod -Method Get -Uri $permissionsUrl -Headers @{
        "Authorization" = "Bearer $AccessToken"
    }
    
    Write-Host "Permissions retrieved successfully"
    return $permissionsResponse
}




# Main script execution
Write-Host "Starting Script: List Permissions for Drive Item ${itemId}" -ForegroundColor Green
Write-Host "============================================"


# Configuration
$configPath = "C:\Projects\HowToInSharePoint\git\howtoinshsarepoint\GraphAPIV1\env.json"
$graphV1Host = "https://graph.microsoft.com/v1.0"

try {
    $config = $null
    if ( (Test-Path -Path $configPath)) {
        $config = Get-ConfigFromJson -ConfigPath $configPath
        Write-Host "Configuration loaded successfully"
        $clientId = $config.clientId
        $tenantId = $config.tenantId
        $clientSecret = $config.clientSecret
    }
       
    # Step 1: Get access token
    $accessToken = Get-AccessToken -TenantId $tenantId `
        -ClientId $clientId `
        -ClientSecret $clientSecret
    
    # Step 2: Get permissions for the item
    $permissionsResponse = Get-DriveItemPermissions -DriveId $driveId `
        -ItemId $itemId `
        -AccessToken $accessToken `
        -GraphV1Host $graphV1Host
    
    # Step 3: Display results
    Write-Host ""
    Write-Host "Permissions for Item: $itemId"
    Write-Host "=============================="
    $permissionsResponse.value | Format-Table -Property id, grantedTo, roles
    
    Write-Host ""
    Write-Host "Script completed successfully"
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}

