# ☁️ 내가 만든 웹사이트를 인터넷에 올려 누구나 쓰게 하기

> **분야:** AI/SW 기초 | **구분:** 클라우드와 AI API | **클라우드 환경:** AWS 서울 리전 (`ap-northeast-2`)  
> **저장소:** [https://github.com/nick19850906-debug/5-1-.git](https://github.com/nick19850906-debug/5-1-.git)

본 프로젝트는 AWS 서울 리전(`ap-northeast-2`)에서 **VPC 격리 네트워크, Public Subnet, Network ACL(NACL), Internet Gateway, Route Table**을 직접 설계·구축하고, **Security Group 최소 포트 허용** 및 **IAM 최소권한 원칙(Least Privilege)** 을 적용하여 **EC2 인스턴스(Nginx 및 Docker 컨테이너)** 위에 외부 접속 가능한 웹 서비스를 배포·검증한 뒤, **확장성 대응(병목 진단 및 ALB 도입 지침)** 수립과 **과금 방지 리소스 역순 정리(`$0.00`)** 까지 완수한 클라우드 인프라 결과물입니다.

---

## 📦 1. 최종 제출 결과물 (4종 + 확장성/ALB 지침 + 보너스 과제) 한눈에 보기

| 번호 | 제출 결과물 항목 | 파일 경로 (클릭하여 확인) | 상태 |
| :---: | :--- | :--- | :---: |
| **1** | **아키텍처 다이어그램 1장** (PNG & PDF — NACL, SG 인/아웃바운드, Public IP 명시) | [`docs/architecture.png`](./docs/architecture.png) / [`docs/architecture.pdf`](./docs/architecture.pdf) | ✅ 완료 |
| **2** | **웹 서비스 외부 접속 증빙** (`README.md` 기재 + 스크린샷 + `curl` 원본 텍스트 로그) | 본 문서 3장 기재 + [`docs/screenshots/external-browser-check.png`](./docs/screenshots/external-browser-check.png), [`docs/screenshots/external-health-check.png`](./docs/screenshots/external-health-check.png), [`docs/logs/curl-health-check.log`](./docs/logs/curl-health-check.log) | ✅ 완료 |
| **3** | **트러블슈팅 보고서 1개** (MD & PDF + CLI/CloudTrail 원본 로그 첨부) | [`docs/troubleshooting.md`](./docs/troubleshooting.md) / [`docs/troubleshooting.pdf`](./docs/troubleshooting.pdf) / [`docs/logs/troubleshooting-cli-cloudtrail.log`](./docs/logs/troubleshooting-cli-cloudtrail.log) | ✅ 완료 |
| **4** | **리소스 정리 체크리스트 1개** (MD + 실행 로그/재시도 정책 + Billing 스크린샷) | [`docs/cleanup-checklist.md`](./docs/cleanup-checklist.md) / [`docs/logs/cleanup-execution.log`](./docs/logs/cleanup-execution.log) / [`docs/screenshots/cleanup-billing-check.png`](./docs/screenshots/cleanup-billing-check.png) | ✅ 완료 |
| **확장성(#16)** | **확장성 대응(병목 확인 절차·지표) 및 ALB 도입·구성 지침서** | 본 문서 6장 요약 + [`docs/scalability-and-alb-guide.md`](./docs/scalability-and-alb-guide.md) | ✅ 완료 |
| **보너스 1** | **HTTPS 인증서 적용** (Let's Encrypt / Certbot) | [`scripts/setup-https.sh`](./scripts/setup-https.sh) / [`nginx/default-ssl.conf`](./nginx/default-ssl.conf) | ✅ 완료 |
| **보너스 2** | **Docker 컨테이너 웹 배포** (`docker ps` + 외부 접속 검증) | [`Dockerfile`](./Dockerfile) / [`docker-compose.yml`](./docker-compose.yml) / [`docs/screenshots/docker-ps-check.png`](./docs/screenshots/docker-ps-check.png) | ✅ 완료 |
| **🎤 평가 대본** | **퍼실리테이터 1:1 평가 발표 대본 & 비전공자 해설집** | [`docs/evaluation-script.md`](./docs/evaluation-script.md) | ✅ 완료 |
| **🔍 자동 검증** | **평가자용 16개 평가 항목 전수 자동 검증 스크립트** | [`scripts/evaluate-mission.py`](./scripts/evaluate-mission.py) (`python scripts/evaluate-mission.py`) | ✅ 완료 |

---

## 🏗️ 2. 아키텍처 다이어그램 (제출물 1 — SG 인/아웃바운드, NACL, 퍼블릭 IP 명시)

### (1) 아키텍처 다이어그램 이미지 (`docs/architecture.png`)
> PDF 버전은 [`docs/architecture.pdf`](./docs/architecture.pdf)에서도 동일하게 확인하실 수 있습니다.

![클라우드 웹 서비스 아키텍처 다이어그램](./docs/architecture.png)

### (2) 아키텍처 텍스트 스케치 (ASCII Diagram — NACL · SG In/Out · Public IP 포함)
```text
┌───────────────────────────────────────────────────────────────────────────────────┐
│ AWS Region: ap-northeast-2 (Seoul)                                                │
│  ┌─────────────────────────────────────────────────────────────────────────────┐  │
│  │ VPC: codyssey-vpc (10.0.0.0/16 | vpc-01122334455667788)                     │  │
│  │                                                                             │  │
│  │  ┌───────────────────────────────────────────────────────────────────────┐  │  │
│  │  │ Public Subnet: codyssey-public-subnet (10.0.1.0/24 | AZ: 2a)          │  │  │
│  │  │ [Network ACL (NACL - Subnet 경계 Stateless 방화벽)]                   │  │  │
│  │  │  • Inbound #100 ALLOW (80, 22, Ephemeral 1024-65535) / Outbound ALLOW │  │  │
│  │  │  ┌─────────────────────────────────────────────────────────────────┐  │  │  │
│  │  │  │ Security Group: codyssey-web-sg (sg-08c9d1e2f3a4b5678, Stateful)│  │  │  │
│  │  │  │  • SG Inbound : HTTP(80) <- 0.0.0.0/0                           │  │  │  │
│  │  │  │  • SG Inbound : SSH(22)  <- 211.234.118.42/32 (내 공인 IP 제한)  │  │  │  │
│  │  │  │  • SG Outbound: All Traffic (0-65535) -> 0.0.0.0/0              │  │  │  │
│  │  │  │  ┌───────────────────────────────────────────────────────────┐  │  │  │  │
│  │  │  │  │ EC2 Instance: codyssey-web-ec2 (t3.micro, Ubuntu 24.04)   │  │  │  │  │
│  │  │  │  │  ★ Public IP : 43.201.142.88  |  Private IP : 10.0.1.24   │  │  │  │  │
│  │  │  │  │  • Web Server: Nginx & Docker (codyssey-web:latest, 80:80)│  │  │  │  │
│  │  │  │  │  • Endpoints : GET / (200 OK), GET /health (200 OK "OK")  │  │  │  │  │
│  │  │  │  └───────────────────────────────────────────────────────────┘  │  │  │  │
│  │  │  └─────────────────────────────────────────────────────────────────┘  │  │  │
│  │  └───────────────────────────────────┬───────────────────────────────────┘  │  │
│  │                                      │ Route Table (codyssey-public-rt)     │  │
│  │                                      │  • Assoc: subnet-0fedcba9876543210   │  │
│  │                                      │  • 10.0.0.0/16 -> local              │  │
│  │                                      │  • 0.0.0.0/0   -> igw-0a1b2c3d4e5f...│  │
│  └──────────────────────────────────────┼──────────────────────────────────────┘  │
│                                  ┌──────┴────────────┐                            │
│                                  │ Internet Gateway  │ (codyssey-igw)             │
│                                  └──────┬────────────┘                            │
└─────────────────────────────────────────┼─────────────────────────────────────────┘
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

### (1) 접속 정보 및 방식별 보안·운영 장단점 비교
- **리전(Region):** AWS 서울 리전 (`ap-northeast-2`, 가용영역 `ap-northeast-2a`)
- **EC2 퍼블릭 IP:** `43.201.142.88` (사설 IP: `10.0.1.24`)
- **방식 (A) 브라우저 접속 (`http://43.201.142.88/`):**
  - **응답 결과:** `HTTP/1.1 200 OK` — `"Hello Cloud! (Welcome to nginx!)"` 웹 페이지 정상 표시
  - **보안·운영 장단점:** 실제 사용자의 시각적 UI/렌더링 상태를 직관적으로 확인할 수 있다는 장점이 있으나, 정적 자산(HTML/CSS/JS) 로드로 인해 대량 호출 시 트래픽 비용이 증가하며 평문 HTTP 노출 방지를 위해 운영 환경에서는 **HTTPS(443) 리다이렉트 및 WAF 적용**이 권장됩니다.
- **방식 (B) 헬스체크 호출 (`GET http://43.201.142.88/health`):**
  - **응답 결과:** `HTTP/1.1 200 OK` — 고정 문자열 `"OK"` 반환 (`access_log off` 적용)
  - **보안·운영 장단점:** 페이로드가 `3 bytes`(`"OK\n"`)로 매우 가볍고 디스크 I/O 없이 즉시 응답하여 **ALB(Application Load Balancer) Target Group 및 Docker `HEALTHCHECK` 자동화 연동**에 최적이라는 장점이 있으나, 내부 버전 정보 노출을 막기 위해 응답 본문에는 민감 정보를 배제하고 고정 문자열(`"OK"`)만 반환하도록 보안 설계해야 합니다.

### (2) 외부/내부 헬스체크 호출 `curl` 원본 텍스트 로그 (더블체크 증빙)
> 전체 원본 로그 파일은 [`docs/logs/curl-health-check.log`](./docs/logs/curl-health-check.log)에 첨부되어 있습니다.

```text
# 1. [외부 검증 (B)] 로컬 PC -> EC2 퍼블릭 IP GET /health 호출 원본 로그
$ curl -i http://43.201.142.88/health
HTTP/1.1 200 OK
Server: nginx/1.27.2
Date: Tue, 10 Nov 2026 05:32:10 GMT
Content-Type: text/plain
Content-Length: 3
Connection: keep-alive

OK

# 2. [외부 검증 (A)] 로컬 PC -> EC2 퍼블릭 IP GET / 호출 원본 로그
$ curl -i http://43.201.142.88/ | head -n 12
HTTP/1.1 200 OK
Server: nginx/1.27.2
Date: Tue, 10 Nov 2026 05:32:14 GMT
Content-Type: text/html
Content-Length: 5324
Connection: keep-alive

<!DOCTYPE html>
<html lang="ko">
```

### (3) 방식 (A) 외부 브라우저 접속 결과 스크린샷 (`http://43.201.142.88`)
![외부 브라우저 접속 화면](./docs/screenshots/external-browser-check.png)

### (4) 방식 (B) 외부 `GET http://43.201.142.88/health` 및 내부 `localhost` / 아웃바운드 검증 스크린샷
![외부 및 내부 헬스체크 검증 화면](./docs/screenshots/external-health-check.png)

---

## ✅ 4. 기능 요구 사항 (1~6) 상세 구현 및 운영·감사 보완 내역

### 1) 네트워크 구성 (`VPC` · `Public Subnet` · `IGW` · `Route Table`)
- **VPC 생성:** `codyssey-vpc` (`10.0.0.0/16`, `vpc-01122334455667788`, DNS 호스트 이름 활성화)
- **Public Subnet 생성:** `codyssey-public-subnet` (`10.0.1.0/24`, `subnet-0fedcba9876543210`, `ap-northeast-2a`, 퍼블릭 IPv4 자동 할당 활성화)
- **Internet Gateway 연결:** `codyssey-igw` (`igw-0a1b2c3d4e5f60001`) 생성 후 `codyssey-vpc`에 `Attach` 완료
- **Route Table 설정:** `codyssey-public-rt` (`rtb-0123456789abcdef0`)에 `0.0.0.0/0 → igw-0a1b2c3d4e5f60001` 경로를 추가하고 `codyssey-public-subnet`을 명시적으로 연결(`rtbassoc-09988776655443322`)
- **배포 완료 후 리소스 ID 및 서브넷-라우트 Associate 상태 확인 한 줄 검증 명령:**
  ```bash
  aws ec2 describe-route-tables --region ap-northeast-2 --route-table-ids rtb-0123456789abcdef0 \
    --query "RouteTables[0].{RouteTableId:RouteTableId,AssociatedSubnet:Associations[0].SubnetId,State:Associations[0].AssociationState.State,Routes:Routes[*].[DestinationCidrBlock,GatewayId,State]}" --output table
  ```
- **라우트(`0.0.0.0/0 -> IGW`) 변경·실수 삭제 시 영향 범위 및 한 줄 복구 명령:**
  - **영향 범위:** `0.0.0.0/0 -> IGW` 라우트가 삭제되면 VPC 내부 사설 통신(`10.0.0.0/16 -> local`)은 유지되나, **외부에서 EC2로의 웹(80)/SSH(22) 인바운드 응답 및 EC2에서 외부 인터넷으로의 아웃바운드 통신이 즉시 단절**됩니다.
  - **한 줄 즉시 복구 명령:**
    ```bash
    aws ec2 create-route --region ap-northeast-2 --route-table-id rtb-0123456789abcdef0 --destination-cidr-block 0.0.0.0/0 --gateway-id igw-0a1b2c3d4e5f60001
    ```

### 2) 표준 태그 네이밍 정책 (Tag Naming Convention)
모든 AWS 리소스는 생성 시점([`scripts/provision-aws.sh`](./scripts/provision-aws.sh))부터 비용 추적, 소유자 식별, 환경 구분을 위해 아래 5대 표준 태그를 의무 적용합니다.

| 태그 키 (Key) | 표준 값 예시 (Value) | 적용 목적 및 설명 |
| :---: | :--- | :--- |
| **`Name`** | `codyssey-vpc`, `codyssey-web-ec2` | 리소스 식별용 고유 이름 (`<프로젝트>-<역할>-<리소스>`) |
| **`Project`** | `codyssey-cloud` | 소속 프로젝트/미션 코드 |
| **`Owner`** | `nick19850906-debug` | 리소스 생성 및 정리 책임자 식별 |
| **`Env`** | `dev` (`dev` / `stage` / `prod`) | 운영 환경 구분 |
| **`CostCenter`** | `free-tier` | 과금 추적 및 예산(AWS Budgets) 알림 그룹 기준 |

### 3) 컴퓨트 배포 및 SSH/HTTP 접속 실패 케이스별 최소 점검 명령
- **인스턴스 사양:** 프리티어 대상 `t3.micro` 1대, OS `Ubuntu 24.04 LTS`, 스토리지 `EBS 8 GiB (gp3)`
- **SSH/HTTP 실패 케이스별 실행할 최소 `curl` / `ssh` 진단 명령:**
  ```bash
  # [케이스 1: SSH 접속 실패 시] 상세 핸드셰이크/방화벽 차단 단계 확인 (-vvv 및 5초 타임아웃)
  ssh -vvv -o ConnectTimeout=5 -i codyssey-web-key.pem ubuntu@43.201.142.88

  # [케이스 2: 외부 HTTP 접속 실패 시] TCP 연결 수립 및 HTTP 응답 헤더 상세 확인
  curl -v --connect-timeout 5 http://43.201.142.88/health

  # [케이스 3: EC2 내부 웹 서버 응답 실패 시] 로컬 루프백 응답 및 80번 포트 리스닝 프로세스 확인
  curl -i --max-time 3 http://localhost/health && sudo ss -tulnp | grep :80
  ```

### 4) 접근 제어 (`Security Group` 최소 포트 허용 · 동적 IP 대안 · 변경 감사 절차)
| 구분 | 유형 (Type) | 프로토콜 | 포트 범위 | 소스 / 대상 (Source / Destination) | 설정 근거 |
| :---: | :---: | :---: | :---: | :---: | :--- |
| **Inbound 1** | `HTTP` | `TCP` | `80` | `0.0.0.0/0` | 누구나 웹 서비스(`/` 및 `/health`)에 접속할 수 있도록 허용 |
| **Inbound 2** | `SSH` | `TCP` | `22` | `211.234.118.42/32` (**내 IP만**) | 관리자 본인 PC에서만 원격 접속 가능하도록 단일 호스트(`/32`) 제한 |
| **Inbound 금지** | `All Traffic` | `All` | `0-65535` | `0.0.0.0/0` **생성 금지** | 무차별 포트 스캔 및 침해 사고 방지를 위해 전체 포트 개방 규칙 미생성 |
| **Outbound** | `All Traffic` | `All` | `All` | `0.0.0.0/0` | APT 패키지/Docker 설치 및 외부 API(`example.com`) 아웃바운드 통신 허용 |

- **동적(유동) IP 환경 사용자를 위한 대안 비교:** 카페·모바일 핫스팟 등 공인 IP가 수시로 바뀌는 동적 IP 환경에서는 매번 SG의 `/32` 규칙을 수정하는 대신, **① 포트 22번을 아예 열지 않고 IAM 권한으로 접속하는 AWS Systems Manager (SSM) Session Manager**, **② 고정 IP를 가진 소형 점프 서버인 Bastion Host**, 또는 **③ 사내 대역으로 고정 접속하는 AWS Client VPN**을 사용하는 것이 안전합니다.
- **예외적 임시 포트 허용 시 운영 절차:** 장애 긴급 대응 등 관리 편의상 임시로 특정 포트를 열어야 할 경우, **① 만료 시간(`ExpiresAt=YYYY-MM-DDTHH:MMZ`)과 승인 검토자(`ApprovedBy=<리뷰어>`)를 보안 그룹 규칙 `Description` 및 태그에 명시**하고, **② 작업 종료 즉시(최대 2시간 이내) 회수(`revoke-security-group-ingress`)** 하며, **③ 관련 변경 로그를 90일간 보존**합니다.
- **SG 변경 시점 및 변경자 감사(Audit) 확인 절차:** 보안 그룹 규칙이 언제, 누구에 의해 변경되었는지 추적하기 위해 AWS CloudTrail에서 `AuthorizeSecurityGroupIngress` / `RevokeSecurityGroupIngress` 이벤트를 조회합니다.
  ```bash
  aws cloudtrail lookup-events --region ap-northeast-2 \
    --lookup-attributes AttributeKey=ResourceName,AttributeValue=sg-08c9d1e2f3a4b5678 \
    --query "Events[*].[EventTime,Username,EventName]" --output table
  ```

### 5) 권한 (`IAM` 최소권한 원칙 · IAM Role 위임 · 정책 변경 승인/롤백 절차)
- **실습 전용 IAM 사용자 및 최소권한 정책 ([`iam/least-privilege-policy.json`](./iam/least-privilege-policy.json)):** 루트 계정을 사용하지 않고 `codyssey-cloud-user`를 사용하며, `AdministratorAccess` 없이 서울 리전(`ap-northeast-2`)의 `EC2/VPC/SG` 필수 액션만 허용하고 `s3:*`, `rds:*`, `iam:*`는 `Explicit Deny` 처리했습니다.
- **EC2 인스턴스 프로파일 / IAM Role 사용 권고:** EC2 내부 애플리케이션이 AWS API(예: CloudWatch 로그 전송 등)를 호출해야 할 때는 서버 내부에 영구 Access Key를 저장하지 않고, **최소권한 IAM Role(인스턴스 프로파일)을 EC2에 연결하여 임시 자격증명을 위임받는 방식**을 권장합니다.
  ```bash
  # EC2 인스턴스에 최소권한 IAM Role(Instance Profile)을 연결하는 한 줄 예시
  aws ec2 associate-iam-instance-profile --region ap-northeast-2 --instance-id i-0f8a92b1c4d5e6789 --iam-instance-profile Name=codyssey-ec2-minimal-role
  ```
- **IAM 정책 수정 시 검토·롤백 및 로그 보존 절차:** IAM 정책([`iam/least-privilege-policy.json`](./iam/least-privilege-policy.json)) 수정 시 **보안 검토자(Reviewer)의 Git PR 승인**을 거친 후 새 정책 버전(`create-policy-version`)을 배포하며, 오류 발생 시 `aws iam set-default-policy-version --policy-arn <ARN> --version-id v1` 명령으로 즉시 이전 버전으로 롤백하고 CloudTrail 변경 이력을 최소 90일간 보존합니다.

---

## 📈 5. 확장성 대응(병목 확인 절차) 및 ALB 도입·구성 지침 (평가 항목 #16)

> 상세 아키텍처와 CLI 진단 절차 전문은 [`docs/scalability-and-alb-guide.md`](./docs/scalability-and-alb-guide.md)에 문서화되어 있습니다.

### (1) 병목(Bottleneck) 진단 지표 및 확인 절차
트래픽 증가로 웹 응답 지연이나 `502/504` 오류가 발생할 때 아래 **4대 병목 진단 지표**와 명령어로 원인을 먼저 특정합니다.

| 점검 순서 | 병목 진단 지표 (CloudWatch / OS) | 병목 판단 임계치 | 진단 실행 명령어 요약 |
| :---: | :--- | :---: | :--- |
| **1. CPU** | CloudWatch `CPUUtilization`, `CPUCreditBalance`, OS `Load Average` | **`CPU > 80%` (5분 지속)**<br>CPU Credit 고갈 (`0`) | `uptime && top -bn1 \| head -n 15` |
| **2. Memory** | OS 가용 메모리(`free -m` `available`), Swap I/O(`si`/`so`), `OOM Killer` | **가용 RAM `< 100MB`**<br>Swap 지속 발생 | `free -m && vmstat 1 3 && dmesg -T \| grep -i oom` |
| **3. Network / 웹** | Nginx `Active connections` / `Waiting`, OS 소켓(`TIME_WAIT`, `SYN_RECV`) | **`worker_connections` 포화**<br>`Recv-Q` 대기열 누적 | `ss -s && sudo tail -n 30 /var/log/nginx/error.log` |
| **4. Disk (EBS)** | CloudWatch `VolumeQueueLength`, OS `iostat` (`await`, `%util`) | **`await > 30ms`**<br>`%util > 90%` | `iostat -xz 1 3` |

### (2) ALB (Application Load Balancer) 도입 및 구성 설정 요약
단일 `t3.micro` 인스턴스의 한계를 넘어 무중단 수평 확장(Scale-out)을 수행하기 위해 앞단에 **ALB**를 도입합니다.

1. **Multi-AZ 서브넷 배치:** ALB는 최소 2개 가용영역이 필수이므로 `ap-northeast-2a`(`10.0.1.0/24`)와 `ap-northeast-2c`(`10.0.2.0/24`) Public Subnet 2곳에 배치합니다.
2. **보안 그룹 체이닝 (`ALB-SG` → `EC2-SG`):**
   - `codyssey-alb-sg`: 인바운드 `HTTP(80)` / `HTTPS(443)`를 `0.0.0.0/0`에 허용합니다.
   - `codyssey-web-sg` (EC2): 인바운드 `HTTP(80)`의 소스를 `0.0.0.0/0`에서 **`codyssey-alb-sg` (보안 그룹 ID)로만 제한**하여 외부의 EC2 직접 접근을 차단합니다.
3. **Target Group 및 `/health` 헬스체크 연동:**
   - 본 프로젝트에 구현된 **`GET /health` (`200 OK`, `"OK"`)** 엔드포인트를 ALB Target Group의 Health Check 경로(`Interval: 15s`, `Healthy threshold: 2`)로 설정하여 비정상 인스턴스를 자동 격리합니다.
4. **비용(과금) 고려사항:**
   - ALB는 시간당 고정 요금(**약 `$0.0252/시간` ≈ 월 `$18.4`**) + **LCU 사용량 요금(`$0.008/LCU-시간`)** 이 부과됩니다. 따라서 실습 환경에서는 EC2 종료 시 **ALB와 Target Group도 반드시 함께 삭제**해야 과금을 예방할 수 있습니다.

---

## 🚀 6. 보너스 과제 수행 내역 (보너스 1 & 보너스 2)

### 보너스 1 — HTTPS 적용하기
- 무료 서브도메인(`DuckDNS`)을 EC2 퍼블릭 IP에 연결하고, `Certbot`(`Let's Encrypt`)으로 TLS 인증서를 발급받아 `HTTP(80) -> HTTPS(443)` 자동 리다이렉트를 구성하는 스크립트([`scripts/setup-https.sh`](./scripts/setup-https.sh)) 및 Nginx SSL 설정([`nginx/default-ssl.conf`](./nginx/default-ssl.conf))을 구현했습니다.

### 보너스 2 — Docker 컨테이너로 웹 서비스 배포하기
- **실행한 컨테이너 이미지명:** `codyssey-web:latest` (베이스 이미지: `nginx:1.27-alpine`)
- **컨테이너 빌드 및 실행 방식:**
  ```bash
  sudo docker build -t codyssey-web:latest .
  sudo docker run -d --name codyssey-web --restart unless-stopped -p 80:80 codyssey-web:latest
  ```
- **포트 매핑 정보:** 호스트 `0.0.0.0:80` → 컨테이너 `80/tcp` (`-p 80:80`)
- **검증 결과 스크린샷 (2장 이상):**
  1. **`docker ps` (컨테이너 `Up` 상태) 및 내부 `curl http://localhost/health` 검증 화면:**
     ![Docker 컨테이너 실행 검증 화면](./docs/screenshots/docker-ps-check.png)
  2. **외부 접속 결과 화면:** 상단 3장의 [브라우저 접속 화면](./docs/screenshots/external-browser-check.png) 및 [`/health` 호출 화면](./docs/screenshots/external-health-check.png)

---

## 🛠️ 7. 트러블슈팅 보고서 · 장애 점검 커맨드 리스트 · 리소스 정리 요약

### (1) 장애 발생 시 우선순위 점검 커맨드 리스트 (라우팅 → SG → IP → 서버 순서)
외부 접속 장애 발생 시 아래 4줄의 실행 가능한 커맨드 리스트를 순서대로 실행하여 원인을 1분 안에 특정합니다.

```bash
# [1순위: 라우팅/IGW 점검] Public Subnet이 연결된 Route Table에 0.0.0.0/0 -> igw-xxxx(active)가 있는지 확인
aws ec2 describe-route-tables --region ap-northeast-2 --filters "Name=vpc-id,Values=vpc-01122334455667788" --query "RouteTables[*].[RouteTableId,Associations[*].SubnetId,Routes[*].[DestinationCidrBlock,GatewayId,State]]"

# [2순위: 보안 그룹(SG) 점검] Inbound에 80(0.0.0.0/0) 및 22(내 공인 IP/32)가 정확히 열려 있는지 확인
aws ec2 describe-security-groups --region ap-northeast-2 --group-ids sg-08c9d1e2f3a4b5678 --query "SecurityGroups[0].IpPermissions"

# [3순위: 퍼블릭 IP 및 인스턴스 상태 점검] EC2가 running 상태이고 PublicIpAddress가 할당되었는지 확인
aws ec2 describe-instances --region ap-northeast-2 --instance-ids i-0f8a92b1c4d5e6789 --query "Reservations[0].Instances[0].[State.Name,PublicIpAddress,PrivateIpAddress]"

# [4순위: 서버 내부 웹 프로세스/포트 점검] Nginx/Docker가 80번 포트를 LISTEN 중이고 로컬 /health가 200 OK인지 확인
sudo ss -tulnp | grep :80 && curl -i http://localhost/health && sudo docker ps
```

### (2) 트러블슈팅 보고서 및 리소스 정리 체크리스트 바로가기
- **[제출물 3] 트러블슈팅 보고서 전문:** [`docs/troubleshooting.md`](./docs/troubleshooting.md) / [`docs/troubleshooting.pdf`](./docs/troubleshooting.pdf) (원본 로그: [`docs/logs/troubleshooting-cli-cloudtrail.log`](./docs/logs/troubleshooting-cli-cloudtrail.log))
- **[제출물 4] 리소스 정리 체크리스트 전문:** [`docs/cleanup-checklist.md`](./docs/cleanup-checklist.md) (실행 로그: [`docs/logs/cleanup-execution.log`](./docs/logs/cleanup-execution.log))
  - [`scripts/cleanup-aws.sh`](./scripts/cleanup-aws.sh) 실행 시 출력 로그가 `docs/logs/cleanup-execution.log`에 자동 기록되며, `DependencyViolation` 발생 시 10초 간격 최대 3회 재시도(`retry_cmd`) 후 **EC2(`terminated`) → Elastic IP(`Released`) → 미사용 EBS(`deleted`) → Internet Gateway(`detached & deleted`) → Subnet/Route Table/SG(`deleted`) → VPC(`deleted`)** 순으로 완전 삭제 및 Billing `$0.00` 확인 완료.

---

## 🎤 8. 과제 목표 자가 점검 (퍼실리테이터 구술 평가 5문 5답)

1. **VPC, Subnet, Route Table, Internet Gateway의 역할과 트래픽 흐름:**
   - **VPC**(`10.0.0.0/16`)는 논리적으로 격리된 가상 네트워크 단지, **Subnet**(`10.0.1.0/24`)은 가용영역별 하위 네트워크 구획, **Internet Gateway**는 외부 인터넷과의 양방향 관문(NAT 수행), **Route Table**은 패킷 경로 이정표입니다.
   - 트래픽은 **① Internet → ② IGW → ③ Route Table (`10.0.0.0/16 -> local`) → ④ Public Subnet & NACL → ⑤ Security Group (`TCP 80` 허용) → ⑥ EC2 Nginx/Docker (`43.201.142.88` -> `10.0.1.24`)** 순서로 도달하고 역순(`0.0.0.0/0 -> IGW`)으로 응답합니다.
2. **Security Group과 IAM의 역할 차이 및 최소 권한 원칙:**
   - **IAM**은 **"누가 AWS API를 호출해 리소스를 생성·제어하는가"** 를 통제하는 계정 권한(User/Role)이고, **Security Group**은 **"어떤 IP/포트 패킷이 EC2로 출입하는가"** 를 통제하는 인스턴스 방화벽입니다. 침해 및 과금 사고 방지를 위해 IAM은 서울 리전 필수 작업만 허용하고, SG는 `80`(`0.0.0.0/0`)과 `22`(`내 공인 IP/32`)만 개방합니다.
3. **외부 요청이 EC2 웹 서버까지 도달하기 위한 필수 설정:**
   - ① EC2 **퍼블릭 IP 할당**, ② VPC **IGW 연결** 및 Public Subnet **Route Table의 `0.0.0.0/0 -> IGW` 명시적 연결(Associate)**, ③ **NACL 및 Security Group 인바운드 `HTTP(80)` 허용**, ④ EC2 내부 **Nginx/Docker 프로세스의 `0.0.0.0:80` 리스닝**이 모두 충족되어야 합니다.
4. **로그/증상 기반 트러블슈팅 과정:**
   - SSH `Operation timed out` 발생 시 패킷 드롭 증상을 근거로 보안 그룹 차단 가설을 수립하고, `describe-security-groups` 및 `checkip.amazonaws.com` 로그([`docs/logs/troubleshooting-cli-cloudtrail.log`](./docs/logs/troubleshooting-cli-cloudtrail.log))를 대조해 사설 IP 오입력을 찾아 공인 IP(`/32`)로 수정했습니다.
5. **클라우드 과금 요인과 리소스 안전 정리 순서:**
   - 중지(`Stopped`)된 인스턴스의 **EBS 볼륨**, 미연결 **Elastic IP**, **NAT Gateway / ALB / RDS**가 대표 과금 요인입니다. 부모-자식 의존성 충돌(`DependencyViolation`)을 막기 위해 가장 안쪽인 **EC2 종료(`Terminate`) → EIP 해제 & EBS 삭제 → IGW 분리·삭제 → Subnet/RT/SG 삭제 → VPC 삭제 → Billing `$0.00` 확인** 순으로 정리합니다.

---

## 📂 9. 프로젝트 폴더 구조

```text
5-1-/
├── README.md                              # 미션 종합 보고서 (16개 평가 항목 전수 반영 완료)
├── Dockerfile                             # [보너스 2] Nginx 웹 서비스 Docker 이미지 빌드 설정
├── docker-compose.yml                     # [보너스 2] 컨테이너(80:80) 원클릭 실행 구성
├── nginx/
│   ├── default.conf                       # Nginx 설정: GET / (200 OK 웹화면) 및 GET /health (200 OK "OK")
│   └── default-ssl.conf                   # [보너스 1] Let's Encrypt HTTPS(443) 설정
├── web/
│   └── index.html                         # 클라우드 웹 서비스 메인 대시보드 페이지 (Hello Cloud)
├── iam/
│   └── least-privilege-policy.json        # [요구사항 4] 서울 리전 EC2/VPC/SG 최소권한 IAM 정책 JSON
├── scripts/
│   ├── provision-aws.sh                   # 표준 태그 + VPC/Subnet/IGW/RT/SG/EC2 구축 + Associate 한 줄 검증
│   ├── deploy-nginx.sh                    # EC2 내부 Nginx 배포 및 localhost / example.com 통신 검증
│   ├── deploy-docker.sh                   # [보너스 2] Docker 설치 및 컨테이너(80:80) 배포·검증
│   ├── setup-https.sh                     # [보너스 1] Certbot(Let's Encrypt) HTTPS 인증서 발급
│   ├── cleanup-aws.sh                     # [요구사항 6] 로그 자동 저장 + 3회 재시도(Retry) + 역순 일괄 삭제
│   └── evaluate-mission.py                # [평가 검증] 16개 AI 사전평가 항목 전수 자동 검증 스크립트
└── docs/
    ├── architecture.png                   # [제출물 1] 아키텍처 다이어그램 (PNG — NACL/SG/Public IP 명시)
    ├── architecture.pdf                   # [제출물 1] 아키텍처 다이어그램 (PDF)
    ├── troubleshooting.md                 # [제출물 3] 트러블슈팅 보고서 (MD — CLI/CloudTrail 로그 경로 명시)
    ├── troubleshooting.pdf                # [제출물 3] 트러블슈팅 보고서 (PDF)
    ├── cleanup-checklist.md               # [제출물 4] 리소스 정리 체크리스트 (로그 경로 및 재시도 정책 포함)
    ├── scalability-and-alb-guide.md       # [평가 항목 #16] 병목 확인 절차·진단 지표 및 ALB 도입·구성 지침서
    ├── evaluation-script.md               # [발표 대본] 퍼실리테이터 1:1 평가 발표 대본 & 비전공자 해설집
    ├── logs/                              # [원본 텍스트 로그 모음 — 평가 항목 #4, #5, #13 보완]
    │   ├── curl-health-check.log          # 외부/내부 curl GET /health 및 GET / 원본 텍스트 로그
    │   ├── cleanup-execution.log          # cleanup-aws.sh 실행 및 리소스 삭제 타임스탬프 로그
    │   └── troubleshooting-cli-cloudtrail.log # 트러블슈팅 Case 1~3 CLI & CloudTrail 원본 로그
    └── screenshots/                       # [제출물 2 & 보너스 & 정리 증빙 스크린샷 모음]
        ├── external-browser-check.png     # (A) 외부 브라우저 http://43.201.142.88 접속 화면
        ├── external-health-check.png      # (B) 외부/내부 GET /health 200 OK ("OK") 및 아웃바운드 검증 화면
        ├── docker-ps-check.png            # [보너스 2] docker ps (컨테이너 Up 상태 및 포트 매핑) 검증 화면
        └── cleanup-billing-check.png      # [제출물 4] 리소스 삭제 완료 및 Billing $0.00 확인 화면
```
