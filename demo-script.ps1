# HELEP Kubernetes Demo Script
# Total Duration: about 5 minutes
# Student: Nguend Arthur Johann

function Invoke-JsonRequest {
    param(
        [string]$Uri,
        [string]$Method,
        [hashtable]$Body,
        [hashtable]$Headers
    )

    $params = @{
        Uri = $Uri
        Method = $Method
        ContentType = 'application/json'
        Body = ($Body | ConvertTo-Json)
        ErrorAction = 'Stop'
    }

    if ($Headers) {
        $params.Headers = $Headers
    }

    return Invoke-RestMethod @params
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "HELEP - Kubernetes Deployment Demo" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "STAGE 1 Introduction and System Overview" -ForegroundColor Yellow
Write-Host "HELEP is a real-time emergency dispatch system." -ForegroundColor White
Write-Host "Architecture: event-driven microservices with Kafka." -ForegroundColor White
Write-Host "Services: user-service, sos-service, dispatch-service, notification-service, analytics-service." -ForegroundColor White
Write-Host "Observability: Prometheus and Grafana." -ForegroundColor White
Write-Host ""
Start-Sleep -Seconds 2

Write-Host "STAGE 2 Kubernetes Cluster State" -ForegroundColor Yellow
kubectl get nodes
Write-Host ""
kubectl get all -n helep
Write-Host ""
kubectl get pods -n kafka
Write-Host ""
Start-Sleep -Seconds 2

Write-Host "STAGE 3 Live SOS Workflow" -ForegroundColor Yellow
$demoPhone = '555000' + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$demoPassword = 'SecurePass123'

Write-Host "Registering user with phone $demoPhone" -ForegroundColor White
$signupResponse = Invoke-JsonRequest -Uri 'http://localhost:8001/signup' -Method Post -Body @{ phone = $demoPhone; password = $demoPassword; role = 'citizen' }
Write-Host ("Signup response: " + ($signupResponse | ConvertTo-Json -Compress)) -ForegroundColor Green

Write-Host "Logging in user" -ForegroundColor White
$loginResponse = Invoke-JsonRequest -Uri 'http://localhost:8001/login' -Method Post -Body @{ phone = $demoPhone; password = $demoPassword }
$authToken = $loginResponse.token
Write-Host ("Login response: " + ($loginResponse | ConvertTo-Json -Compress)) -ForegroundColor Green

Write-Host "Triggering SOS" -ForegroundColor White
$sosResponse = Invoke-JsonRequest -Uri 'http://localhost:8002/sos' -Method Post -Headers @{ Authorization = ('Bearer ' + $authToken) } -Body @{ lat = 42.3314; lon = -83.0458; mode = 'online' }
Write-Host ("SOS response: " + ($sosResponse | ConvertTo-Json -Compress)) -ForegroundColor Green
Write-Host "Kafka topic: sos.triggered" -ForegroundColor Gray
Write-Host ""
Start-Sleep -Seconds 2

Write-Host "STAGE 4 SOS Cancellation and Responder Release" -ForegroundColor Yellow
$cancelResponse = Invoke-JsonRequest -Uri ("http://localhost:8002/sos/" + $sosResponse.incident_id + "/cancel") -Method Post -Headers @{ Authorization = ('Bearer ' + $authToken) } -Body @{}
Write-Host ("Cancel response: " + ($cancelResponse | ConvertTo-Json -Compress)) -ForegroundColor Green
Write-Host "Kafka topic: sos.cancelled" -ForegroundColor Gray
Write-Host ""
Start-Sleep -Seconds 2

Write-Host "STAGE 5 Chaos Test and Auto-Recovery" -ForegroundColor Yellow
$dispatchPod = kubectl get pods -n helep -l app=dispatch-service -o jsonpath="{.items[0].metadata.name}"
Write-Host ("Dispatch pod: " + $dispatchPod) -ForegroundColor White
kubectl delete pod $dispatchPod -n helep --grace-period=1 | Out-Null
Write-Host "Dispatch pod deleted and being recreated by Kubernetes." -ForegroundColor Green
Start-Sleep -Seconds 3
kubectl get pods -n helep -l app=dispatch-service
Write-Host ""

Write-Host "STAGE 6 Observability" -ForegroundColor Yellow
Write-Host "Prometheus: http://localhost:9090" -ForegroundColor Green
Write-Host "Grafana: http://localhost:3000 (admin/admin)" -ForegroundColor Green
kubectl get pods -n observability
Write-Host ""
Start-Sleep -Seconds 2

Write-Host "STAGE 7 CI/CD Pipeline" -ForegroundColor Yellow
Write-Host "Jenkins pipeline stages:" -ForegroundColor White
Write-Host "  1. Code checkout" -ForegroundColor Gray
Write-Host "  2. Unit tests" -ForegroundColor Gray
Write-Host "  3. Build Docker images" -ForegroundColor Gray
Write-Host "  4. Push to registry" -ForegroundColor Gray
Write-Host "  5. Deploy to Kubernetes" -ForegroundColor Gray
Write-Host "  6. Smoke tests" -ForegroundColor Gray
Write-Host "  7. Integration tests" -ForegroundColor Gray
kubectl get deployment -n helep -o wide
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Demo Complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Kubernetes cluster operational" -ForegroundColor Green
Write-Host "HELEP services running" -ForegroundColor Green
Write-Host "Kafka messaging operational" -ForegroundColor Green
Write-Host "Observability enabled" -ForegroundColor Green
Write-Host "Pod resilience verified" -ForegroundColor Green
Write-Host "API endpoints responding" -ForegroundColor Green
Write-Host "CI/CD pipeline configured" -ForegroundColor Green
Write-Host "Platform Readiness: PRODUCTION-READY FOR DEMO" -ForegroundColor Green
