# 📈 확장성 대응(병목 확인 절차) 및 ALB 도입·구성 지침서 (평가 항목 #16)

> **💡 비전공자 눈높이 한 줄 비유:**  
> 처음에는 **1인 셰프 식당(`단일 EC2 t3.micro`)** 으로 오픈했지만, 손님(트래픽)이 몰려 줄이 길어지면 **① 어디가 막히는지(주방 화구 부족=CPU, 좌석 부족=Memory, 출입문 정체=Network) 먼저 진단(병목 확인)** 하고, **② 매장 입구에 지배인(`ALB, Application Load Balancer`)을 세워 여러 주방(`다중 EC2 + Auto Scaling`)으로 손님을 골고루 안내**하는 확장 설계도입니다.

---

## 1. 병목(Bottleneck) 확인 절차 및 핵심 진단 지표

웹 서비스 응답이 느려지거나 간헐적인 타임아웃(`502 Bad Gateway`, `504 Gateway Timeout`)이 발생할 때, 무작정 서버 사양을 올리지 않고 **4단계 순서(클라우드 지표 → OS 자원 → 네트워크/연결 → 애플리케이션 로그)** 로 병목 지점을 특정합니다.

### (1) 병목 진단 핵심 지표 및 기준치 (Threshold)

| 진단 영역 | 주요 확인 지표 (CloudWatch / OS) | 정상 범위 | 병목 의심 임계치 (조치 기준) | 병목 원인 및 증상 |
| :---: | :--- | :---: | :---: | :--- |
| **1. CPU (연산)** | • CloudWatch `CPUUtilization`<br>• `CPUCreditBalance` (`t3.micro` 버스트 잔량)<br>• OS `Load Average` (`uptime`, `top`) | `< 60%`<br>Credit `> 30` | **`> 80%` (5분 이상 지속)**<br>Credit 고갈 (`0` 근접) | 동시 요청 급증 또는 SSL/TLS 핸드셰이크 과부하로 응답 지연 발생 |
| **2. Memory (메모리)** | • OS `available` 메모리 (`free -m`)<br>• Swap 사용량 (`vmstat 1 5`)<br>• OOM Killer 발생 여부 (`dmesg -T`) | 가용 `> 20%`<br>Swap `0 MB` | **가용 `< 10%` (`< 100MB`)**<br>`si`/`so`(Swap I/O) 지속 발생 | `t3.micro`(`1GiB` RAM) 한계 초과로 인한 워커 프로세스 강제 종료(`OOM`) |
| **3. Network / 소켓** | • CloudWatch `NetworkIn` / `NetworkOut`<br>• Nginx `Active connections` / `Waiting`<br>• OS 소켓 상태 (`ss -s`, `TIME_WAIT`) | 연결 즉시 처리<br>`SYN_RECV` `< 10` | **`worker_connections` 포화**<br>대기 큐(`Send-Q`/`Recv-Q`) 누적 | 단일 EC2의 동시 연결 한계 도달로 신규 접속 타임아웃 발생 |
| **4. Disk I/O (EBS)** | • CloudWatch `VolumeQueueLength`<br>• OS `iostat -xz 1` (`%util`, `await`) | `await < 10ms`<br>`%util < 70%` | **`await > 30ms`**<br>`%util > 90%` 지속 | 과도한 액세스 로그 기록 또는 스왑 발생으로 디스크 병목 |

### (2) 실전 병목 확인 명령어 절차 (Step-by-Step)

```bash
# [Step 1] AWS CLI로 최근 10분간 EC2 CPU 사용률(CPUUtilization) 병목 여부 확인
aws cloudwatch get-metric-statistics \
  --region ap-northeast-2 \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-0f8a92b1c4d5e6789 \
  --start-time "$(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --period 60 --statistics Average Maximum

# [Step 2] EC2 내부 접속 후 CPU 부하(Load Average), 메모리/스왑(free -m), I/O 대기(vmstat) 즉시 점검
uptime && free -m && vmstat 1 3

# [Step 3] 네트워크 소켓 상태(ESTABLISHED / TIME_WAIT / SYN_RECV) 및 포트 큐 적체 확인
ss -s && ss -tulnp | grep :80

# [Step 4] Nginx 연결 한계 초과 에러('worker_connections are not enough') 및 느린 응답 로그 확인
sudo tail -n 50 /var/log/nginx/error.log
```

---

## 2. 단계별 확장 전략 및 ALB(Application Load Balancer) 도입·구성 지침

단일 `t3.micro` 인스턴스에서 병목이 확인되면 서비스 중단을 막기 위해 **단기(Scale-up)** 와 **중장기(Scale-out + ALB 도입)** 전략을 순차 적용합니다.

