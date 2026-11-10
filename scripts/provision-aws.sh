#!/usr/bin/env bash
# ==============================================================================
# [파일 이름] scripts/provision-aws.sh
# [파일 역할] 미션 기능 요구사항 1~3번(VPC, Public Subnet, IGW, Route Table, Security Group, EC2)을
#            AWS 서울 리전(ap-northeast-2)에 순서대로 건설하는 인프라 자동 구축 스크립트입니다.
# [실생활 비유] 허허벌판 땅(AWS)에 ① 아파트 단지 울타리(VPC)를 치고 -> ② 1층 상가 구역(Public Subnet)을 나누고
#             -> ③ 단지 정문(IGW)과 이정표(Route Table)를 세운 뒤 -> ④ 경비 초소(Security Group)와
#             ⑤ 실제 매장 건물(EC2)을 짓는 '건축 시공 순서도'입니다.
# ==============================================================================

# [안전장치 설정]
# -e : 명령어 중 하나라도 에러가 나면 즉시 멈춰서 사고를 예방합니다.
# -u : 만들지 않은 빈 변수를 실수로 쓰면 즉시 알려줍니다.
# -o pipefail : 파이프(|)로 연결된 명령어 중간에 에러가 나도 놓치지 않고 잡아냅니다.
set -euo pipefail

# [0구역: 공사에 사용할 기본 설계 치수(변수) 정의]
REGION="ap-northeast-2"        # 제약 사항: 모든 리소스는 반드시 '서울 리전(ap-northeast-2)'에 생성합니다.
AZ="ap-northeast-2a"           # 서울 리전 안의 첫 번째 데이터센터 건물(가용영역 2a)을 지정합니다.
VPC_CIDR="10.0.0.0/16"         # VPC 전체 주소 범위 (약 65,536개의 사설 IP를 담는 큰 단지)
SUBNET_CIDR="10.0.1.0/24"      # Public Subnet 주소 범위 (약 256개의 IP를 담는 1층 상가 구역)
INSTANCE_TYPE="t3.micro"       # 제약 사항: 과금이 없는 프리티어(Free Tier) 대상 micro 급 서버 사양
KEY_NAME="codyssey-web-key"    # SSH 원격 접속에 사용할 열쇠(키페어) 이름

# [보안 핵심!] 현재 내 컴퓨터의 실제 외부 '공인 IP'를 자동으로 물어봐서 뒤에 '/32'(딱 이 IP 1개만!)를 붙입니다.
# - 왜 필요한가요? Windows 'ipconfig'에 나오는 192.168.x.x는 집 안 공유기 사설 IP라서 AWS가 알아보지 못합니다.
# - checkip.amazonaws.com 에 물어보면 내 진짜 인터넷 공인 IP를 알려주어 SSH(22) 접속 타임아웃 사고를 막아줍니다!
MY_IP="$(curl -s https://checkip.amazonaws.com)/32"
echo "[INFO] 학습자 본인 공인 IP 감지 완료 (SSH 22번 포트 단독 허용 대상): ${MY_IP}"

# ------------------------------------------------------------------------------
# [1구역: VPC 생성 — 나만의 격리된 가상 네트워크 단지(10.0.0.0/16) 만들기]
# ------------------------------------------------------------------------------
# - create-vpc : 새 VPC를 만듭니다.
# - --tag-specifications : 리소스 이름표(Name=codyssey-vpc)를 붙여서 나중에 찾거나 지우기 쉽게 합니다.
# - --query 'Vpc.VpcId' --output text : 만들어진 VPC의 고유 번호(예: vpc-01122334455667788)만 깔끔하게 뽑아냅니다.
VPC_ID=$(aws ec2 create-vpc \
  --region "${REGION}" \
  --cidr-block "${VPC_CIDR}" \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=codyssey-vpc}]' \
  --query 'Vpc.VpcId' --output text)

# VPC 내부의 서버가 도메인 이름(DNS 호스트네임)을 가질 수 있도록 옵션을 켭니다.
aws ec2 modify-vpc-attribute --region "${REGION}" --vpc-id "${VPC_ID}" --enable-dns-hostnames "{\"Value\":true}"
echo "[1/6] VPC 생성 완료: ${VPC_ID} (${VPC_CIDR})"

# ------------------------------------------------------------------------------
# [2구역: Public Subnet 생성 — 외부 손님이 찾아올 수 있는 1층 구역(10.0.1.0/24) 만들기]
# ------------------------------------------------------------------------------
SUBNET_ID=$(aws ec2 create-subnet \
  --region "${REGION}" \
  --vpc-id "${VPC_ID}" \
  --cidr-block "${SUBNET_CIDR}" \
  --availability-zone "${AZ}" \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=codyssey-public-subnet}]' \
  --query 'Subnet.SubnetId' --output text)

# [매우 중요!] 이 서브넷에 만들어지는 EC2 서버에 외부 인터넷용 '퍼블릭 IP'가 자동으로 부여되도록 옵션을 켭니다.
aws ec2 modify-subnet-attribute --region "${REGION}" --subnet-id "${SUBNET_ID}" --map-public-ip-on-launch
echo "[2/6] Public Subnet 생성 완료: ${SUBNET_ID} (${SUBNET_CIDR})"

# ------------------------------------------------------------------------------
# [3구역: Internet Gateway(IGW) 생성 및 VPC 부착 — 단지 정문 톨게이트 세우기]
# ------------------------------------------------------------------------------
# 1) 정문(Internet Gateway) 구조물을 먼저 만들고,
IGW_ID=$(aws ec2 create-internet-gateway \
  --region "${REGION}" \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=codyssey-igw}]' \
  --query 'InternetGateway.InternetGatewayId' --output text)

