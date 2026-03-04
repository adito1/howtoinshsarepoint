<#
docuementation: https://learn.microsoft.com/en-us/graph/api/user-list?view=graph-rest-1.0&tabs=http
API endpoint: GET /users

Permission type	Permissions (from least to most privileged)
Delegated (work or school account)	User.ReadBasic.All, User.Read.All, User.ReadWrite.All, Directory.Read.All, Directory.ReadWrite.All
Delegated (personal Microsoft account)	Not supported.

Application	User.Read.All, User.ReadWrite.All, Directory.Read.All, Directory.ReadWrite.All
#>
$PSScriptRoot = "C:\Projects\HowToInSharePoint\git\howtoinshsarepoint\GraphAPIV1\APIV1"
# Source the configuration and authentication scripts
. "$PSScriptRoot\Authentication\GetConfiguration.ps1"
. "$PSScriptRoot\Authentication\ApplicationAccessToken.ps1"

# Get configuratio object  from JSON file
$config = Get-ConfigFromJson 

$clientId = $config.clientId
$tenantId = $config.tenantId
$clientSecret = $config.clientSecret

# Get access token using the config
$accessToken = Get-ApplicationAccessToken -TenantId $tenantId -ClientId $clientId -ClientSecret $clientSecret

#Write-Host "Access token obtained. Ready to call Graph API endpoints."
#Write-Host "Access Token: $($accessToken.Substring(0, 20))..." # Display first 20 chars for security

# Function to call GET /users endpoint
function Get-Users {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken
    )
    
    $graphApiUrl = "https://graph.microsoft.com/v1.0/users"
    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type"  = "application/json"
    }
    
    Write-Host "Calling GET $graphApiUrl"
    $users = Invoke-RestMethod -Method Get -Uri $graphApiUrl -Headers $headers
    
    Write-Host "Users retrieved successfully"
    $users.value | ForEach-Object {
        Write-Host "User ID: $($_.id) | Name: $($_.displayName) | UPN: $($_.userPrincipalName)"
    }
    
    return $users
}

# Function to retrieve a user by UPN
function Get-UserByUPN {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName
    )
    
    $graphApiUrl = "https://graph.microsoft.com/v1.0/users/$UserPrincipalName"
    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type"  = "application/json"
    }
    
    Write-Host "Calling GET $graphApiUrl"
    $user = Invoke-RestMethod -Method Get -Uri $graphApiUrl -Headers $headers
    
    Write-Host "User retrieved successfully"
    Write-Host "User ID: $($user.id) | Name: $($user.displayName) | UPN: $($user.userPrincipalName) | Email: $($user.mail)"
    
    return $user
}

# Call the function
$users = Get-Users -AccessToken $accessToken

# Example: Get a specific user by UPN
$specificUser = Get-UserByUPN -AccessToken $accessToken -UserPrincipalName "admin@MngEnvMCAP367749.onmicrosoft.com"

$specificUser 

