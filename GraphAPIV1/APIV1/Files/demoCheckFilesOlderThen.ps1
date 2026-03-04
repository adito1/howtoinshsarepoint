<#
Graph-only scan for files not modified in the last 3 and 5 years across the target sites.
- Discovers/reads via Microsoft Graph only (no CSOM/SharePoint REST)
- Expects you've already granted Sites.Selected -> Read to your app on those sites
- Writes: DFF_InactiveFiles_3yrs.csv, DFF_InactiveFiles_5yrs.csv, DFF_InactiveFiles_Summary.csv
#>
 
param(
  [Parameter(Mandatory = $true)] [string] $TenantId,        # e.g. a6cfdf05-9838-4d88-948d-b2eba70bdf3a
  [Parameter(Mandatory = $true)] [string] $ClientId,        # e2e823b1-b3ea-4ecf-9058-5007cc176e7a
  [Parameter(Mandatory = $true)] [string] $ClientSecret,    # rotated secret
  [Parameter(Mandatory = $true)] [string] $SitesFile,       # path to sites.txt (one URL per line)
  [int] $MaxSites = 50,
  [int] $PageSize = 200,                                  # Graph page size for listItems
  [string] $OutputFolder = ".\DFF_Reports"
)

$ErrorActionPreference = 'Stop'
 
# --- Helper: Graph token (application) ---
function Get-GraphToken([string]$TenantId, [string]$ClientId, [string]$ClientSecret) {
  (Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Body @{
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = 'https://graph.microsoft.com/.default'
    grant_type    = 'client_credentials'
  } -ContentType 'application/x-www-form-urlencoded').access_token
}
 
# --- Helper: backoff retry for Graph calls ---
function Invoke-Graph([string]$Uri, [hashtable]$Headers, [string]$Method = 'GET', $Body = $null) {
  $attempt = 0
  while ($true) {
    try {
      $attempt++
      if ($Body -ne $null) {
        return Invoke-RestMethod -Headers $Headers -Method $Method -Uri $Uri -Body $Body -ContentType 'application/json' -ErrorAction Stop
      }
      else {
        return Invoke-RestMethod -Headers $Headers -Method $Method -Uri $Uri -ErrorAction Stop
      }
    }
    catch {
      $status = $_.Exception.Response.StatusCode.value__
      $msg = $_.Exception.Message
      if (($status -eq 429 -or $status -eq 503 -or $msg -match 'Too Many Requests') -and $attempt -lt 8) {
        $delay = [Math]::Min([Math]::Pow(2, $attempt) * 2, 60)
        Write-Host "Graph throttled ($status). Sleeping $delay s ..." -ForegroundColor Yellow
        Start-Sleep -Seconds $delay
        continue
      }
      throw
    }
  }
}
 
# --- Prepare token/headers ---
$graphToken = Get-GraphToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
$H = @{ Authorization = "Bearer $graphToken"; 'ConsistencyLevel' = 'eventual' }
#Write-Host "Graph token acquired." -ForegroundColor Green

# --- Load sites list ---
if (-not (Test-Path $SitesFile)) { throw "Sites file not found: $SitesFile" }

$allSites = Get-Content $SitesFile | Where-Object {
  $_ -and $_.Trim().Length -gt 0 #-and $_ -match '^https://[^/]+\.sharepoint\.com/(sites|teams)/'
} | ForEach-Object { $_.Trim() } | Select-Object -Unique
if ($MaxSites -gt 0) { 
  $allSites = $allSites | Select-Object -First $MaxSites 
}
Write-Host ("Sites to process: {0}" -f $allSites.Count) -ForegroundColor Cyan
 
# --- Output prep ---
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
$detailsCsv3 = Join-Path $OutputFolder "DFF_InactiveFiles_3yrs.csv"
$detailsCsv5 = Join-Path $OutputFolder "DFF_InactiveFiles_5yrs.csv"
$summaryCsv = Join-Path $OutputFolder "DFF_InactiveFiles_Summary.csv"
 
"SiteUrl,LibraryTitle,ItemWebUrl,Path,FileName,LastModifiedUtc,SizeBytes,SizeMB" | Out-File -FilePath $detailsCsv3 -Encoding utf8
"SiteUrl,LibraryTitle,ItemWebUrl,Path,FileName,LastModifiedUtc,SizeBytes,SizeMB" | Out-File -FilePath $detailsCsv5 -Encoding utf8
 
# --- Cutoffs ---
#$cutoff3 = (Get-Date).AddYears(-3)
$cutoff3 = (Get-Date).AddYears(-1)
$cutoff5 = (Get-Date).AddYears(-5)

