#!/usr/bin/env bash
# ==============================================================================
# [보너스 과제 1] 무료 서브도메인(DuckDNS 등) 연결 및 Let's Encrypt HTTPS 인증서 적용
# 사전 조건: Security Group 인바운드에 HTTPS(443) 0.0.0.0/0 허용 규칙 추가 완료
# 사용법: ./scripts/setup-https.sh <도메인명> <이메일>
# ==============================================================================
set -euo pipefail

DOMAIN="${1:-codyssey-web.duckdns.org}"
EMAIL="${2:-nick19850906@gmail.com}"

echo "[Step 1] Certbot 및 Nginx 플러그인 설치"
sudo apt-get update -y
sudo apt-get install -y certbot python3-certbot-nginx

echo "[Step 2] Let's Encrypt TLS 인증서 발급 및 Nginx HTTPS 자동 리다이렉트 적용"
sudo certbot --nginx \
  -d "${DOMAIN}" \
  --non-interactive \
  --agree-tos \
  -m "${EMAIL}" \
  --redirect

echo "[Step 3] 인증서 자동 갱신 타이머 상태 확인 및 HTTPS 응답 검증"
sudo systemctl status certbot.timer --no-pager
curl -I "https://${DOMAIN}/health"
