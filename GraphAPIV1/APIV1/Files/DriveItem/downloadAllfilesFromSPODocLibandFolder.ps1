<#
#>

$clientId = ""
$tenantId = ""
$clientSecret = ""
$graphV1Host = "https://graph.microsoft.com/v1.0"
 
$sharePointHostname = "mngenvmcap367749.sharepoint.com" #e.g. contoso.sharepoint.com
$siteServerRelativePath = "/sites/test1" #e.g. /sites/test1
$documentLibraryName = "testDocLib" #e.g. Documents
$folderName = "folder1" #e.g. TestFolder

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

# Get access token using the config
$accessToken = Get-ApplicationAccessToken -TenantId $tenantId -ClientId $clientId -ClientSecret $clientSecret
<#

Get site ID from SharePoint using Graph API
Documentation: https://learn.microsoft.com/en-us/graph/api/site-get?view=graph-rest-1.0&tabs=http
#>
function Get-SiteId {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SharePointHostname,
        
        [Parameter(Mandatory = $true)]
        [string]$SiteServerRelativePath,
        
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        
        [Parameter(Mandatory = $true)]
        [string]$GraphV1Host
    )
    
    $siteApiUrl = "${GraphV1Host}/sites/${SharePointHostname}:${SiteServerRelativePath}"
    Write-Host "Fetching site information from: ${siteApiUrl}"
    
    $siteResponse = Invoke-RestMethod -Method Get -Uri $siteApiUrl -Headers @{
        "Authorization" = "Bearer $AccessToken"
    }
    
    $siteId = $siteResponse.id
    Write-Host "Site ID retrieved: $siteId"
    return $siteId
}

<#
.SYNOPSIS
Get list of all drives for a SharePoint site
#>
function Get-SiteDrives {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteId,
        
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        
        [Parameter(Mandatory = $true)]
        [string]$GraphV1Host
    )
    
    $graphAPIListSiteDrives = "/sites/${SiteId}/drives"
    $API_ListSiteDrives = "${GraphV1Host}${graphAPIListSiteDrives}"
    
    Write-Host "Fetching all document libraries from: $API_ListSiteDrives"
    
    $drivesResponse = Invoke-RestMethod -Method Get -Uri $API_ListSiteDrives -Headers @{
        "Authorization" = "Bearer $AccessToken"
    }
    
    Write-Host "Document libraries retrieved successfully"
    return $drivesResponse
}

<#
.SYNOPSIS
Enumerate and download all files from a SharePoint folder in a document library
#>
function Download-AllFilesFromSpoFolder {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DriveId,

        [Parameter(Mandatory = $true)]
        [string]$SpoFolderName,

        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$GraphV1Host,

        [Parameter(Mandatory = $true)]
        [string]$OutputRootPath
    )

    if (-not (Test-Path -LiteralPath $OutputRootPath)) {
        New-Item -ItemType Directory -Path $OutputRootPath | Out-Null
    }

    function Get-DriveChildren {
        param(
            [string]$CurrentFolderPath
        )

        $escapedPath = [Uri]::EscapeDataString($CurrentFolderPath)
        Write-Host "escapedPath: $escapedPath"
        $childrenUrl = "${GraphV1Host}/drives/${DriveId}/root:/${escapedPath}:/children"
        return Invoke-RestMethod -Method Get -Uri $childrenUrl -Headers @{ "Authorization" = "Bearer $AccessToken" }
    }

    function Download-FileByItemId {
        param(
            [string]$ItemId,
            [string]$DestinationPath
        )

        $downloadUrl = "${GraphV1Host}/drives/${DriveId}/items/${ItemId}/content"
        Invoke-WebRequest -Method Get -Uri $downloadUrl -Headers @{ "Authorization" = "Bearer $AccessToken" } -OutFile $DestinationPath
    }

    $folderQueue = New-Object System.Collections.Generic.Queue[System.String]
    $folderQueue.Enqueue($SpoFolderName)
    $downloadCount = 0

    while ($folderQueue.Count -gt 0) {
        $currentFolder = $folderQueue.Dequeue()
        Write-Host "Enumerating folder: $currentFolder"

        $itemsResponse = Get-DriveChildren -CurrentFolderPath $currentFolder
        foreach ($item in $itemsResponse.value) {
            if ($null -ne $item.folder) {
                $childFolderPath = "$currentFolder/$($item.name)"
                $folderQueue.Enqueue($childFolderPath)
            }
            elseif ($null -ne $item.file) {
                $graphParentPath = [string]$item.parentReference.path
                $prefix = "/drives/${DriveId}/root:/"
                $relativeFilePath = $graphParentPath -replace [regex]::Escape($prefix), ''
                $relativeFilePath = $relativeFilePath.TrimStart('/').Replace('/', [System.IO.Path]::DirectorySeparatorChar)

                if ([string]::IsNullOrWhiteSpace($relativeFilePath)) {
                    $localFolderPath = $OutputRootPath
                }
                else {
                    $localFolderPath = Join-Path $OutputRootPath $relativeFilePath
                }

                if (-not (Test-Path -LiteralPath $localFolderPath)) {
                    New-Item -ItemType Directory -Path $localFolderPath | Out-Null
                }

                $destinationFile = Join-Path $localFolderPath $item.name
                Write-Host "Downloading file: $($item.name)"
                Download-FileByItemId -ItemId $item.id -DestinationPath $destinationFile
                $downloadCount++
            }
        }
    }

    Write-Host "Total downloaded files: $downloadCount"
}

# Step 2: Get site ID
$siteId = Get-SiteId -SharePointHostname $sharePointHostname `
    -SiteServerRelativePath $siteServerRelativePath `
    -AccessToken $accessToken `
    -GraphV1Host $graphV1Host

# Step 3: Get site drives
$drivesResponse = Get-SiteDrives -SiteId $siteId `
    -AccessToken $accessToken `
    -GraphV1Host $graphV1Host

    
# Step 4: Display results
Write-Host ""
Write-Host "Results:"
Write-Host "--------"
$drivesResponse.value | Format-Table -Property id, name, driveType
    
Write-Host ""
Write-Host "Script completed successfully"

#Step 5: Find the drive ID for the specific document library
$targetDrive = $drivesResponse.value | Where-Object { $_.name -eq $documentLibraryName }
if ($null -ne $targetDrive) {
    Write-Host "Drive ID for document library '$documentLibraryName': $($targetDrive.id)"

    $downloadOutputPath = Join-Path -Path $PSScriptRoot -ChildPath "downloads"
    Download-AllFilesFromSpoFolder -DriveId $targetDrive.id `
        -SpoFolderName $folderName `
        -AccessToken $accessToken `
        -GraphV1Host $graphV1Host `
        -OutputRootPath $downloadOutputPath
}
else {
    Write-Host "Document library '$documentLibraryName' not found among the site drives."
}


