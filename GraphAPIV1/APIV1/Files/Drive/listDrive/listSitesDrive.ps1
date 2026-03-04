
#documentation: https://learn.microsoft.com/en-us/graph/api/drive-list?view=graph-rest-1.0&tabs=http
# Configuration to be updated by user
$clientId = ""
$tenantId = ""
$clientSecret = ""
$sharePointHostname = "" #e.g. contoso.sharepoint.com
$siteServerRelativePath = "/sites/test1" #e.g. /sites/test1


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
Get site ID from SharePoint using Graph API
Documentation: https://learn.microsoft.com/en-us/graph/api/site-get?view=graph-rest-1.0&tabs=http
#>
function Get-SiteId {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SharePointHostname,
        
        [Parameter(Mandatory = $true)]
        [string]$SiteServerRelativePath,
        
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        
        [Parameter(Mandatory = $true)]
        [string]$GraphV1Host
    )
    
    $siteApiUrl = "${GraphV1Host}/sites/${SharePointHostname}:${SiteServerRelativePath}"
    Write-Host "Fetching site information from: $siteApiUrl"
    
    $siteResponse = Invoke-RestMethod -Method Get -Uri $siteApiUrl -Headers @{
        "Authorization" = "Bearer $AccessToken"
    }
    
    $siteId = $siteResponse.id
    Write-Host "Site ID retrieved: $siteId"
    return $siteId
}

<#
.SYNOPSIS
Get list of all drives for a SharePoint site
#>
function Get-SiteDrives {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteId,
        
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        
        [Parameter(Mandatory = $true)]
        [string]$GraphV1Host
    )
    
    $graphAPIListSiteDrives = "/sites/${SiteId}/drives"
    $API_ListSiteDrives = "${GraphV1Host}${graphAPIListSiteDrives}"
    
    Write-Host "Fetching all document libraries from: $API_ListSiteDrives"
    
    $drivesResponse = Invoke-RestMethod -Method Get -Uri $API_ListSiteDrives -Headers @{
        "Authorization" = "Bearer $AccessToken"
    }
    
    Write-Host "Document libraries retrieved successfully"
    return $drivesResponse
}


# Main script execution
Write-Host "Starting Script: List SharePoint Site Drives"
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
    
    # Step 2: Get site ID
    $siteId = Get-SiteId -SharePointHostname $sharePointHostname `
        -SiteServerRelativePath $siteServerRelativePath `
        -AccessToken $accessToken `
        -GraphV1Host $graphV1Host
    
    # Step 3: Get site drives
    $drivesResponse = Get-SiteDrives -SiteId $siteId `
        -AccessToken $accessToken `
        -GraphV1Host $graphV1Host
    
    # Step 4: Display results
    Write-Host ""
    Write-Host "Results:"
    Write-Host "--------"
    $drivesResponse.value | Format-Table -Property id, name, driveType
    
    Write-Host ""
    Write-Host "Script completed successfully"
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}

