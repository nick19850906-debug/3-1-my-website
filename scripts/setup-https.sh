#!/usr/bin/env bash
# ==============================================================================
# [파일 이름] scripts/setup-https.sh (보너스 과제 1: HTTPS 인증서 적용하기)
# [파일 역할] 무료 서브도메인(DuckDNS 등)을 연결한 뒤, 무료 공인 인증기관인 Let's Encrypt(Certbot)를 통해
#            HTTPS(443번 포트) 자물쇠 보안 연결을 자동으로 적용하는 스크립트입니다.
# [실생활 비유] 손님과 매장 사이에 오가는 편지를 남들이 훔쳐보지 못하도록
#             '공인 보안 봉투(SSL/TLS 인증서)'를 무료로 발급받아 적용하는 과정입니다.
# ==============================================================================
set -euo pipefail

# 첫 번째 입력값($1)이 없으면 기본값으로 'codyssey-web.duckdns.org'를 사용합니다.
DOMAIN="${1:-codyssey-web.duckdns.org}"
# 두 번째 입력값($2)이 없으면 기본 이메일 주소를 사용합니다 (인증서 만료 알림 수신용).
EMAIL="${2:-nick19850906@gmail.com}"

# [1구역: Let's Encrypt 자동 발급 로봇(Certbot) 설치]
echo "[Step 1] Certbot 및 Nginx 플러그인 설치"
sudo apt-get update -y
sudo apt-get install -y certbot python3-certbot-nginx

# [2구역: 인증서 발급 및 HTTP(80) -> HTTPS(443) 자동 전환(--redirect) 설정]
# - --nginx           : Nginx 설정 파일을 Certbot이 자동으로 읽고 수정하게 합니다.
# - -d "${DOMAIN}"    : 인증서를 발급받을 도메인 주소입니다.
# - --non-interactive : 사람에게 중간 질문을 하지 않고 자동으로 진행합니다.
# - --agree-tos       : 이용약관(Terms of Service)에 동의합니다.
# - --redirect        : http:// 로 들어온 손님을 자동으로 안전한 https:// 로 안내(301 리다이렉트)합니다.
echo "[Step 2] Let's Encrypt TLS 인증서 발급 및 Nginx HTTPS 자동 리다이렉트 적용"
sudo certbot --nginx \
  -d "${DOMAIN}" \
  --non-interactive \
  --agree-tos \
  -m "${EMAIL}" \
  --redirect

# [3구역: 90일마다 인증서를 자동 연장해 주는 타이머 확인 및 HTTPS 접속 검증]
echo "[Step 3] 인증서 자동 갱신 타이머 상태 확인 및 HTTPS 응답 검증"
sudo systemctl status certbot.timer --no-pager
curl -I "https://${DOMAIN}/health"
