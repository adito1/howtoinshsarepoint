$Secret = "your-client-secret"

$ClientID = ""     
$TenantID = ""
$resource = "https://graph.microsoft.com"
$TokenURL = "https://login.microsoftonline.com/$TenantID/oauth2/token"
 
$body = @{

    grant_type    = "client_credentials"

    client_id     = $ClientID

    client_secret = $Secret

    resource      = $resource

}
 
Write-Verbose "Obtaining token..."

$resT = Invoke-WebRequest -Method Post -Uri $TokenURL -Body $body -ContentType "application/x-www-form-urlencoded" -UseBasicParsing

$token = ($resT.Content | ConvertFrom-Json).access_token
 
#Write-host "Bearer $token"
 
$headers = @{

    Authorization  = "Bearer $token"

    "Content-Type" = "application/json"

}
 
Write-Host $headers.Authorization
 
$body = @{

    subject       = ""

    startDateTime = "2026-07-12T22:30:00.00Z"

    endDateTime   = "2026-07-14T22:45:00.00Z"

} | convertto-json -Depth 5
 
$url = "$resource/v1.0/users/0630e7de-66fa-424f-a0c4-7096da0d2c33/onlineMeetings"
 
$res = Invoke-WebRequest -Method Post -Uri $url -Headers $headers -Body $body -UseBasicParsing
