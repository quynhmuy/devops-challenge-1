#!/bin/bash
set -euo pipefail

# Tự xác định đường dẫn: chạy từ thư mục nào cũng được
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVICE="devops-app"
HEALTH_URL="http://localhost/health"

echo "===== DevOps Deployment ====="
cd "$APP_DIR"

echo "[1] Updating source..."
git pull origin main

echo "[2] Installing dependencies..."
source venv/bin/activate
pip install -r requirements.txt

echo "[3] Restarting application..."
sudo systemctl restart "$SERVICE"

echo "[4] Checking service..."
sleep 2
sudo systemctl is-active --quiet "$SERVICE" || { echo "Service is not running."; exit 1; }

echo "[5] Health check..."
for i in 1 2 3 4 5; do
    if curl --fail --silent "$HEALTH_URL"; then
        echo
        echo "Application is healthy. Deployment successful."
        exit 0
    fi
    echo "Attempt $i failed, retrying..."
    sleep 2
done

echo "Health check failed. Deployment FAILED."
exit 1