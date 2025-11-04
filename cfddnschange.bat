@echo off
setlocal EnableDelayedExpansion

:: Lazily made, could be made almost fully automatic but just change some values for now.

set CF_TOKEN=YOUR_CLOUDFLARE_API_TOKEN
set ZONE_ID=YOUR_CLOUDFLARE_ZONE_ID
set TARGET_IP=CURRENT_SET_IP
set PROXY_STATUS=true

for /f %%a in ('curl -L -4 iprs.fly.dev') do set CURRENT_IP=%%a
echo Current public IP is: !CURRENT_IP!

curl -s -X GET "https://api.cloudflare.com/client/v4/zones/%ZONE_ID%/dns_records?type=A" ^
     -H "Authorization: Bearer %CF_TOKEN%" ^
     -H "Content-Type: application/json" > dns_records.json

powershell -command "Get-Content dns_records.json | ConvertFrom-Json | Select -ExpandProperty result | Where-Object {$_.content -eq '%TARGET_IP%'} | ForEach-Object { \"$($_.id),$($_.name)\" }" > records_to_update.txt

for /f %%a in ('type records_to_update.txt ^| find /c ","') do set records_count=%%a
if !records_count! equ 0 (
    echo No records found with IP %TARGET_IP%. Exiting.
    goto finish
)

for /f "tokens=1,2 delims=," %%A in (records_to_update.txt) do (
    echo Updating %%B to IP !CURRENT_IP!...
    curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/%ZONE_ID%/dns_records/%%A" ^
         -H "Authorization: Bearer %CF_TOKEN%" ^
         -H "Content-Type: application/json" ^
         --data "{\"type\":\"A\",\"name\":\"%%B\",\"content\":\"!CURRENT_IP!\",\"ttl\":3600,\"proxied\":true}" >nul
)

del records_to_update.txt

echo DNS records updated to match current ip
endlocal
pause
