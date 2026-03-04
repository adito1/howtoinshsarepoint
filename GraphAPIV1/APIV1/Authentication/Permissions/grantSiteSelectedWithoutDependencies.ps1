$tenantId = ""
$clientId = ""
$clientSecret = ""
$permissions = "read" # possible values are : "read", "write", "owner", "fullcontrol"
$hostname = "yourTenant.sharepoint.com" # change to your tenant's hostname
$relativePath = "/sites/site1" # change to your site's relative path



<#
.SYNOPSIS
    Grants selected permissions to an application for a specific SharePoint site.

.DESCRIPTION
    This function grants Sites.Selected permissions to a target application for a specific SharePoint site using Microsoft Graph API.
    Documentation: https://learn.microsoft.com/en-us/graph/api/site-list-permissions?view=graph-rest-1.0&tabs=http
    API endpoint: /sites/{site-id}/permissions

.PARAMETER AccessToken
    The access token for authenticating with Microsoft Graph API.

.PARAMETER ClientId
    The client ID (application ID) of the target application that will receive the permissions.

.PARAMETER DisplayName
    The display name for the permission grant (e.g., "grant read permissions to target application").

.PARAMETER SiteId
    The ID of the SharePoint site where permissions will be granted.

.PARAMETER Roles
    The roles to grant. Default is "read". Valid values are "read", "write", "owner", or "fullcontrol".

.EXAMPLE
    Grant-SiteSelectedPermissions -AccessToken $token -ClientId "c9d11591-e575-4f81-bcce-353d0dfab860" -DisplayName "Target Application Permission" -SiteId "5b3bf646-177c-4415-a71d-57ffc956fd2c"

.EXAMPLE
    Grant-SiteSelectedPermissions -AccessToken $token -ClientId "c9d11591-e575-4f81-bcce-353d0dfab860" -DisplayName "Target App - Full Control" -SiteId "5b3bf646-177c-4415-a71d-57ffc956fd2c" -Roles "write"

.OUTPUTS
    Returns the permission object created by Microsoft Graph API.
#>
function Grant-SiteSelectedPermissions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$ClientId,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter(Mandatory = $true)]
        [string]$SiteId,

        [Parameter()]
        [ValidateSet("read", "write", "owner", "fullcontrol")]
        [string]$Roles
    )

    if ([string]::IsNullOrWhiteSpace($Roles)) {
        $Roles = "read"
    }

    # Grant Sites.Selected permission
    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type"  = "application/json"
    }
 
    $body = @{
        roles               = @($Roles)
        grantedToIdentities = @(
            @{
                application = @{
                    id          = $ClientId
                    displayName = $DisplayName
                }
            }
        )
    } | ConvertTo-Json -Depth 10

    try {
        $result = Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/v1.0/sites/$SiteId/permissions" -Headers $headers -Body $body
        Write-Host "Permissions granted successfully" -BackgroundColor Green
        Write-Host $result
        return $result
    }
    catch {
        Write-Error "Failed to grant permissions: $_"
        throw
    }
}

<#
.SYNOPSIS
Get all assigned site permissions for a specific application (clientId).

.DESCRIPTION
Calls Microsoft Graph API to list all permissions for a site, then filters
the result to only permissions granted to the provided clientId.

.PARAMETER AccessToken
The access token for authenticating with Microsoft Graph API.

.PARAMETER SiteId
The ID of the SharePoint site.

.PARAMETER ClientId
The client ID (application ID) to filter permissions for.

.OUTPUTS
Returns matching permission objects.
#>
function Get-SiteSelectedPermissionsByClientId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$SiteId,

        [Parameter(Mandatory = $true)]
        [string]$ClientId
    )

    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type"  = "application/json"
    }

    try {
        $response = Invoke-RestMethod -Method Get -Uri "https://graph.microsoft.com/v1.0/sites/$SiteId/permissions" -Headers $headers

        $matchingPermissions = @($response.value | Where-Object {
                $permission = $_

                $hasMatchInV1 = $false
                if ($permission.grantedToIdentities) {
                    $hasMatchInV1 = @($permission.grantedToIdentities | Where-Object {
                            $_.application -and $_.application.id -eq $ClientId
                        }).Count -gt 0
                }

                $hasMatchInV2 = $false
                if ($permission.grantedToIdentitiesV2) {
                    $hasMatchInV2 = @($permission.grantedToIdentitiesV2 | Where-Object {
                            $_.application -and $_.application.id -eq $ClientId
                        }).Count -gt 0
                }

                $hasMatchInV1 -or $hasMatchInV2
            })

        return $matchingPermissions
    }
    catch {
        Write-Error "Failed to get site permissions for clientId '$ClientId': $_"
        throw
    }
}


<#
.SYNOPSIS
Get access token from Microsoft identity provider
#>
function Get-ApplicationAccessToken {
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
    
    Write-Host "Access token obtained successfully" -BackgroundColor Green 
    return $tokenResponse.access_token
}



$accessToken = Get-ApplicationAccessToken -TenantId $tenantId -ClientId $clientId -ClientSecret $clientSecret


$siteInfo = Get-SiteResourceByPath `
    -AccessToken $accessToken `
    -Hostname $hostname `
    -RelativePath $relativePath

# Display the results
Write-Host "`nSite Information:" -ForegroundColor Green
$siteInfo | Select-Object id, displayName, description, webUrl | Format-List

$displayName = "grant $permissions permissions to $clientId for site $($siteInfo.displayName)"

<#
# Then call the function
$result = Grant-SiteSelectedPermissions `
    -AccessToken $accessToken `
    -ClientId $clientId  `
    -DisplayName $displayName `
    -SiteId $siteInfo.id `
    -Roles $permissions


$result | Select-Object id, roles, grantedToIdentitiesV2, grantedToIdentities | Format-List
#>

$assignedPermissions = Get-SiteSelectedPermissionsByClientId `
    -AccessToken $accessToken `
    -SiteId $siteInfo.id `
    -ClientId $clientId

Write-Host "`nPermissions assigned to clientId '$clientId':" -ForegroundColor Green
$assignedPermissions | Select-Object id, roles, name, grantedToIdentitiesV2, grantedToIdentities | Format-List
    

