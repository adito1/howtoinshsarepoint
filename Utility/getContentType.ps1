
$bytes = Get-Content "C:\tmp\tetsPdf.pdf" -Encoding Byte -TotalCount 5
[System.Text.Encoding]::ASCII.GetString($bytes)


$bytes = [System.IO.File]::ReadAllBytes("C:\tmp\tetsPdf.pdf")
$header = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 5)
$header