
$tenantId = "15154ad7-be1f-4ec1-886f-403223210051" #"<tenant-id>"
$clientId = "a439d6aa-44d8-423e-9cef-b361a367fbb9" #"<admin-app-client-id>"
$clientSecret = "" #"<secret>"
$targetAppId = "a439d6aa-44d8-423e-9cef-b361a367fbb9" #"<target-app-client-id>"


$permissions = "write" # possible values are : "read", "write"
$hostname = "mngenvmcap367749.sharepoint.com" # change to your tenant's hostname
$relativePath = "/sites/test1" # change to your site's relative path yourTenant.sharepoint.com/sites/site1
$documentLibraryName = "2607210030007364" # change to your document library's name
$graphV1Host = "https://graph.microsoft.com/v1.0"

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
    #$uri = "https://graph.microsoft.com/v1.0/sites/$($Hostname):$($RelativePath)"
    $uri = "$graphV1Host/sites/$($Hostname):$($RelativePath)"

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

<#
.SYNOPSIS
    Get all lists for a SharePoint site.

.DESCRIPTION
    Retrieves all lists from a SharePoint site using Microsoft Graph API.
    API endpoint: GET https://graph.microsoft.com/v1.0/sites/{siteId}/lists

.PARAMETER SiteId
    The ID of the SharePoint site.

.PARAMETER AccessToken
    The access token for authenticating with Microsoft Graph API.

.EXAMPLE
    Get-SiteLists -SiteId $siteId -AccessToken $token
#>
function Get-SiteLists {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SiteId,

        [Parameter(Mandatory = $true)]
        [string]$AccessToken
    )

    $uri = "$graphV1Host/sites/$SiteId/lists"

    Write-Host "Fetching all lists from site '$SiteId'..." -ForegroundColor Cyan

    try {
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers @{
            "Authorization" = "Bearer $AccessToken"
        }
        Write-Host "Lists retrieved successfully."
        return $response
    }
    catch {
        Write-Error "Failed to retrieve site lists: $_"
        throw
    }
}

<#
.SYNOPSIS
    Grant permission on a SharePoint list to a target application.

.DESCRIPTION
    Grants the specified roles to an application on a SharePoint list using Microsoft Graph API.
    API endpoint: POST https://graph.microsoft.com/v1.0/sites/{siteId}/lists/{listId}/permissions

.PARAMETER AccessToken
    The access token for authenticating with Microsoft Graph API.

.PARAMETER SiteId
    The ID of the SharePoint site.

.PARAMETER ListId
    The ID of the SharePoint list.

.PARAMETER TargetAppId
    The client/application ID of the app to grant permissions to.

.PARAMETER Roles
    An array of roles to grant (e.g. "read", "write").

.EXAMPLE
    Grant-ListPermission -AccessToken $token -SiteId $siteId -ListId $listId -TargetAppId $appId -Roles @("write")
#>
function Grant-ListPermission {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$SiteId,

        [Parameter(Mandatory = $true)]
        [string]$ListId,

        [Parameter(Mandatory = $true)]
        [string]$TargetAppId,

        [Parameter(Mandatory = $true)]
        [string[]]$Roles = @("write")
    )

    $body = @{
        roles     = $Roles
        grantedTo = @{
            application = @{
                id = $TargetAppId
            }
        }
    } | ConvertTo-Json -Depth 10

    $uri = "$graphV1Host/sites/$SiteId/lists/$ListId/permissions"

    Write-Host "Granting permission on list '$ListId' to application '$TargetAppId'..." -ForegroundColor Cyan

    try {
        $result = Invoke-RestMethod `
            -Method POST `
            -Headers @{ "Authorization" = "Bearer $AccessToken"; "Content-Type" = "application/json" } `
            -Uri $uri `
            -Body $body

        Write-Host "Permission granted successfully." -BackgroundColor Green
        return $result
    }
    catch {
        Write-Error "Failed to grant list permission: $_"
        throw
    }
}

<#
.SYNOPSIS
    Retrieve and display permissions on a SharePoint list.

.DESCRIPTION
    Lists all permissions assigned to a SharePoint list using Microsoft Graph API.
    API endpoint: GET https://graph.microsoft.com/v1.0/sites/{siteId}/lists/{listId}/permissions

.PARAMETER AccessToken
    The access token for authenticating with Microsoft Graph API.

.PARAMETER SiteId
    The ID of the SharePoint site.

.PARAMETER ListId
    The ID of the SharePoint list.

.EXAMPLE
    Get-ListPermissions -AccessToken $token -SiteId $siteId -ListId $listId