# --- Iterate sites ---
$siteIndex = 0
foreach ($siteUrl in $allSites) {
  $siteIndex++
  Write-Host ("[{0}/{1}] {2}" -f $siteIndex, $allSites.Count, $siteUrl) -ForegroundColor Green
  try {
    # Resolve site id
    $u = [Uri]$siteUrl
    $url = "https://graph.microsoft.com/v1.0/sites/$($u.Host):$($u.AbsolutePath)"  
    Write-Host (" Resolving site id for: {0}" -f $url) -ForegroundColor Cyan
    $site = Invoke-Graph -Headers $H -Uri $url
   
  
    $siteId = $site.id
    Write-Host (" Resolved site id: {0}" -f $siteId) -ForegroundColor Cyan
 
    # Get lists; keep doc libraries only
    $lists = @()
    $next = "https://graph.microsoft.com/v1.0/sites/$siteId/lists?`$top=999&`$select=id,name,webUrl,list"
    Write-Host (" Getting lists from: {0}" -f $next) -ForegroundColor Cyan

    while ($next) {
      $r = Invoke-Graph -Headers $H -Uri $next
      if ($r.value) {
        $lists += ($r.value | Where-Object { $_.list.template -eq 'documentLibrary' })
      }
      $next = $r.'@odata.nextLink'
    }

  

    write-Host (" Found {0} document libraries" -f $lists.Count) -ForegroundColor Cyan
    if ($lists.Count -eq 0) { continue }
 
    foreach ($list in $lists) {
      $libName = $list.name
      Write-Host (" Processing library: {0}" -f $libName) -ForegroundColor Cyan
 
      # Pull items via listItems (expand driveItem to get size/name/parent/webUrl)
      $base = "https://graph.microsoft.com/v1.0/sites/$siteId/lists/$($list.id)/items"
      $filter3 = "?`$filter=fields/Modified le '$($cutoff3.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))'&`$top=$PageSize&`$expand=driveItem(`$select=id,name,size,webUrl,parentReference,lastModifiedDateTime)&`$select=id,lastModifiedDateTime,webUrl"
      $filter5 = "?`$filter=fields/Modified le '$($cutoff5.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))'&`$top=$PageSize&`$expand=driveItem(`$select=id,name,size,webUrl,parentReference,lastModifiedDateTime)&`$select=id,lastModifiedDateTime,webUrl"
 
      # --- 3 years ---
      $next3 = $base + $filter3
      while ($next3) {
        $r3 = Invoke-Graph -Headers $H -Uri $next3
        foreach ($it in $r3.value) {
          if ($null -eq $it.driveItem) { continue }
          $lm = [datetime]$it.lastModifiedDateTime
          if ($lm -gt $cutoff3) { continue }
          $size = $it.driveItem.size
          $name = $it.driveItem.name
          $itemUrl = $it.driveItem.webUrl
          $path = $it.driveItem.parentReference.path
          $line = ('"{0}","{1}","{2}","{3}","{4}","{5}",{6},{7}' -f
            $siteUrl.Replace('"', '""'),
            $libName.Replace('"', '""'),
            ($itemUrl ? $itemUrl : "").Replace('"', '""'),
            ($path ? $path : "").Replace('"', '""'),
            ($name ? $name : "").Replace('"', '""'),
            $lm.ToUniversalTime().ToString("o"),
            $size,
            [math]::Round($size / 1MB, 2)
          )
          Add-Content -Path $detailsCsv3 -Value $line
        }
        $next3 = $r3.'@odata.nextLink'
      }
 
      # --- 5 years ---
      
      $next5 = $base + $filter5
      while ($next5) {
        $r5 = Invoke-Graph -Headers $H -Uri $next5
        foreach ($it in $r5.value) {
          if ($null -eq $it.driveItem) { continue }
          $lm = [datetime]$it.lastModifiedDateTime
          if ($lm -gt $cutoff5) { continue }
          $size = $it.driveItem.size
          $name = $it.driveItem.name
          $itemUrl = $it.driveItem.webUrl
          $path = $it.driveItem.parentReference.path
          $line = ('"{0}","{1}","{2}","{3}","{4}","{5}",{6},{7}' -f
            $siteUrl.Replace('"', '""'),
            $libName.Replace('"', '""'),
            ($itemUrl ? $itemUrl : "").Replace('"', '""'),
            ($path ? $path : "").Replace('"', '""'),
            ($name ? $name : "").Replace('"', '""'),
            $lm.ToUniversalTime().ToString("o"),
            $size,
            [math]::Round($size / 1MB, 2)
          )
          Add-Content -Path $detailsCsv5 -Value $line
        }
        $next5 = $r5.'@odata.nextLink'
      }
      
    }
  }
  catch {
    Write-Warning "Failed site $siteUrl : $($_.Exception.Message)"
  }
}
 
# --- Summaries ---
function SummarizeCsv([string]$Path) {
  if (-not (Test-Path $Path)) { return $null }
  $sum = 0L; $count = 0L
  $rows = Import-Csv -Path $Path
  foreach ($r in $rows) { if ($r.SizeBytes) { $sum += [int64]$r.SizeBytes }; $count++ }
  [pscustomobject]@{ File = (Split-Path $Path -Leaf); Count = $count; TotalSizeBytes = $sum; TotalSizeGB = [math]::Round($sum / 1GB, 2) }
}
$sum3 = SummarizeCsv $detailsCsv3
$sum5 = SummarizeCsv $detailsCsv5
@($sum3, $sum5 | Where-Object { $_ -ne $null }) | Export-Csv -NoTypeInformation -Path $summaryCsv
 
Write-Host "DONE. Outputs:" -ForegroundColor Green
Write-Host " - $detailsCsv3"
Write-Host " - $detailsCsv5"
