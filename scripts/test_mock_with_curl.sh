#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:4010}"
AUTH_HEADER="Authorization: Bearer test-token"

echo "[Lab02] Testing Prism mock server at $BASE_URL for Pair 03 (Core Business <-> Access Gate)"
echo

echo "[1/5] Happy path: GET /health"
curl -i "$BASE_URL/health"
echo "
---"

echo "[2/5] Happy path: GET /access/logs"
curl -i "$BASE_URL/access/logs" -H "$AUTH_HEADER"
echo "
---"

echo "[3/5] Happy path: GET /cards/RFID-2026-001"
curl -i "$BASE_URL/cards/RFID-2026-001" -H "$AUTH_HEADER"
echo "
---"

echo "[4/5] Error case: GET /access/logs/{logId} Not Found (404)"
curl -i "$BASE_URL/access/logs/0196fb3d-4ad7-7d1e-9f49-5d5148d20000" -H "$AUTH_HEADER" -H "Prefer: code=404"
echo "
---"

echo "[5/5] Error case: GET /cards/RFID-2026-001 Bad Request (400)"
curl -i "$BASE_URL/cards/RFID-2026-001" -H "$AUTH_HEADER" -H "Prefer: code=400"
echo