### (1) 아키텍처 전환: 단일 EC2 → ALB + Multi-AZ 다중 EC2 구성
```text
                        [ Internet (0.0.0.0/0) ]
                                   │ (HTTP 80 / HTTPS 443)
                                   ▼
                 ┌───────────────────────────────────┐
                 │  Internet Gateway (codyssey-igw)  │
                 └─────────────────┬─────────────────┘
                                   │
     ┌─────────────────────────────┴─────────────────────────────┐
     │ VPC (10.0.0.0/16 | ap-northeast-2 서울 리전)              │
     │  ┌─────────────────────────────────────────────────────┐  │
     │  │ [ALB] codyssey-alb (SG: alb-sg | 80, 443 Open)      │  │
     │  │  • 가용영역 최소 2개 이상 배치 (2a: 10.0.1.0/24,    │  │
     │  │    2c: 10.0.2.0/24)                                 │  │
     │  │  • Health Check: GET /health (200 OK "OK", 30s 주기)│  │
     │  └──────────────┬───────────────────────┬──────────────┘  │
     │                 │ (SG 체이닝: alb-sg만 허용)              │
     │                 ▼                       ▼                 │
     │  ┌──────────────────────────┐ ┌──────────────────────────┐│
     │  │ [AZ-2a] EC2 Web #1       │ │ [AZ-2c] EC2 Web #2       ││
     │  │ (SG: ec2-sg | 80<-alb-sg)│ │ (SG: ec2-sg | 80<-alb-sg)││
     │  │ Nginx/Docker (:80)       │ │ Nginx/Docker (:80)       ││
     │  └──────────────────────────┘ └──────────────────────────┘│
     └───────────────────────────────────────────────────────────┘
```

### (2) ALB 도입 시 핵심 설정 요약 (4대 구성 요소)

1. **Multi-AZ 서브넷 구성 (필수 조건):**
   - AWS ALB는 고가용성을 위해 **최소 2개 이상의 서로 다른 가용영역(AZ)** 에 속한 Public Subnet이 필요합니다.
   - 기존 `ap-northeast-2a` (`10.0.1.0/24`) 외에 `ap-northeast-2c` (`10.0.2.0/24`) Public Subnet을 추가 생성하고 동일한 Public Route Table(`0.0.0.0/0 -> IGW`)에 연결합니다.
2. **보안 그룹 체이닝 (Security Group Chaining — 핵심 보안 설정):**
   - **ALB 보안 그룹 (`codyssey-alb-sg`):** 인바운드 `HTTP(80)`, `HTTPS(443)`를 `0.0.0.0/0`에 허용합니다.
   - **EC2 보안 그룹 (`codyssey-web-sg`):** 인바운드 `HTTP(80)`의 소스(Source)를 기존 `0.0.0.0/0`에서 **`codyssey-alb-sg` (보안 그룹 ID 참조)** 로 변경합니다. 이렇게 하면 외부 사용자가 퍼블릭 IP로 EC2에 직접 우회 접속하는 것을 차단하고 오직 ALB를 통과한 정상 트래픽만 받을 수 있습니다.
3. **대상 그룹 (Target Group) 및 `/health` 헬스체크 연동:**
   - **Target Type:** `Instance` (프로토콜 `HTTP`, 포트 `80`)
   - **Health Check 경로:** 본 미션에서 구현한 **`GET /health`** (`Matcher: 200`, 응답 본문 `"OK"`)를 그대로 사용합니다.
   - **헬스체크 파라미터:** `Interval: 15s`, `Timeout: 5s`, `Healthy threshold: 2`, `Unhealthy threshold: 2` (특정 EC2가 장애 시 30초 내 자동 격리 및 정상 인스턴스로만 트래픽 라우팅)
4. **SSL/TLS 종료 (HTTPS Offloading):**
   - AWS Certificate Manager(ACM)에서 발급한 무료 인증서를 ALB의 `HTTPS(443)` 리스너에 부착하면, 암호화/복호화 연산을 ALB가 전담하여 뒷단 EC2(`t3.micro`)의 CPU 병목을 크게 줄일 수 있습니다.

### (3) ALB 도입 시 비용(과금) 고려사항 및 운영 주의점

| 비용 항목 | 서울 리전(`ap-northeast-2`) 과금 기준 | 운영 및 실습 정리 시 주의사항 |
| :--- | :--- | :--- |
| **ALB 시간당 고정 요금** | 약 **`$0.0252 / 시간`** (월 약 `$18.4` 수준)<br>*(신규 계정 프리티어: 월 750시간 무료 제공)* | EC2를 모두 종료(`Terminate`)했더라도 **ALB가 삭제되지 않고 남아 있으면 매시간 고정 요금이 부과**되므로 실습 종료 시 반드시 최우선 삭제 대상에 포함해야 함 |
| **LCU (용량 단위) 요금** | **`$0.008 / LCU-시간`**<br>(신규 연결 수, 활성 연결 수, 처리 바이트, 규칙 평가 수 중 최댓값 기준) | 트래픽 스파이크 또는 DDoS 공격 시 LCU 요금이 증가할 수 있으므로 AWS Budgets 예산 알림 설정 필수 |
| **다중 EC2 인스턴스 요금** | 프리티어 월 750시간은 **모든 micro 인스턴스 합산 시간** 기준 (2대 동시 가동 시 375시간 만에 소진) | 평상시에는 최소 대수(`Min=1, Desired=1`)로 운영하고, CPU `> 70%` 병목 시에만 `Max=2`로 늘리는 Auto Scaling 정책 권장 |
