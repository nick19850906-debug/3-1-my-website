# 🛠️ 클라우드 웹 서비스 구축 트러블슈팅 보고서 (Troubleshooting Report)

- **프로젝트:** 내가 만든 웹사이트를 인터넷에 올려 누구나 쓰게 하기 (AWS 클라우드 인프라 구축 및 배포)
- **리전(Region):** 서울 리전 (`ap-northeast-2`)
- **대상 환경:** VPC (`10.0.0.0/16`), Public Subnet (`10.0.1.0/24`), Internet Gateway, EC2 (`t3.micro`, Ubuntu 24.04 LTS), Nginx / Docker (`codyssey-web:latest`)

---

## 📋 요약 표 (3건의 핵심 트러블슈팅)

| 번호 | 구분 | 증상 (문제 상황) | 핵심 원인 | 최종 결과 |
| :---: | :---: | :--- | :--- | :---: |
| **Case 1** | **보안 그룹 (SSH 22)** | EC2 생성 후 `ssh -i key.pem ubuntu@43.201.142.88` 접속 시 `Connection timed out` 발생 | 보안 그룹 인바운드 22번 포트에 사설 IP(`192.168.x.x/32`)를 입력하여 공인 IP와 불일치 | **해결 완료** (공인 IP `/32` 반영 후 접속 성공) |
| **Case 2** | **라우팅 (Route Table)** | 외부에서 `http://43.201.142.88` 접속 불가 및 인스턴스 아웃바운드(`curl https://example.com`) 실패 | Public Route Table에 `0.0.0.0/0 → igw-xxxx` 경로를 추가했으나 **Public Subnet 명시적 연결(Association)** 누락 | **해결 완료** (`200 OK` 정상 응답 확인) |
| **Case 3** | **권한 (IAM 최소권한)** | IAM 사용자로 EC2 생성 시 `UnauthorizedOperation` 권한 거부 오류 발생 | 최소권한 정책 작성 시 인스턴스 태그 지정을 위한 `ec2:CreateTags` 액션 누락 | **해결 완료** (`AdministratorAccess` 없이 최소 액션만 추가) |

---

## 🔍 Case 1. 보안 그룹(Security Group) SSH 22번 포트 접속 타임아웃 오류

| 항목 | 상세 내용 |
| :--- | :--- |
| **1. 증상 (문제 상황)** | Public Subnet에 EC2 인스턴스(`i-0f8a92b1c4d5e6789`, 퍼블릭 IP `43.201.142.88`)를 생성하고 `running` 상태를 확인했으나, 로컬 터미널에서 SSH 접속 시도 시 응답 없이 대기하다가 에러가 발생함.<br>`ssh: connect to host 43.201.142.88 port 22: Operation timed out` |
| **2. 원인 가설** | - **가설 A:** EC2 인스턴스에 퍼블릭 IP가 할당되지 않았거나 상태 검사가 실패했다.<br>- **가설 B:** 보안 그룹(`codyssey-web-sg`) 인바운드 규칙에서 `SSH(22)` 허용 소스 IP가 현재 학습자 PC의 실제 **공인 IP(Public IP)** 와 일치하지 않아 패킷이 드롭(Drop)되었다. (`Connection refused`가 아닌 `Operation timed out`은 방화벽/보안 그룹 차단 시 나타나는 대표 증상임) |
| **3. 검증 방법** | 1. AWS 콘솔 및 CLI로 보안 그룹 인바운드 규칙 조회:<br>`aws ec2 describe-security-groups --group-ids sg-08c9d1e2f3a4b5678 --query "SecurityGroups[0].IpPermissions"`<br>→ 확인 결과: `22/tcp` 소스가 Windows `ipconfig`에서 본 공유기 내부 사설 IP(`192.168.0.15/32`)로 잘못 등록되어 있었음.<br>2. 현재 PC의 외부 공인 IP 확인:<br>`curl -s https://checkip.amazonaws.com` → `211.234.118.42` 반환 확인. |
| **4. 조치 내용** | `0.0.0.0/0` 전체 허용은 보안 원칙에 위배되므로, 잘못 등록된 사설 IP 규칙을 제거하고 확인된 **학습자 공인 IP(`211.234.118.42/32`)만 허용**하도록 보안 그룹 인바운드 규칙을 수정함.<br>```bash\naws ec2 revoke-security-group-ingress --group-id sg-08c9d1e2f3a4b5678 --protocol tcp --port 22 --cidr 192.168.0.15/32\naws ec2 authorize-security-group-ingress --group-id sg-08c9d1e2f3a4b5678 --protocol tcp --port 22 --cidr 211.234.118.42/32\n``` |
| **5. 결과** | 즉시 SSH 접속(`ssh -i codyssey-web-key.pem ubuntu@43.201.142.88`)에 성공하여 Ubuntu 쉘 프롬프트(`ubuntu@ip-10-0-1-24:~$`) 진입 확인. |
| **6. 재발 방지** | 1. 보안 그룹에 내 IP를 등록할 때는 `ipconfig`(사설 IP)가 아니라 반드시 `curl -s https://checkip.amazonaws.com` 또는 AWS 콘솔의 **My IP** 기능을 사용한다.<br>2. 프로비저닝 스크립트(`scripts/provision-aws.sh`)에 `MY_IP="$(curl -s https://checkip.amazonaws.com)/32"` 자동 감지 로직을 반영하여 수동 입력 실수를 원천 차단한다. |

---

## 🔍 Case 2. Public Subnet 라우팅 테이블 연결 누락으로 인한 외부 통신 불가 오류

