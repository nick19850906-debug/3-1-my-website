#!/usr/bin/env bash
# ==============================================================================
# [파일 이름] scripts/deploy-docker.sh (보너스 과제 2: Docker 컨테이너로 웹 서비스 배포)
# [파일 역할] EC2 인스턴스 내부에 Docker를 설치하고, Dockerfile로 빌드한 컨테이너(codyssey-web:latest)를
#            80:80 포트 매핑으로 실행한 뒤 'docker ps'와 'curl http://localhost'로 검증합니다.
# [실생활 비유] 매장 안에 직접 차렸던 임시 안내 데스크(기본 Nginx)를 접고,
#             어디서나 규격이 똑같은 '프랜차이즈 컨테이너 매장(codyssey-web)'을 80번 대문에 연결해 오픈합니다.
# ==============================================================================
set -euo pipefail

# [1구역: 80번 포트 자리 비우기 및 Docker 엔진 설치]
# - 하나의 포트(80번)에는 하나의 프로그램만 앉을 수 있으므로, 호스트의 기본 Nginx를 먼저 멈춥니다.
# - '|| true'는 혹시 Nginx가 아직 설치 전이어서 멈출 게 없더라도 에러 없이 넘어가라는 뜻입니다.
echo "[Step 1] 호스트 기본 Nginx 중지(80번 포트 충돌 방지) 및 Docker 설치"
sudo systemctl stop nginx || true
sudo systemctl disable nginx || true

sudo apt-get update -y
sudo apt-get install -y docker.io docker-compose-v2
# Docker 서비스를 지금 바로 켜고(--now), 재부팅 시에도 자동으로 켜지게(enable) 설정합니다.
sudo systemctl enable --now docker
# 현재 사용자(ubuntu)를 docker 그룹에 추가하여 권한을 부여합니다.
sudo usermod -aG docker "$USER" || true

# [2구역: Dockerfile 조리법으로 컨테이너 이미지(codyssey-web:latest) 굽기]
# - -t codyssey-web:latest : 완성된 이미지에 'codyssey-web:latest'라는 이름표(Tag)를 붙입니다.
# - 마지막 '.' : 현재 폴더에 있는 Dockerfile을 사용하라는 뜻입니다.
echo "[Step 2] Docker 이미지(codyssey-web:latest) 빌드"
sudo docker build -t codyssey-web:latest .

# [3구역: 컨테이너 실행 (포트 매핑 -p 80:80)]
# - -d                       : 백그라운드(detached)에서 계속 돌아가게 실행합니다.
# - --name codyssey-web      : 컨테이너 상자 이름을 'codyssey-web'으로 지정합니다.
# - --restart unless-stopped : 서버가 재부팅되어도 컨테이너가 자동으로 다시 켜지게 합니다.
# - -p 80:80                 : [핵심!] EC2 외부 80번 포트와 컨테이너 내부 80번 포트를 직통 연결합니다.
echo "[Step 3] 기존 컨테이너 정리 후 80:80 포트 매핑으로 컨테이너 실행"
sudo docker rm -f codyssey-web 2>/dev/null || true
sudo docker run -d \
  --name codyssey-web \
  --restart unless-stopped \
  -p 80:80 \
  codyssey-web:latest

# [4구역: 보너스 2 필수 검증 1 — docker ps 로 컨테이너 Up 상태 및 포트 매핑 확인]
echo "[Step 4] docker ps 컨테이너 Up 상태 검증"
sudo docker ps --filter "name=codyssey-web"

# [5구역: 보너스 2 필수 검증 2 — 인스턴스 내부에서 curl http://localhost 200 OK 응답 확인]
echo "[Step 5] 인스턴스 내부 curl http://localhost 및 /health 200 OK 응답 검증"
curl -i http://localhost | head -n 10
echo ""
curl -i http://localhost/health
