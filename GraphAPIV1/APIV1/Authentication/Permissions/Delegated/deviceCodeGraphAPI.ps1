<#
.SYNOPSIS
    PowerShell implementation of Device Code authentication and SharePoint list operations using Microsoft Graph API.

.DESCRIPTION
    This script provides functions to authenticate using Device Code flow and interact with SharePoint lists via Microsoft Graph API.
    Converted from C# code that uses Microsoft.Identity.Client (MSAL).
#>

<#
.SYNOPSIS
    Authenticate using Device Code flow to get an access token.

.DESCRIPTION
    Initiates a Device Code authentication flow where the user opens a browser, navigates to a URL, and enters a code.
    This is useful for command-line scripts or scenarios where interactive login is needed without a web server.

.PARAMETER TenantId
    The Azure AD tenant ID (e.g., "15154ad7-be1f-4ec1-886f-403223210051" or "mngenvmcap367749.onmicrosoft.com").

.PARAMETER ClientId
    The application (client) ID from Azure AD app registration.

.PARAMETER Scopes
    Array of permission scopes to request (e.g., @("Sites.Selected", "Sites.Read.All")).

.EXAMPLE
    $token = Get-AccessTokenWithDeviceCode -TenantId "15154ad7-be1f-4ec1-886f-403223210051" -ClientId "79f224e5-1624-455b-a219-1be8560631dc" -Scopes @("Sites.Selected")

.OUTPUTS
    Returns the access token string.
#>
function Get-AccessTokenWithDeviceCode {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$ClientId,

        [Parameter(Mandatory = $true)]
        [string[]]$Scopes
    )

    $scopeString = $Scopes -join " "
    
    # Device code authentication endpoint
    $deviceCodeUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/devicecode"
    $tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

    # Request device code
    $deviceCodeBody = @{
        client_id = $ClientId
        scope     = $scopeString
    }

    Write-Host "Requesting device code..." -ForegroundColor Cyan
    $deviceCodeResponse = Invoke-RestMethod -Method Post -Uri $deviceCodeUrl -Body $deviceCodeBody

    # Display the message to the user
    Write-Host "`n$($deviceCodeResponse.message)" -ForegroundColor Yellow
    Write-Host "`nWaiting for authentication..." -ForegroundColor Cyan

    # Poll for the token
    $interval = $deviceCodeResponse.interval
    $expiresIn = $deviceCodeResponse.expires_in
    $deviceCode = $deviceCodeResponse.device_code

    $tokenBody = @{
        grant_type  = "urn:ietf:params:oauth:grant-type:device_code"
        client_id   = $ClientId
        device_code = $deviceCode
    }

    $startTime = Get-Date
    while ($true) {
        Start-Sleep -Seconds $interval

        try {
            $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $tokenBody -ErrorAction Stop
            Write-Host "`nAuthentication successful!" -ForegroundColor Green
            return $tokenResponse.access_token
        }
        catch {
            $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json
            
            if ($errorResponse.error -eq "authorization_pending") {
                # Still waiting for user to authenticate
                Write-Host "." -NoNewline -ForegroundColor Gray
            }
            elseif ($errorResponse.error -eq "authorization_declined") {
                throw "Authentication was declined by the user."
            }
            elseif ($errorResponse.error -eq "expired_token") {
                throw "The device code has expired. Please try again."
            }
            else {
                throw "Authentication failed: $($errorResponse.error_description)"
            }
        }

        # Check if we've exceeded the expiration time
        if (((Get-Date) - $startTime).TotalSeconds -gt $expiresIn) {
            throw "Authentication timed out. Please try again."
        }
    }
}

<#
.SYNOPSIS
    Get a SharePoint site ID by its hostname and path.

.PARAMETER AccessToken
    The access token for Microsoft Graph API.

.PARAMETER SiteHostname
    The SharePoint hostname (e.g., "mngenvmcap367749.sharepoint.com").

.PARAMETER SitePath
    The site path (e.g., "/sites/test5").

.EXAMPLE
    $siteId = Get-GraphSiteId -AccessToken $token -SiteHostname "mngenvmcap367749.sharepoint.com" -SitePath "/sites/test5"

.OUTPUTS
    Returns the site ID string.
