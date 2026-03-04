<#
docuementation: https://learn.microsoft.com/en-us/graph/api/message-list-attachments?view=graph-rest-1.0&tabs=http
API endpoint: /users/{id | userPrincipalName}/messages/{message-id}/attachments

Permission type	Permissions (from least to most privileged)
Delegated (work or school account)	Mail.Read
Delegated (personal Microsoft account)	Mail.Read
Application	Mail.Read
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


# Function to list attachments for a given message ID
function Get-MessageAttachments {   
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName,

        [Parameter(Mandatory = $true)]
        [string]$MessageId
    )
    
    $graphApiUrl = "https://graph.microsoft.com/v1.0/users/$UserPrincipalName/messages/$MessageId/attachments"
    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type"  = "application/json"
    }
    
    Write-Host "Calling GET $graphApiUrl"
    $attachments = Invoke-RestMethod -Method Get -Uri $graphApiUrl -Headers $headers
    
    Write-Host "Attachments retrieved successfully for message ID: $MessageId"
    $attachments.value | ForEach-Object {
        Write-Host -BackgroundColor Blue -ForegroundColor White "Attachment ID: $($_.id) | Name: $($_.name) | Size: $($_.size) bytes | Content Type: $($_.contentType)"
    }
    
    return $attachments
}

#Example usage:
$userUPN = "admin@MngEnvMCAP367749.onmicrosoft.com"
$messageId = "AAMkADVmMTE1ZmQ5LTA3MGQtNGFmZC1hZmMzLTAzZTQ5ZjJhZWM4MABGAAAAAADHVbFlUU2oToQaLmW08WKhBwA2mbNkqgqeRaMTlCjQG171AAAAAAEMAAA2mbNkqgqeRaMTlCjQG171AACjPmyaAAA="
$attachments = Get-MessageAttachments -AccessToken $accessToken -UserPrincipalName $userUPN -MessageId $messageId
