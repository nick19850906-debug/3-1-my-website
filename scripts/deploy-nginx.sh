#!/usr/bin/env bash
# ==============================================================================
# [요구사항 1·2] EC2 인스턴스 내부 아웃바운드 통신 검증 및 Nginx 웹 서버 설치·배포
# ==============================================================================
set -euo pipefail

echo "[Step 1] Public Subnet -> Internet Gateway 아웃바운드 통신 검증"
curl -I -s https://example.com | head -n 5

echo "[Step 2] 패키지 목록 업데이트 및 Nginx 설치"
sudo apt-get update -y
sudo apt-get install -y nginx curl

echo "[Step 3] 커스텀 웹 페이지(web/index.html) 및 Nginx 설정(nginx/default.conf) 반영"
sudo cp ./web/index.html /usr/share/nginx/html/index.html
sudo cp ./nginx/default.conf /etc/nginx/sites-available/default

sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx

echo "[Step 4] 인스턴스 내부 localhost 200 OK 응답 검증"
curl -i http://localhost | head -n 12
echo ""
echo "[Step 5] 인스턴스 내부 /health 엔드포인트 200 OK 응답 검증"
curl -i http://localhost/health