#>
function Get-GraphSiteId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$SiteHostname,

        [Parameter(Mandatory = $true)]
        [string]$SitePath
    )

    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type"  = "application/json"
    }

    $siteUrl = "https://graph.microsoft.com/v1.0/sites/$($SiteHostname):$($SitePath)"
    
    try {
        Write-Host "Getting site ID for $SiteHostname$SitePath..." -ForegroundColor Cyan
        $siteResponse = Invoke-RestMethod -Method Get -Uri $siteUrl -Headers $headers
        Write-Host "Site ID: $($siteResponse.id)" -ForegroundColor Green
        return $siteResponse.id
    }
    catch {
        Write-Error "Failed to get site ID: $_"
        throw
    }
}

<#
.SYNOPSIS
    Get a SharePoint list ID by its display name.

.PARAMETER AccessToken
    The access token for Microsoft Graph API.

.PARAMETER SiteId
    The site ID where the list is located.

.PARAMETER ListName
    The display name of the list (e.g., "list1").

.EXAMPLE
    $listId = Get-GraphListId -AccessToken $token -SiteId $siteId -ListName "list1"

.OUTPUTS
    Returns the list ID string.
#>
function Get-GraphListId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$SiteId,

        [Parameter(Mandatory = $true)]
        [string]$ListName
    )

    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type"  = "application/json"
    }

    $listUrl = "https://graph.microsoft.com/v1.0/sites/$SiteId/lists/$ListName"
    
    try {
        Write-Host "Getting list ID for '$ListName'..." -ForegroundColor Cyan
        $listResponse = Invoke-RestMethod -Method Get -Uri $listUrl -Headers $headers
        Write-Host "List ID: $($listResponse.id)" -ForegroundColor Green
        return $listResponse.id
    }
    catch {
        Write-Error "Failed to get list ID: $_"
        throw
    }
}

<#
.SYNOPSIS
    Get all items from a SharePoint list with their field values.

.PARAMETER AccessToken
    The access token for Microsoft Graph API.

.PARAMETER SiteId
    The site ID where the list is located.

.PARAMETER ListId
    The ID of the list.

.EXAMPLE
    $items = Get-GraphListItems -AccessToken $token -SiteId $siteId -ListId $listId

.OUTPUTS
    Returns an array of list items with their field values.
#>
function Get-GraphListItems {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$SiteId,

        [Parameter(Mandatory = $true)]
        [string]$ListId
    )

    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type"  = "application/json"
    }

    $itemsUrl = "https://graph.microsoft.com/v1.0/sites/$SiteId/lists/$ListId/items?expand=fields"
    
    try {
        Write-Host "Getting list items..." -ForegroundColor Cyan
        $itemsResponse = Invoke-RestMethod -Method Get -Uri $itemsUrl -Headers $headers
        return $itemsResponse.value
    }
    catch {
        Write-Error "Failed to get list items: $_"
        throw
    }
}

<#
.SYNOPSIS
    Display list items in a formatted way.

.PARAMETER Items
    The array of list items to display.

.PARAMETER ListName
    The name of the list (for display purposes).
#>
function Show-ListItems {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array]$Items,

        [Parameter(Mandatory = $false)]
        [string]$ListName = "List"
    )

    Write-Host "`nItems in list '$ListName':" -ForegroundColor Green
    Write-Host "=============================" -ForegroundColor Green

    foreach ($item in $Items) {
        Write-Host "`nID: $($item.id)" -ForegroundColor Yellow
        
        if ($item.fields) {
            foreach ($field in $item.fields.PSObject.Properties) {
                Write-Host "  $($field.Name): $($field.Value)" -ForegroundColor White
            }
        }
        Write-Host "-----------" -ForegroundColor Gray
    }
}


# Configuration - Replace with your values
$tenantId = ""
$clientId = ""
$scopes = @("Sites.Selected")

# SPO site and list details
$siteHostname = "yoursharepointTenant.sharepoint.com"
$sitePath = "/sites/site6"
$listName = "list1"

try {
    # 1. Authenticate using Device Code flow
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "Step 1: Authentication" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    $accessToken = Get-AccessTokenWithDeviceCode -TenantId $tenantId -ClientId $clientId -Scopes $scopes

    # 2. Get Site ID
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "Step 2: Get Site ID" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    $siteId = Get-GraphSiteId -AccessToken $accessToken -SiteHostname $siteHostname -SitePath $sitePath

    # 3. Get List ID
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "Step 3: Get List ID" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    $listId = Get-GraphListId -AccessToken $accessToken -SiteId $siteId -ListName $listName

    # 4. Get List Items
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "Step 4: Get List Items" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    $items = Get-GraphListItems -AccessToken $accessToken -SiteId $siteId -ListId $listId

    # 5. Display Items
    Show-ListItems -Items $items -ListName $listName

    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "Completed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
}
catch {
    Write-Host "`nError occurred: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}
