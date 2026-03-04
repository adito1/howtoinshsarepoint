<#
docuementation: 
API endpoint:GET https://graph.microsoft.com/v1.0/sites/{hostname}:/{relative-path}

Permission type	Least privileged permissions	Higher privileged permissions
Delegated (work or school account)	Sites.Read.All	Sites.ReadWrite.All
Delegated (personal Microsoft account)	Not supported.	Not supported.
Application	Sites.Read.All	Sites.ReadWrite.All
#>
<#
.SYNOPSIS
    Get a SharePoint site resource by its path using Microsoft Graph API.

.DESCRIPTION
    This function retrieves site information from a SharePoint site using its hostname and relative path.
    API endpoint: GET https://graph.microsoft.com/v1.0/sites/{hostname}:/{relative-path}

.PARAMETER AccessToken
    The access token for authenticating with Microsoft Graph API.

.PARAMETER Hostname
    The hostname of the SharePoint tenant (e.g., "mngenvmcap367749.sharepoint.com").

.PARAMETER RelativePath
    The relative path to the site (e.g., "/sites/test4").

.EXAMPLE
    Get-SiteResourceByPath -AccessToken $token -Hostname "mngenvmcap367749.sharepoint.com" -RelativePath "/sites/test4"

.OUTPUTS
    Returns the site object with properties like id, displayName, description, webUrl, etc.
#>
function Get-SiteResourceByPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$Hostname,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type"  = "application/json"
    }

    # Build the URI - note the colon between hostname and relative path
    $uri = "https://graph.microsoft.com/v1.0/sites/$($Hostname):$($RelativePath)"

    try {
        Write-Host "Calling Microsoft Graph API: $uri" -ForegroundColor Cyan
        $result = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
        return $result
    }
    catch {
        Write-Error "Failed to get site resource: $_"
        throw
    }
}

# ============================================
# SAMPLE USAGE
# ============================================

$PSScriptRoot = "C:\Projects\HowToInSharePoint\git\howtoinshsarepoint\GraphAPIV1\APIV1"
# Source the configuration and authentication scripts
. "$PSScriptRoot\AuthenticationAndAuthorization\GetConfiguration.ps1"
. "$PSScriptRoot\AuthenticationAndAuthorization\ApplicationAccessToken.ps1"

# Get configuratio object from JSON file
$config = Get-ConfigFromJson 

$clientId = $config.clientId
$tenantId = $config.tenantId
$clientSecret = $config.clientSecret

$hostname = "mngenvmcap367749.sharepoint.com"
$relativePath = "/sites/test4"

# Get access token using the config
$accessToken = Get-ApplicationAccessToken -TenantId $tenantId -ClientId $clientId -ClientSecret $clientSecret

# Call the function for SPO site: https://mngenvmcap367749.sharepoint.com/sites/test4
$siteInfo = Get-SiteResourceByPath `
    -AccessToken $accessToken `
    -Hostname $hostname `
    -RelativePath $relativePath

# Display the results
Write-Host "`nSite Information:" -ForegroundColor Green
$siteInfo | Select-Object id, displayName, description, webUrl | Format-List




