$tenantId = "15154ad7-be1f-4ec1-886f-403223210051"
$clientId = ""

# Ensure the Graph authentication module is available in the current session.
if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue)) {
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
}

# delegated connection
Connect-MgGraph -ClientId $clientId -TenantId $tenantId -Scopes "Sites.ReadWrite.All" -UseDeviceAuthentication -ErrorAction Stop

$context = Get-MgContext
if ($null -eq $context) {
    Write-Host "No Graph context found. Authentication did not complete or was canceled." -ForegroundColor Yellow
}
else {
    $context | Format-List
}

# Cleanup: end Graph session and clear sensitive values from this PowerShell session.
Disconnect-MgGraph -ErrorAction SilentlyContinue
Clear-Variable tenantId, clientId, context -ErrorAction SilentlyContinue
Remove-Variable tenantId, clientId, context -ErrorAction SilentlyContinue
