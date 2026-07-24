<#
docuementation: https://learn.microsoft.com/en-us/graph/add-properties-profilecard
API endpoint: https://graph.microsoft.com/v1.0/admin/people/profileCardProperties


#>


$PSScriptRoot = "C:\Projects\HowToInSharePoint\git\hotwoinsharepoint\howtoinshsarepoint\GraphAPIV1\APIV1"
$PSScriptRoot 
# Source the configuration and authentication scripts
. "$PSScriptRoot\Authentication\GetConfiguration.ps1"
. "$PSScriptRoot\Authentication\ApplicationAccessToken.ps1"

function Add-ProfileCardCustomPropertyLocalized {
    <#
	.SYNOPSIS
	Adds one custom profile card property with English, French, and Italian labels.

	.PARAMETER AccessToken
	Microsoft Graph application access token.

	.PARAMETER DirectoryPropertyName
	Custom attribute name (for example: CustomAttribute1 ... CustomAttribute15).

	.PARAMETER EnglishDisplayName
	Default label shown when no localization applies.

	.PARAMETER FrenchDisplayName
	Label for French users.

	.PARAMETER ItalianDisplayName
	Label for Italian users.
	#>
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^CustomAttribute(1[0-5]|[1-9])$')]
        [string]$DirectoryPropertyName,

        [Parameter(Mandatory = $true)]
        [string]$EnglishDisplayName,

        [Parameter(Mandatory = $true)]
        [string]$FrenchDisplayName,

        [Parameter(Mandatory = $true)]
        [string]$ItalianDisplayName
    )

    $uri = "https://graph.microsoft.com/v1.0/admin/people/profileCardProperties"
    $headers = @{
        Authorization  = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }

    $body = @{
        directoryPropertyName = $DirectoryPropertyName
        annotations           = @(
            @{
                displayName   = $EnglishDisplayName
                localizations = @(
                    @{
                        languageTag = "fr"
                        displayName = $FrenchDisplayName
                    },
                    @{
                        languageTag = "it"
                        displayName = $ItalianDisplayName
                    }
                )
            }
        )
    } | ConvertTo-Json -Depth 6

    try {
        Write-Host "Adding profile card property '$DirectoryPropertyName'..." -ForegroundColor Cyan
        $result = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body
        Write-Host "Profile card property added successfully." -ForegroundColor Green
        return $result
    }
    catch {
        Write-Error "Failed to add profile card property '$DirectoryPropertyName'. Error: $($_.Exception.Message)"
        throw
    }
}

# Get configuratio object  from JSON file
$config = Get-ConfigFromJson 

$clientId = $config.clientId
$tenantId = $config.tenantId
$clientSecret = $config.clientSecret

# Get access token using the config
$accessToken = Get-ApplicationAccessToken -TenantId $tenantId -ClientId $clientId -ClientSecret $clientSecret

$profileCardProperty = Add-ProfileCardCustomPropertyLocalized `
    -AccessToken $accessToken `
    -DirectoryPropertyName "CustomAttribute1" `
    -EnglishDisplayName "Cost center" `
    -FrenchDisplayName "Centre de cout" `
    -ItalianDisplayName "Centro di costo"

$profileCardProperty | ConvertTo-Json -Depth 6