# 2) 만들어진 정문(IGW)을 우리 아파트 단지(VPC)에 찰칵 부착(attach)합니다.
aws ec2 attach-internet-gateway --region "${REGION}" --vpc-id "${VPC_ID}" --internet-gateway-id "${IGW_ID}"
echo "[3/6] Internet Gateway 생성 및 VPC 연결 완료: ${IGW_ID}"

# ------------------------------------------------------------------------------
# [4구역: Route Table 설정 — "인터넷(0.0.0.0/0)으로 갈 때는 정문(IGW)으로 가라!" 이정표 세우기]
# ------------------------------------------------------------------------------
# 1) 새 이정표 게시판(Route Table)을 만듭니다.
RTB_ID=$(aws ec2 create-route-table \
  --region "${REGION}" \
  --vpc-id "${VPC_ID}" \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=codyssey-public-rt}]' \
  --query 'RouteTable.RouteTableId' --output text)

# 2) 이정표에 "모든 외부 인터넷 목적지(0.0.0.0/0)는 정문(${IGW_ID})으로 나가라"는 길을 적습니다.
aws ec2 create-route --region "${REGION}" --route-table-id "${RTB_ID}" --destination-cidr-block "0.0.0.0/0" --gateway-id "${IGW_ID}"

# 3) [트러블슈팅 Case 2 핵심!] 이정표를 1층 구역(Public Subnet)에 명시적으로 연결(associate)합니다.
#    (이 줄을 빼먹으면 서브넷이 길을 못 찾아서 외부 접속도 안 되고 curl https://example.com 도 실패합니다!)
aws ec2 associate-route-table --region "${REGION}" --route-table-id "${RTB_ID}" --subnet-id "${SUBNET_ID}"
echo "[4/6] Route Table 경로(0.0.0.0/0 -> ${IGW_ID}) 및 서브넷 연결 완료: ${RTB_ID}"

# ------------------------------------------------------------------------------
# [5구역: Security Group(보안 그룹) 설정 — 문지기 출입 명부 만들기 (최소 포트 허용 원칙)]
# ------------------------------------------------------------------------------
SG_ID=$(aws ec2 create-security-group \
  --region "${REGION}" \
  --group-name "codyssey-web-sg" \
  --description "Allow HTTP(80) from anywhere and SSH(22) from learner IP only" \
  --vpc-id "${VPC_ID}" \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=codyssey-web-sg}]' \
  --query 'GroupId' --output text)

# 규칙 1: 웹 서비스 포트인 HTTP(80번)는 누구나 홈페이지를 볼 수 있도록 전체(0.0.0.0/0) 허용합니다.
aws ec2 authorize-security-group-ingress \
  --region "${REGION}" \
  --group-id "${SG_ID}" \
  --protocol tcp --port 80 --cidr "0.0.0.0/0"

# 규칙 2: 서버 관리용 포트인 SSH(22번)는 해킹 방지를 위해 오직 '내 공인 IP(${MY_IP})'에서만 들어오게 잠급니다.
#         (미션 요구사항 3: 0.0.0.0/0에 대해 전체 포트 0-65535 허용 규칙은 절대 생성하지 않음!)
aws ec2 authorize-security-group-ingress \
  --region "${REGION}" \
  --group-id "${SG_ID}" \
  --protocol tcp --port 22 --cidr "${MY_IP}"
echo "[5/6] Security Group 생성 완료: ${SG_ID} (HTTP 80: 전체 허용, SSH 22: ${MY_IP} 단독 허용)"

# ------------------------------------------------------------------------------
# [6구역: EC2 인스턴스 생성 — Ubuntu 24.04 LTS 가상 컴퓨터(t3.micro, 8GiB) 켜기]
# ------------------------------------------------------------------------------
# 최신 Ubuntu 24.04 LTS 공식 이미지 번호(AMI ID)를 조회합니다.
AMI_ID=$(aws ec2 describe-images \
  --region "${REGION}" \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text)

# Public Subnet 안에, 방금 만든 보안 그룹(SG_ID)을 씌워서 EC2 1대를 생성합니다.
# - DeleteOnTermination=true : 나중에 실습이 끝나서 EC2를 종료(Terminate)하면 하드디스크(EBS 8GiB)도
#                              자동으로 함께 삭제되게 하여 잔여 EBS 과금 사고를 예방합니다!
INSTANCE_ID=$(aws ec2 run-instances \
  --region "${REGION}" \
  --image-id "${AMI_ID}" \
  --instance-type "${INSTANCE_TYPE}" \
  --key-name "${KEY_NAME}" \
  --subnet-id "${SUBNET_ID}" \
  --security-group-ids "${SG_ID}" \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":8,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=codyssey-web-ec2}]' \
  --query 'Instances[0].InstanceId' --output text)

echo "[6/6] EC2 인스턴스 생성 완료: ${INSTANCE_ID} (${INSTANCE_TYPE}, EBS 8GiB) — 부팅 대기 중..."
aws ec2 wait instance-running --region "${REGION}" --instance-ids "${INSTANCE_ID}"

# 부여된 외부 접속용 퍼블릭 IP 주소를 조회하여 화면에 출력합니다.
PUBLIC_IP=$(aws ec2 describe-instances \
  --region "${REGION}" \
  --instance-ids "${INSTANCE_ID}" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "=================================================================="
echo " 🎉 클라우드 인프라 구축 완료!"
echo " • 할당된 퍼블릭 IP : ${PUBLIC_IP}"
echo " • (A) 브라우저 접속: http://${PUBLIC_IP}"
echo " • (B) 헬스체크 호출: http://${PUBLIC_IP}/health"
echo "=================================================================="
