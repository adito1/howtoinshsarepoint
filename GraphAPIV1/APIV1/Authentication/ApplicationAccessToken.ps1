
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
    
    Write-Host "Access token obtained successfully"
    return $tokenResponse.access_token
}
