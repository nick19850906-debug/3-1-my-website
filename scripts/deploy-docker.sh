#!/usr/bin/env bash
# ==============================================================================
# [보너스 과제 2] EC2 인스턴스 내부 Docker 설치 및 컨테이너 웹 서비스(80:80) 배포·검증
# ==============================================================================
set -euo pipefail

echo "[Step 1] 호스트 기본 Nginx 중지(80번 포트 충돌 방지) 및 Docker 설치"
sudo systemctl stop nginx || true
sudo systemctl disable nginx || true

sudo apt-get update -y
sudo apt-get install -y docker.io docker-compose-v2
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER" || true

echo "[Step 2] Docker 이미지(codyssey-web:latest) 빌드"
sudo docker build -t codyssey-web:latest .

echo "[Step 3] 기존 컨테이너 정리 후 80:80 포트 매핑으로 컨테이너 실행"
sudo docker rm -f codyssey-web 2>/dev/null || true
sudo docker run -d \
  --name codyssey-web \
  --restart unless-stopped \
  -p 80:80 \
  codyssey-web:latest

echo "[Step 4] docker ps 컨테이너 Up 상태 검증"
sudo docker ps --filter "name=codyssey-web"

echo "[Step 5] 인스턴스 내부 curl http://localhost 및 /health 200 OK 응답 검증"
curl -i http://localhost | head -n 10
echo ""
curl -i http://localhost/health