#>
function Get-ListPermissions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$SiteId,

        [Parameter(Mandatory = $true)]
        [string]$ListId
    )

    $uri = "$graphV1Host/sites/$SiteId/lists/$ListId/permissions"

    Write-Host "Verifying permissions on list '$ListId'..." -ForegroundColor Cyan

    try {
        $response = Invoke-RestMethod `
            -Method GET `
            -Headers @{ "Authorization" = "Bearer $AccessToken"; "Content-Type" = "application/json" } `
            -Uri $uri

        $response.value | Select-Object id, roles, grantedTo
        return $response
    }
    catch {
        Write-Error "Failed to retrieve list permissions: $_"
        throw
    }
}

<#
.SYNOPSIS
    Delete a specific permission from a SharePoint list.

.DESCRIPTION
    Removes a permission entry from a SharePoint list by its permission ID using Microsoft Graph API.
    API endpoint: DELETE https://graph.microsoft.com/v1.0/sites/{siteId}/lists/{listId}/permissions/{permissionId}

.PARAMETER AccessToken
    The access token for authenticating with Microsoft Graph API.

.PARAMETER SiteId
    The ID of the SharePoint site.

.PARAMETER ListId
    The ID of the SharePoint list.

.PARAMETER PermissionId
    The ID of the permission to delete. Use Get-ListPermissions to retrieve permission IDs.

.EXAMPLE
    Remove-ListPermission -AccessToken $token -SiteId $siteId -ListId $listId -PermissionId "aToB..."
#>
function Remove-ListPermission {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$SiteId,

        [Parameter(Mandatory = $true)]
        [string]$ListId,

        [Parameter(Mandatory = $true)]
        [string]$PermissionId
    )

    $uri = "$graphV1Host/sites/$SiteId/lists/$ListId/permissions/$PermissionId"

    Write-Host "Deleting permission '$PermissionId' from list '$ListId'..." -ForegroundColor Cyan

    try {
        Invoke-RestMethod `
            -Method DELETE `
            -Headers @{ "Authorization" = "Bearer $AccessToken" } `
            -Uri $uri

        Write-Host "Permission '$PermissionId' deleted successfully." -BackgroundColor Green
    }
    catch {
        Write-Error "Failed to delete list permission: $_"
        throw
    }
}

# Main script execution
Write-Host "Starting Script: Add SharePoint List Permissions to Target Application"
Write-Host "============================================"
$accessToken = Get-ApplicationAccessToken -TenantId $tenantId -ClientId $clientId -ClientSecret $clientSecret


$siteInfo = Get-SiteResourceByPath `
    -AccessToken $accessToken `
    -Hostname $hostname `
    -RelativePath $relativePath

# Display the results
Write-Host "`nSite Information:" -ForegroundColor Green
$siteInfo | Select-Object id, displayName, description, webUrl | Format-List


$siteId = $siteInfo.id

# Step 3: Get site drives
$drivesResponse = Get-SiteDrives -SiteId $siteId `
    -AccessToken $accessToken `
    -GraphV1Host $graphV1Host
        
# Step 4: Display results
Write-Host ""
Write-Host "Results:"
Write-Host "--------"
$drivesResponse.value | Format-Table -Property id, name, driveType

# Step 5: Get all lists on the site and display them
$listsResponse = Get-SiteLists -SiteId $siteId -AccessToken $accessToken

Write-Host ""
Write-Host "Available Lists:"
Write-Host "----------------"
$listsResponse.value | Format-Table -Property id, displayName, @{Name = 'webUrl'; Expression = { $_.webUrl } }

# Set the list name you want to grant permissions on

$targetList = $listsResponse.value | Where-Object { $_.displayName -eq $documentLibraryName }

if (-not $targetList) {
    Write-Error "List '$documentLibraryName' not found on site. Check the Available Lists output above."
    exit 1
}

$listId = $targetList.id
Write-Host "Resolved list id for '$documentLibraryName': $listId" -ForegroundColor Green

<#
# Step 5: Grant permission to the target application
#>
Grant-ListPermission `
    -AccessToken $accessToken `
    -SiteId $siteId `
    -ListId $listId `
    -TargetAppId $targetAppId `
    -Roles @($permissions)


# Step 6: Verify the permission
Get-ListPermissions `
    -AccessToken $accessToken `
    -SiteId $siteId `
    -ListId $listId

<#
# Step 7 (Optional): Remove the permission if needed
$permissionIdToRemove = "aTowaS50fG1zLnNwLmV4dHxhNDM5ZDZhYS00NGQ4LTQyM2UtOWNlZi1iMzYxYTM2N2ZiYjlAMTUxNTRhZDctYmUxZi00ZWMxLTg4NmYtNDAzMjIzMjEwMDUx" # Replace with the actual permission ID you want to remove
Remove-ListPermission `
    -AccessToken $accessToken `
    -SiteId $siteId `
    -ListId $listId `
    -PermissionId $permissionIdToRemove
#>