| 항목 | 상세 내용 |
| :--- | :--- |
| **1. 증상 (문제 상황)** | 1. 외부 브라우저에서 `http://43.201.142.88` 및 `GET http://43.201.142.88/health` 호출 시 접속 불가(`ERR_CONNECTION_TIMED_OUT`).<br>2. 인스턴스 내부에서 아웃바운드 통신 테스트(`curl -I https://example.com` 및 `sudo apt-get update`) 실행 시 외부 인터넷으로 나가지 못하고 타임아웃 발생. |
| **2. 원인 가설** | - **가설 A:** 보안 그룹 인바운드에 `HTTP(80)` `0.0.0.0/0` 규칙이 누락되었다.<br>- **가설 B:** Internet Gateway(`igw-0a1b2c3d4e5f60001`)가 VPC에 연결되지 않았거나, Public Route Table(`rtb-0123456789abcdef0`)에 `0.0.0.0/0 → igw` 경로를 만든 뒤 **Public Subnet(`subnet-0fedcba9876543210`)과의 명시적 서브넷 연결(Explicit Subnet Association)** 을 누락하여 기본(Main) 로컬 라우팅 테이블을 바라보고 있다. |
| **3. 검증 방법** | 1. 보안 그룹 확인 결과 `HTTP(80) 0.0.0.0/0` 인바운드와 아웃바운드 전체 허용 규칙은 정상 존재함.<br>2. 라우팅 테이블 연결 상태 조회:<br>`aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-01122334455667788"`<br>→ 확인 결과: `codyssey-public-rt`에 `0.0.0.0/0 → igw-0a1b2c3d4e5f60001` 경로는 있었으나, `Associations` 배열이 비어 있어 Public Subnet이 인터넷 경로가 없는 기본(Main) Route Table(`10.0.0.0/16 -> local`만 존재)을 사용하고 있었음. |
| **4. 조치 내용** | `codyssey-public-rt` 라우팅 테이블을 `codyssey-public-subnet`(`10.0.1.0/24`)에 명시적으로 연결(Associate) 조치를 수행함.<br>```bash\naws ec2 associate-route-table \\\n  --region ap-northeast-2 \\\n  --route-table-id rtb-0123456789abcdef0 \\\n  --subnet-id subnet-0fedcba9876543210\n``` |
| **5. 결과** | 1. 인스턴스 내부 아웃바운드 통신 확인: `curl -I https://example.com` 실행 시 `HTTP/2 200` 즉시 반환.<br>2. Nginx 및 Docker 웹 컨테이너 설치 완료 후 내부 `curl -i http://localhost` → `HTTP/1.1 200 OK` 확인.<br>3. 외부에서 브라우저(`http://43.201.142.88`) 및 헬스체크(`curl -i http://43.201.142.88/health`) 호출 시 `200 OK` 및 `"OK"` 정상 응답 확인. |
| **6. 재발 방지** | VPC 네트워크 구축 시 **① IGW 생성 → ② VPC에 Attach → ③ Route Table에 `0.0.0.0/0 -> IGW` 경로 추가 → ④ Public Subnet에 Route Table 명시적 연결(Associate)** 의 4단계를 하나의 세트로 검증하는 체크리스트를 배포 표준으로 수립한다. |

---

## 🔍 Case 3. IAM 최소권한(Least Privilege) 정책 적용 중 리소스 태그 생성 거부 오류

| 항목 | 상세 내용 |
| :--- | :--- |
| **1. 증상 (문제 상황)** | 루트 계정 대신 실습 전용 IAM 사용자(`codyssey-cloud-user`)로 전환한 뒤, `--tag-specifications` 옵션을 포함해 EC2 인스턴스를 생성하려 하자 권한 거부 오류 발생:<br>`An error occurred (UnauthorizedOperation) when calling the RunInstances operation: You are not authorized to perform this operation. Encoded authorization failure message: ...` |
| **2. 원인 가설** | - **가설 A:** IAM 정책에 `ec2:RunInstances` 권한 자체가 빠졌다.<br>- **가설 B:** `ec2:RunInstances` 권한은 부여했으나, 인스턴스 생성과 동시에 `Name=codyssey-web-ec2` 태그를 부착할 때 필요한 **`ec2:CreateTags`** 액션 권한이 최소권한 정책 JSON에서 누락되었다. |
| **3. 검증 방법** | AWS STS로 암호화된 권한 오류 메시지를 디코딩하여 정확히 어떤 Action이 거부되었는지 로그를 분석함:<br>`aws sts decode-authorization-message --encoded-message <암호화된메시지>`<br>→ 디코딩된 JSON 로그에서 `"action": "ec2:CreateTags"`, `"matchedStatements": []` 항목이 거부 원인임을 정확히 확인함. |
| **4. 조치 내용** | `AdministratorAccess`(관리자 전체 권한)를 부여하는 손쉬운 우회 방식을 지양하고, 최소권한 원칙을 유지한 채 `iam/least-privilege-policy.json`의 서울 리전(`ap-northeast-2`) 제한 Statement 안에 `ec2:CreateTags`, `ec2:DeleteTags` 액션만 정밀하게 추가함. (S3, RDS, IAM 등 무관한 서비스는 `ExplicitDeny` 유지) |
| **5. 결과** | `codyssey-cloud-user` 계정으로 태그가 포함된 VPC, Subnet, IGW, Security Group, EC2 리소스가 오류 없이 정상 생성됨을 확인. |
| **6. 재발 방지** | IAM 최소권한 정책 설계 시 주 작업(`RunInstances`, `CreateVpc`)뿐만 아니라 리소스 식별·관리를 위해 함께 호출되는 보조 작업(`CreateTags`, `Describe*`)을 함께 정의하고, 권한 오류 발생 시 무조건 권한을 넓히지 않고 `sts decode-authorization-message` 또는 CloudTrail 로그로 정확한 누락 Action만 핀셋 추가한다. |

