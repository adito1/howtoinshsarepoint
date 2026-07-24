
$configPath = "C:\Projects\HowToInSharePoint\git\hotwoinsharepoint\howtoinshsarepoint\GraphAPIV1\env.json"

$clientId = ""
$tenantId = ""
$clientSecret = ""
$certificatePath = ""
$certificatePassword = ""
$url = "https://mngenvmcap367749.sharepoint.com/sites/devteamsite/"


<#
.SYNOPSIS
Get configuration from JSON file
#>
function Get-ConfigFromJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )
    
    Write-Host "Loading configuration from: $ConfigPath"
    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    $global:clientId = $config.clientId
    $global:tenantId = $config.tenantId
    $global:clientSecret = $config.clientSecret
    $global:sharePointHostname = $config.sharePointHostname
    $global:certificatePath = $config.CertificatePath
    $global:certificatePassword = $config.CertificatePassword
    Write-Host "Configuration loaded successfully"
}

Get-ConfigFromJson -ConfigPath $configPath
Connect-PnPOnline -Url $url -ClientId $clientId  -Tenant $tenantId -CertificatePath $certificatePath