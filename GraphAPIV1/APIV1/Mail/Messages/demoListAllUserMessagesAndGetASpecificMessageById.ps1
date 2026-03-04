<#
Demo script to list all user messages and get a specific message by ID
Uses functions from getMessage.ps1 and listMessages.ps1
#>
$PSScriptRoot = "C:\Projects\HowToInSharePoint\git\howtoinshsarepoint\GraphAPIV1\APIV1"

# Source the configuration and authentication scripts
. "$PSScriptRoot\Authentication\GetConfiguration.ps1"
. "$PSScriptRoot\Authentication\ApplicationAccessToken.ps1"

# Source the message functions
. "$PSScriptRoot\Mail\Messages\listMessages.ps1"
. "$PSScriptRoot\Mail\Messages\getMessage.ps1"

# Get configuration object from JSON file
$config = Get-ConfigFromJson 

$clientId = $config.clientId
$tenantId = $config.tenantId
$clientSecret = $config.clientSecret

# Get access token using the config
$accessToken = Get-ApplicationAccessToken -TenantId $tenantId -ClientId $clientId -ClientSecret $clientSecret

# Step 1: List all messages for a user
Write-Host "`n========== STEP 1: Listing All Messages ==========" -ForegroundColor Cyan
$userUPN = "admin@MngEnvMCAP367749.onmicrosoft.com"
$messages = Get-UserMessages -AccessToken $accessToken -UserPrincipalName $userUPN

# Step 2: Get a specific message by ID
if ($messages.value -and $messages.value.Count -gt 0) {
    Write-Host "`n========== STEP 2: Getting Specific Message ==========" -ForegroundColor Cyan
    $firstMessageId = $messages.value[0].id
    $specificMessage = Get-UserMessage -AccessToken $accessToken -UserPrincipalName $userUPN -MessageId $firstMessageId
}
else {
    Write-Host "`nNo messages found for user $userUPN" -ForegroundColor Yellow
}
