$phone = '555000' + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$bodyObj = @{ phone = $phone; password = 'demo123'; role = 'citizen' }
$body = $bodyObj | ConvertTo-Json

try {
    $signup = Invoke-RestMethod -Uri 'http://localhost:8001/signup' -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 10
    Write-Output ('SIGNUP_OK:' + ($signup | ConvertTo-Json -Compress))
} catch {
    Write-Output ('SIGNUP_FAIL:' + $_.Exception.Message)
}

try {
    $login = Invoke-RestMethod -Uri 'http://localhost:8001/login' -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 10
    Write-Output ('LOGIN_OK:' + ($login | ConvertTo-Json -Compress))
    $token = $login.access_token
    if (-not $token) { $token = $login.token }
    Write-Output ('TOKEN:' + $token)
} catch {
    Write-Output ('LOGIN_FAIL:' + $_.Exception.Message)
}

try {
    $sosBodyObj = @{ lat = 48.85; lon = 2.35; mode = 'online' }
    $sosBody = $sosBodyObj | ConvertTo-Json
    $headers = @{ Authorization = ('Bearer ' + $token) }
    $resp = Invoke-RestMethod -Uri 'http://localhost:8002/sos' -Method Post -Headers $headers -Body $sosBody -ContentType 'application/json' -TimeoutSec 10
    Write-Output ('SOS_OK:' + ($resp | ConvertTo-Json -Compress))
} catch {
    Write-Output ('SOS_FAIL:' + $_.Exception.Message)
}
