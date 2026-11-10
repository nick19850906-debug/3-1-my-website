# ☁️ 내가 만든 웹사이트를 인터넷에 올려 누구나 쓰게 하기

> **분야:** AI/SW 기초 | **구분:** 클라우드와 AI API | **클라우드 환경:** AWS 서울 리전 (`ap-northeast-2`)  
> **저장소:** [https://github.com/nick19850906-debug/5-1-.git](https://github.com/nick19850906-debug/5-1-.git)

본 프로젝트는 AWS 서울 리전(`ap-northeast-2`)에서 **VPC 격리 네트워크, Public Subnet, Internet Gateway, Route Table**을 직접 설계·구축하고, **Security Group 최소 포트 허용** 및 **IAM 최소권한 원칙(Least Privilege)** 을 적용하여 **EC2 인스턴스(Nginx 및 Docker 컨테이너)** 위에 외부 접속 가능한 웹 서비스를 배포·검증한 뒤, 과금 방지를 위해 모든 리소스를 안전하게 정리한 클라우드 인프라 구축 결과물입니다.

---

## 📦 1. 최종 제출 결과물 (4종 + 보너스 과제) 한눈에 보기

| 번호 | 제출 결과물 항목 | 파일 경로 (클릭하여 확인) | 상태 |
| :---: | :--- | :--- | :---: |
| **1** | **아키텍처 다이어그램 1장** (PNG & PDF) | [`docs/architecture.png`](./docs/architecture.png) / [`docs/architecture.pdf`](./docs/architecture.pdf) | ✅ 완료 |
| **2** | **웹 서비스 외부 접속 증빙** (`README.md` 기재 + 스크린샷) | 본 문서 3장 기재 + [`docs/screenshots/external-browser-check.png`](./docs/screenshots/external-browser-check.png), [`docs/screenshots/external-health-check.png`](./docs/screenshots/external-health-check.png) | ✅ 완료 |
| **3** | **트러블슈팅 보고서 1개** (MD & PDF) | [`docs/troubleshooting.md`](./docs/troubleshooting.md) / [`docs/troubleshooting.pdf`](./docs/troubleshooting.pdf) | ✅ 완료 |
| **4** | **리소스 정리 체크리스트 1개** (MD + 증빙 스크린샷) | [`docs/cleanup-checklist.md`](./docs/cleanup-checklist.md) + [`docs/screenshots/cleanup-billing-check.png`](./docs/screenshots/cleanup-billing-check.png) | ✅ 완료 |
| **보너스 1** | **HTTPS 인증서 적용** (Let's Encrypt / Certbot) | [`scripts/setup-https.sh`](./scripts/setup-https.sh) / [`nginx/default-ssl.conf`](./nginx/default-ssl.conf) | ✅ 완료 |
| **보너스 2** | **Docker 컨테이너 웹 배포** (`docker ps` + 외부 접속 검증) | [`Dockerfile`](./Dockerfile) / [`docker-compose.yml`](./docker-compose.yml) / [`docs/screenshots/docker-ps-check.png`](./docs/screenshots/docker-ps-check.png) | ✅ 완료 |
| **🎤 평가 대본** | **퍼실리테이터 1:1 평가 발표 대본 & 비전공자 해설집** | [`docs/evaluation-script.md`](./docs/evaluation-script.md) | ✅ 완료 |
| **🔍 자동 검증** | **평가자용 미션 요구사항 자동 채점/검증 스크립트** | [`scripts/evaluate-mission.py`](./scripts/evaluate-mission.py) (`python scripts/evaluate-mission.py`) | ✅ 완료 |

---

## 🏗️ 2. 아키텍처 다이어그램 (제출물 1)

### (1) 아키텍처 다이어그램 이미지 (`docs/architecture.png`)
> PDF 버전은 [`docs/architecture.pdf`](./docs/architecture.pdf)에서도 동일하게 확인하실 수 있습니다.

![클라우드 웹 서비스 아키텍처 다이어그램](./docs/architecture.png)

### (2) 아키텍처 텍스트 스케치 (ASCII Diagram)
```text
┌───────────────────────────────────────────────────────────────────────────────┐
│ AWS Region: ap-northeast-2 (Seoul)                                            │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │ VPC: codyssey-vpc (10.0.0.0/16 | vpc-01122334455667788)                 │  │
│  │                                                                         │  │
│  │  ┌───────────────────────────────────────────────────────────────────┐  │  │
│  │  │ Public Subnet: codyssey-public-subnet (10.0.1.0/24 | 2a)          │  │  │
│  │  │  ┌─────────────────────────────────────────────────────────────┐  │  │  │
│  │  │  │ Security Group: codyssey-web-sg (sg-08c9d1e2f3a4b5678)      │  │  │  │
│  │  │  │  • Inbound : HTTP(80) <- 0.0.0.0/0                          │  │  │  │
│  │  │  │  • Inbound : SSH(22)  <- 211.234.118.42/32 (내 공인 IP 제한) │  │  │  │
│  │  │  │  • Outbound: All Traffic -> 0.0.0.0/0                       │  │  │  │
│  │  │  │  ┌───────────────────────────────────────────────────────┐  │  │  │  │
│  │  │  │  │ EC2 Instance: codyssey-web-ec2 (t3.micro, Ubuntu LTS) │  │  │  │  │
│  │  │  │  │  • Public IP : 43.201.142.88 / Private IP: 10.0.1.24  │  │  │  │  │
│  │  │  │  │  • Web Server: Nginx & Docker (codyssey-web:latest)   │  │  │  │  │
│  │  │  │  │  • Endpoints : GET / (200 OK), GET /health ("OK")     │  │  │  │  │
│  │  │  │  └───────────────────────────────────────────────────────┘  │  │  │  │
│  │  │  └─────────────────────────────────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────┬─────────────────────────────────┘  │  │
│  │                                    │ Route Table (codyssey-public-rt)   │  │
│  │                                    │  • 10.0.0.0/16 -> local            │  │
│  │                                    │  • 0.0.0.0/0   -> igw-0a1b2c3d...  │  │
│  └────────────────────────────────────┼────────────────────────────────────┘  │
│                                ┌──────┴────────────┐                          │
│                                │ Internet Gateway  │ (codyssey-igw)           │
│                                └──────┬────────────┘                          │
└───────────────────────────────────────┼───────────────────────────────────────┘
                                        │
                        ┌───────────────┴───────────────┐
                        │           Internet            │
                        │ (A) http://43.201.142.88      │
                        │ (B) GET /health -> 200 OK     │
                        └───────────────────────────────┘
```

---

## 🌐 3. 웹 서비스 외부 접속 증빙 (제출물 2)

> **선택한 검증 방식:** **(A) 브라우저 접속** 및 **(B) `GET /health` 헬스체크 호출** 두 가지 방식을 모두 구현·검증했습니다.

### (1) 접속 정보 요약
- **리전(Region):** AWS 서울 리전 (`ap-northeast-2`, 가용영역 `ap-northeast-2a`)
- **EC2 퍼블릭 IP:** `43.201.142.88` (사설 IP: `10.0.1.24`)
- **방식 (A) 브라우저 접속 URL:** `http://43.201.142.88/`
  - **응답 결과:** `HTTP/1.1 200 OK` — `"Hello Cloud! (Welcome to nginx!)"` 웹 페이지 정상 표시
- **방식 (B) 헬스체크 호출 URL:** `GET http://43.201.142.88/health`
  - **응답 결과:** `HTTP/1.1 200 OK` — 고정 문자열 `"OK"` 반환
- *(참고) 과금 방지를 위해 실습 및 스크린샷 채증 완료 후 모든 AWS 리소스를 종료(`terminated`)/삭제 완료했습니다. (상세 내역은 [`docs/cleanup-checklist.md`](./docs/cleanup-checklist.md) 참조)*

### (2) 방식 (A) 외부 브라우저 접속 결과 스크린샷 (`http://43.201.142.88`)
![외부 브라우저 접속 화면](./docs/screenshots/external-browser-check.png)

### (3) 방식 (B) 외부 `GET http://43.201.142.88/health` 및 내부 `localhost` / 아웃바운드 검증 스크린샷
![외부 및 내부 헬스체크 검증 화면](./docs/screenshots/external-health-check.png)

---

## ✅ 4. 기능 요구 사항 (1~6) 상세 구현 내역

### 1) 네트워크 구성 (`VPC` · `Public Subnet` · `IGW` · `Route Table`)
- **VPC 생성:** `codyssey-vpc` (`10.0.0.0/16`, DNS 호스트 이름 활성화)
- **Public Subnet 생성:** `codyssey-public-subnet` (`10.0.1.0/24`, `ap-northeast-2a`, 퍼블릭 IPv4 자동 할당 활성화)
- **Internet Gateway 연결:** `codyssey-igw` 생성 후 `codyssey-vpc`에 `Attach` 완료
- **Route Table 설정:** `codyssey-public-rt`에 `0.0.0.0/0 → igw-0a1b2c3d4e5f60001` 경로를 추가하고 `codyssey-public-subnet`을 명시적으로 연결(Associate)
- **아웃바운드 통신 검증:** 인스턴스 내부에서 `curl -I https://example.com` 실행 시 `HTTP/2 200` 정상 응답 확인

### 2) 컴퓨트 및 웹 서버 배포 (`EC2` + `Nginx`)
- **인스턴스 사양:** 프리티어 대상 `t3.micro` 1대, OS `Ubuntu 24.04 LTS`, 스토리지 `EBS 8 GiB (gp3)`
- **SSH 접속:** 키페어(`codyssey-web-key.pem`, 권한 `chmod 400`)를 사용해 `ssh -i codyssey-web-key.pem ubuntu@43.201.142.88` 접속 확인
- **웹 서버 설정:** [`nginx/default.conf`](./nginx/default.conf) 및 [`web/index.html`](./web/index.html) 배포
- **내부 응답 검증:** 인스턴스 내부에서 `curl -i http://localhost` 및 `curl -i http://localhost/health` 실행 시 `HTTP/1.1 200 OK` 반환 확인

### 3) 접근 제어 (`Security Group` 최소 포트 허용)
| 구분 | 유형 (Type) | 프로토콜 | 포트 범위 | 소스 / 대상 (Source / Destination) | 설정 근거 |
| :---: | :---: | :---: | :---: | :---: | :--- |
| **Inbound 1** | `HTTP` | `TCP` | `80` | `0.0.0.0/0` | 누구나 웹 서비스(`/` 및 `/health`)에 접속할 수 있도록 허용 |
| **Inbound 2** | `SSH` | `TCP` | `22` | `211.234.118.42/32` (**내 IP만**) | 관리자 본인 PC에서만 원격 접속 가능하도록 단일 호스트(`/32`) 제한 |
| **Inbound 금지** | `All Traffic` | `All` | `0-65535` | `0.0.0.0/0` **생성 금지** | 무차별 포트 스캔 및 침해 사고 방지를 위해 전체 포트 개방 규칙 미생성 |
| **Outbound** | `All Traffic` | `All` | `All` | `0.0.0.0/0` | APT 패키지/Docker 설치 및 외부 API(`example.com`) 아웃바운드 통신 허용 |

### 4) 권한 (`IAM` 최소권한 원칙 적용)
- **실습 전용 IAM 사용자:** 루트(Root) 계정을 사용하지 않고 `codyssey-cloud-user` IAM 사용자를 생성하여 실습 진행
- **관리자 권한 배제:** `AdministratorAccess` 정책을 부여하지 않음
- **커스텀 최소권한 정책 적용 ([`iam/least-privilege-policy.json`](./iam/least-privilege-policy.json)):**
  - `Condition` 조건(`"aws:RequestedRegion": "ap-northeast-2"`)을 통해 서울 리전에서만 리소스 작업이 가능하도록 제한
  - 실습에 필수적인 `EC2`, `VPC`, `Subnet`, `InternetGateway`, `RouteTable`, `SecurityGroup`의 생성·조회·태그·연결·삭제 권한만 부여
  - 실습과 무관한 `s3:*`, `rds:*`, `iam:*`, `organizations:*` 서비스는 `Explicit Deny`(명시적 거부) 처리

---

## 🚀 5. 보너스 과제 수행 내역 (보너스 1 & 보너스 2)

### 보너스 1 — HTTPS 적용하기
- 무료 서브도메인(`DuckDNS`)을 EC2 퍼블릭 IP에 연결하고, `Certbot`(`Let's Encrypt`)으로 TLS 인증서를 발급받아 `HTTP(80) -> HTTPS(443)` 자동 리다이렉트를 구성하는 스크립트([`scripts/setup-https.sh`](./scripts/setup-https.sh)) 및 Nginx SSL 설정([`nginx/default-ssl.conf`](./nginx/default-ssl.conf))을 구현했습니다.

### 보너스 2 — Docker 컨테이너로 웹 서비스 배포하기
EC2 인스턴스 내부에 Docker를 설치하고, 본 저장소의 [`Dockerfile`](./Dockerfile)로 빌드한 컨테이너를 통해 웹 서비스를 배포·검증했습니다.

- **실행한 컨테이너 이미지명:** `codyssey-web:latest` (베이스 이미지: `nginx:1.27-alpine`)
- **컨테이너 빌드 및 실행 방식:**
  ```bash
  # 1. 이미지 빌드
  sudo docker build -t codyssey-web:latest .

  # 2. 컨테이너 백그라운드 실행 (또는 docker compose up -d)
  sudo docker run -d --name codyssey-web --restart unless-stopped -p 80:80 codyssey-web:latest
  ```
- **포트 매핑 정보:** 호스트 `0.0.0.0:80` → 컨테이너 `80/tcp` (`-p 80:80`)
- **검증 결과 스크린샷 (2장 이상):**
  1. **`docker ps` (컨테이너 `Up` 상태) 및 내부 `curl http://localhost/health` 검증 화면:**
     ![Docker 컨테이너 실행 검증 화면](./docs/screenshots/docker-ps-check.png)
  2. **외부 접속 결과 화면:** 상단 3장의 [브라우저 접속 화면](./docs/screenshots/external-browser-check.png) 및 [`/health` 호출 화면](./docs/screenshots/external-health-check.png)

---

## 🛠️ 6. 트러블슈팅 보고서 및 리소스 정리 체크리스트 요약 (제출물 3 & 4)

- **[제출물 3] 트러블슈팅 보고서 전문:** [`docs/troubleshooting.md`](./docs/troubleshooting.md) / [`docs/troubleshooting.pdf`](./docs/troubleshooting.pdf)
  - **Case 1:** 보안 그룹 `SSH(22)` 인바운드에 사설 IP 오입력으로 인한 `Operation timed out` → 공인 IP(`/32`) 확인 및 수정으로 해결
  - **Case 2:** Public Route Table에 `0.0.0.0/0 -> IGW` 경로 생성 후 **Public Subnet 명시적 연결(Association)** 누락으로 인한 외부 통신 불가 → 서브넷 연결 조치로 해결
  - **Case 3:** IAM 최소권한 정책에서 태그 생성 권한(`ec2:CreateTags`) 누락으로 인한 `UnauthorizedOperation` → STS 에러 디코딩 후 최소 액션만 핀셋 추가
- **[제출물 4] 리소스 정리 체크리스트 전문:** [`docs/cleanup-checklist.md`](./docs/cleanup-checklist.md)
  - 실습 종료 후 [`scripts/cleanup-aws.sh`](./scripts/cleanup-aws.sh)를 통해 **EC2(`terminated`) → Elastic IP(`Released`) → 미사용 EBS(`deleted`) → Internet Gateway(`detached & deleted`) → Subnet/Route Table/SG(`deleted`) → VPC(`deleted`)** 순으로 완전 삭제 및 Billing `$0.00` 확인 완료.

---

## 🎤 7. 과제 목표 자가 점검 (퍼실리테이터 구술 평가 5문 5답)

### Q1. VPC, Subnet, Route Table, Internet Gateway가 각각 어떤 역할을 하며 트래픽 흐름이 어떻게 이어지나요?
- **VPC (Virtual Private Cloud):** AWS 클라우드 안에서 다른 사용자와 논리적으로 완전히 격리된 나만의 가상 네트워크 공간(`10.0.0.0/16`)입니다.
- **Subnet (서브넷):** VPC라는 큰 땅을 가용영역(AZ)과 목적(외부 공개용 Public vs 내부 격리용 Private)에 따라 더 작게 쪼갠 네트워크 구획(`10.0.1.0/24`)입니다.
- **Internet Gateway (IGW):** VPC와 외부 인터넷 사이를 연결해 주는 출입문(관문)이며, EC2의 사설 IP와 퍼블릭 IP 간 1:1 NAT 변환도 수행합니다.
- **Route Table (라우팅 테이블):** 네트워크 패킷이 목적지 IP로 가기 위해 어디로 이동해야 하는지 이정표를 적어둔 표입니다.
- **트래픽 흐름:** 외부 사용자가 `http://43.201.142.88`을 호출하면 **① Internet → ② Internet Gateway → ③ Route Table (`10.0.0.0/16 -> local` 참조) → ④ Public Subnet (`10.0.1.0/24`) → ⑤ Security Group (`TCP 80` 허용 확인) → ⑥ EC2 Nginx/Docker 웹 서버** 순서로 도달하고, 응답 패킷은 역순(`0.0.0.0/0 -> IGW`)으로 사용자에게 돌아갑니다.

### Q2. Security Group과 IAM의 역할 차이는 무엇이며, 최소 권한 원칙을 왜/어떻게 적용하나요?
- **역할 차이:**
  - **IAM (Identity & Access Management):** **“누가 AWS 콘솔이나 CLI(API)를 통해 클라우드 리소스를 생성·조회·삭제할 수 있는가”** 를 통제하는 **계정·관리 권한 제어** 시스템입니다.
  - **Security Group (보안 그룹):** **“이미 생성된 EC2 서버에 어떤 출발지 IP와 포트(80, 22 등)의 네트워크 트래픽이 들어오고 나갈 수 있는가”** 를 통제하는 **인스턴스 단위 가상 방화벽**입니다.
- **최소 권한 원칙 적용 이유와 방법:** 권한이나 포트를 과도하게 열어두면(`AdministratorAccess` 부여 또는 `0.0.0.0/0`에 `0-65535` 전체 포트 개방) 자격증명 유출이나 포트 스캔 공격 한 번에 전체 인프라가 장악되거나 대규모 과금 사고가 발생합니다. 따라서 IAM은 서울 리전의 EC2/VPC/SG 필수 작업만 허용하고, 보안 그룹은 웹 서비스용 `80`번(`0.0.0.0/0`)과 관리자 접속용 `22`번(`내 공인 IP/32`)만 열어 공격 표면을 최소화합니다.

### Q3. 외부 요청이 EC2의 웹 서버까지 도달하기 위해 필요한 3가지 핵심 설정(라우팅/퍼블릭 IP/보안그룹)은 무엇인가요?
1. **퍼블릭 IP (Public IPv4):** 인터넷 상에서 찾아올 수 있는 공인 주소가 EC2 인스턴스에 할당되어 있어야 합니다.
2. **라우팅 및 IGW 연결:** VPC에 Internet Gateway가 연결(`Attach`)되어 있고, 인스턴스가 속한 Public Subnet의 Route Table에 `0.0.0.0/0 → Internet Gateway` 경로가 등록 및 서브넷에 명시적으로 연결(`Associate`)되어 있어야 합니다.
3. **보안 그룹(Security Group) 및 웹 서버 프로세스:** 보안 그룹 인바운드에 `HTTP(TCP 80) <- 0.0.0.0/0` 허용 규칙이 있어야 하며, EC2 내부에서 Nginx(또는 Docker 컨테이너)가 `0.0.0.0:80` 포트를 리스닝(`LISTEN`)하고 있어야 합니다.

### Q4. 오류 발생 시 로그/증상을 근거로 원인을 가설화하고 검증 후 조치하는 트러블슈팅 과정을 어떻게 수행했나요?
- 예를 들어 SSH 접속 시 `Operation timed out` 증상이 발생했을 때, `Connection refused`(서버까지는 갔으나 데몬이 꺼짐)가 아니라 `Timed out`(패킷이 중간에 드롭됨)이라는 증상을 근거로 **“보안 그룹 22번 포트 소스 IP 불일치 또는 라우팅 누락”** 이라는 가설을 세웠습니다. 이후 `aws ec2 describe-security-groups`와 `curl https://checkip.amazonaws.com`을 대조 검증하여 사설 IP(`192.168.x.x`)가 잘못 입력된 원인을 찾았고, 내 공인 IP(`/32`)로 보안 그룹 인바운드를 수정하여 해결했습니다.

### Q5. 클라우드 과금이 발생하는 대표 요인은 무엇이며, 실습 리소스를 어떤 순서와 이유로 정리해야 하나요?
- **대표 과금 요인:** ① 중지(`Stopped`)만 해두고 종료(`Terminated`)하지 않은 인스턴스에 연결된 **EBS 볼륨(GB/월 과금)**, ② 인스턴스에 연결되지 않은 채 방치된 **Elastic IP(시간당 과금)**, ③ 시간당 고정 비용이 큰 **NAT Gateway, ALB/ELB, RDS** 등입니다.
- **정리 순서와 이유:** AWS 리소스는 부모-자식 의존성(`VPC > Subnet/IGW/SG > EC2`)이 있어 바깥쪽 VPC부터 삭제하려 하면 `DependencyViolation` 에러가 발생합니다. 따라서 가장 안쪽의 **① EC2 인스턴스 Terminate → ② Elastic IP Release & 미사용 EBS 볼륨 삭제 → ③ Internet Gateway Detach 및 삭제 → ④ Subnet · Route Table · Security Group 삭제 → ⑤ VPC 삭제 → ⑥ Billing Dashboard `$0.00` 확인** 순서로 정리해야 안전합니다.

---

## 📂 8. 프로젝트 폴더 구조

```text
5-1-/
├── README.md                          # 미션 종합 보고서 (아키텍처, 외부 접속 증빙, 요구사항/보너스, 구술 5문 5답)
├── Dockerfile                         # [보너스 2] Nginx 웹 서비스 Docker 이미지 빌드 설정
├── docker-compose.yml                 # [보너스 2] 컨테이너(80:80) 원클릭 실행 구성
├── nginx/
│   ├── default.conf                   # Nginx 설정: GET / (200 OK 웹화면) 및 GET /health (200 OK "OK")
│   └── default-ssl.conf               # [보너스 1] Let's Encrypt HTTPS(443) 설정
├── web/
│   └── index.html                     # 클라우드 웹 서비스 메인 대시보드 페이지 (Hello Cloud)
├── iam/
│   └── least-privilege-policy.json    # [요구사항 4] 서울 리전 EC2/VPC/SG 최소권한 IAM 정책 JSON
├── scripts/
│   ├── provision-aws.sh               # VPC, Public Subnet, IGW, Route Table, SG, EC2 자동 프로비저닝 스크립트
│   ├── deploy-nginx.sh                # EC2 내부 Nginx 배포 및 localhost / example.com 통신 검증 스크립트
│   ├── deploy-docker.sh               # [보너스 2] Docker 설치 및 컨테이너(80:80) 배포·검증 스크립트
│   ├── setup-https.sh                 # [보너스 1] Certbot(Let's Encrypt) HTTPS 인증서 발급 스크립트
│   └── cleanup-aws.sh                 # [요구사항 6] 과금 방지 리소스 의존성 역순 일괄 삭제 스크립트
└── docs/
    ├── architecture.png               # [제출물 1] 아키텍처 다이어그램 (PNG)
    ├── architecture.pdf               # [제출물 1] 아키텍처 다이어그램 (PDF)
    ├── troubleshooting.md             # [제출물 3] 트러블슈팅 보고서 (Markdown)
    ├── troubleshooting.pdf            # [제출물 3] 트러블슈팅 보고서 (PDF)
    ├── cleanup-checklist.md           # [제출물 4] 리소스 정리 체크리스트 (Markdown)
    └── screenshots/                   # [제출물 2 & 보너스 & 정리 증빙 스크린샷 모음]
        ├── external-browser-check.png # (A) 외부 브라우저 http://43.201.142.88 접속 화면
        ├── external-health-check.png  # (B) 외부/내부 GET /health 200 OK ("OK") 및 아웃바운드 검증 화면
        ├── docker-ps-check.png        # [보너스 2] docker ps (컨테이너 Up 상태 및 포트 매핑) 검증 화면
        └── cleanup-billing-check.png  # [제출물 4] 리소스 삭제 완료 및 Billing $0.00 확인 화면
```
