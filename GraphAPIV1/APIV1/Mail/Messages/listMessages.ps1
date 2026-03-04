<#
docuementation: https://learn.microsoft.com/en-us/graph/api/user-list-messages?view=graph-rest-1.0&tabs=http
API endpoint: /users/{id | userPrincipalName}/messages

Permission type	Least privileged permissions	Higher privileged permissions

Delegated (work or school account)	Mail.ReadBasic	Mail.ReadWrite, Mail.Read
Delegated (personal Microsoft account)	Mail.ReadBasic	Mail.ReadWrite, Mail.Read
Application	Mail.ReadBasic.All	Mail.ReadWrite, Mail.Read
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


# Function to list messages for a given user UPN
function Get-UserMessages {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName
    )
    
    $graphApiUrl = "https://graph.microsoft.com/v1.0/users/$UserPrincipalName/messages"
    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type"  = "application/json"
    }
    
    Write-Host "Calling GET $graphApiUrl"
    $messages = Invoke-RestMethod -Method Get -Uri $graphApiUrl -Headers $headers
    
    Write-Host "Messages retrieved successfully for user: $UserPrincipalName"
    $messages.value | ForEach-Object {
        Write-Host "Message ID: $($_.id) | Subject: $($_.subject) | From: $($_.from.emailAddress.address) | Received: $($_.receivedDateTime)"
    }
    
    return $messages
}


#Example usage:
$userUPN = "admin@MngEnvMCAP367749.onmicrosoft.com"
$messages = Get-UserMessages -AccessToken $accessToken -UserPrincipalName $userUPN




