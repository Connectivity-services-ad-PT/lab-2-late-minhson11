$ErrorActionPreference = "Stop"

$BaseUrl = if ($env:BASE_URL) { $env:BASE_URL } else { "http://localhost:4010" }
$AuthHeader = "Authorization: Bearer test-token"

Write-Host "[Lab02] Testing Prism mock server at $BaseUrl for Pair 03 (Core Business <-> Access Gate)"
Write-Host ""

Write-Host "[1/5] Happy path: GET /health"
curl.exe -i "$BaseUrl/health"
Write-Host "`n---"

Write-Host "[2/5] Happy path: GET /access/logs"
curl.exe -i "$BaseUrl/access/logs" -H $AuthHeader
Write-Host "`n---"

Write-Host "[3/5] Happy path: GET /cards/RFID-2026-001"
curl.exe -i "$BaseUrl/cards/RFID-2026-001" -H $AuthHeader
Write-Host "`n---"

Write-Host "[4/5] Error case: GET /access/logs/{logId} Not Found (404)"
curl.exe -i "$BaseUrl/access/logs/0196fb3d-4ad7-7d1e-9f49-5d5148d20000" -H $AuthHeader -H "Prefer: code=404"
Write-Host "`n---"

Write-Host "[5/5] Error case: GET /cards/RFID-2026-001 Bad Request (400)"
curl.exe -i "$BaseUrl/cards/RFID-2026-001" -H $AuthHeader -H "Prefer: code=400"
Write-Host ""
