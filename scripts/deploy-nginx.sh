#!/usr/bin/env bash
# ==============================================================================
# [파일 이름] scripts/deploy-nginx.sh
# [파일 역할] EC2 인스턴스 내부에서 ① 외부 인터넷 아웃바운드 통신을 검증하고,
#            ② Nginx 웹 서버를 설치한 뒤 ③ localhost 200 OK 응답을 확인하는 스크립트입니다.
# [실생활 비유] 새로 지은 매장 건물(EC2) 안에 들어가서 ① 외부로 전화(인터넷)가 잘 걸리는지 확인하고,
#             ② 안내 데스크 직원(Nginx)을 배치한 뒤 ③ 매장 안에서 테스트 호출을 해보는 과정입니다.
# ==============================================================================
set -euo pipefail

# [1구역: 요구사항 1 — Public Subnet -> Route Table(0.0.0.0/0) -> IGW 아웃바운드 통신 검증]
# - curl -I -s https://example.com : 외부 사이트(example.com)에 머리말(Header, -I)만 조용히(-s) 요청합니다.
# - head -n 5 : 응답의 첫 5줄('HTTP/2 200' 포함)을 출력하여 인터넷으로 나가는 길이 뚫려 있음을 증명합니다.
echo "[Step 1] Public Subnet -> Internet Gateway 아웃바운드 통신 검증 (curl https://example.com)"
curl -I -s https://example.com | head -n 5

# [2구역: 요구사항 2 — Ubuntu 패키지 장부 업데이트 및 Nginx 웹 서버 설치]
# - sudo : 관리자(root) 권한으로 실행합니다.
# - apt-get update -y : 설치 가능한 프로그램 목록을 최신으로 새로고침합니다 (-y는 "네, 진행하세요" 자동 응답).
# - apt-get install -y nginx curl : 웹 서버(nginx)와 통신 테스트 도구(curl)를 설치합니다.
echo "[Step 2] 패키지 목록 업데이트 및 Nginx 설치"
sudo apt-get update -y
sudo apt-get install -y nginx curl

# [3구역: 우리가 만든 홈페이지 화면(web/index.html)과 안내 매뉴얼(nginx/default.conf) 적용]
echo "[Step 3] 커스텀 웹 페이지(web/index.html) 및 Nginx 설정(nginx/default.conf) 반영"
sudo cp ./web/index.html /usr/share/nginx/html/index.html
sudo cp ./nginx/default.conf /etc/nginx/sites-available/default

# - sudo nginx -t : Nginx 설정 파일에 오타나 문법 에러가 없는지 미리 검사(test)합니다.
sudo nginx -t
# - sudo systemctl enable nginx : 서버가 재부팅되어도 Nginx가 자동으로 켜지도록 등록합니다.
sudo systemctl enable nginx
# - sudo systemctl restart nginx : 새 설정이 반영되도록 Nginx를 재시작합니다.
sudo systemctl restart nginx

# [4구역: 요구사항 2 — 인스턴스 내부에서 curl http://localhost 요청이 200 응답을 반환하는지 검증]
# - curl -i http://localhost : 상태 코드('HTTP/1.1 200 OK')와 본문을 함께(-i) 출력합니다.
echo "[Step 4] 인스턴스 내부 localhost 200 OK 응답 검증"
curl -i http://localhost | head -n 12
echo ""

# [5구역: 요구사항 5(B) — 인스턴스 내부에서 /health 호출 시 200 OK 및 "OK" 반환 검증]
echo "[Step 5] 인스턴스 내부 /health 엔드포인트 200 OK ('OK') 응답 검증"
curl -i http://localhost/health
