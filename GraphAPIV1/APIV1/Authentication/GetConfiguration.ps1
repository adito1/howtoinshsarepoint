<#
.SYNOPSIS
Get configuration from JSON file
#>
$configPath = "C:\Projects\HowToInSharePoint\git\howtoinshsarepoint\GraphAPIV1\env.json"
function Get-ConfigFromJson {
    
    Write-Host "Loading configuration from: $configPath"
    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    return $config
}
