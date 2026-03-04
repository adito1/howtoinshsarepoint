<#
docuementation: https://learn.microsoft.com/en-us/graph/api/message-get?view=graph-rest-1.0&tabs=http
API endpoint: GET /users/{user-id}/messages/{message-id}

Permission type	Permissions (from least to most privileged)
Delegated (work or school account)	Mail.ReadBasic, Mail.Read
Delegated (personal Microsoft account)	Mail.ReadBasic, Mail.Read
Application	Mail.ReadBasic.All, Mail.Read
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

<# 
Function to get a specific message for a user
API endpoint: GET /users/{user-id}/messages/{message-id}
#>
function Get-UserMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName,
        
        [Parameter(Mandatory = $true)]
        [string]$MessageId
    )
    
    $graphApiUrl = "https://graph.microsoft.com/v1.0/users/$UserPrincipalName/messages/$MessageId"
    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type"  = "application/json"
    }
    
    Write-Host "Calling GET $graphApiUrl" -ForegroundColor Yellow
    $message = Invoke-RestMethod -Method Get -Uri $graphApiUrl -Headers $headers
    
    Write-Host "Message retrieved successfully"
    Write-Host "Message ID: $($message.id)"
    Write-Host "Subject: $($message.subject)"
    Write-Host "From: $($message.from.emailAddress.address) ($($message.from.emailAddress.name))"
    Write-Host "Received: $($message.receivedDateTime)"
    Write-Host "Has Attachments: $($message.hasAttachments)"
    Write-Host "Body Preview: $($message.bodyPreview)"
    
    return $message
}

<# 
Function to get the MIME content of a message
API endpoint: GET /users/{id | userPrincipalName}/messages/{id}/$value
#>
function Get-UserMessageMimeContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName,
        
        [Parameter(Mandatory = $true)]
        [string]$MessageId,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputFilePath
    )
    
    $graphApiUrl = "https://graph.microsoft.com/v1.0/users/$UserPrincipalName/messages/$MessageId/`$value"
    $headers = @{
        "Authorization" = "Bearer $AccessToken"
    }
    
    Write-Host "Calling GET $graphApiUrl" -ForegroundColor Yellow
    $mimeContent = Invoke-RestMethod -Method Get -Uri $graphApiUrl -Headers $headers
    
    Write-Host "MIME content retrieved successfully"
    
    # Save to file if OutputFilePath is provided
    if ($OutputFilePath) {
        $mimeContent | Out-File -FilePath $OutputFilePath -Encoding ASCII
        Write-Host "MIME content saved to: $OutputFilePath"
    }
    
    return $mimeContent
}

# Example usage:
$userUPN = "admin@MngEnvMCAP367749.onmicrosoft.com"
$messageId = "AAMkADVmMTE1ZmQ5LTA3MGQtNGFmZC1hZmMzLTAzZTQ5ZjJhZWM4MABGAAAAAADHVbFlUU2oToQaLmW08WKhBwA2mbNkqgqeRaMTlCjQG171AAAAAAEMAAA2mbNkqgqeRaMTlCjQG171AACjPmyaAAA="
#$message = Get-UserMessage -AccessToken $accessToken -UserPrincipalName $userUPN -MessageId $messageId

# Get MIME content
$mimeContent = Get-UserMessageMimeContent -AccessToken $accessToken -UserPrincipalName $userUPN -MessageId $messageId -OutputFilePath "C:\tmp\messagePDF2.eml"
