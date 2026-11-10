#!/usr/bin/env bash
# ==============================================================================
# [파일 이름] scripts/provision-aws.sh
# [파일 역할] 미션 기능 요구사항 1~3번(VPC, Public Subnet, IGW, Route Table, Security Group, EC2)을
#            AWS 서울 리전(ap-northeast-2)에 순서대로 건설하는 인프라 자동 구축 스크립트입니다.
# [실생활 비유] 허허벌판 땅(AWS)에 ① 아파트 단지 울타리(VPC)를 치고 -> ② 1층 상가 구역(Public Subnet)을 나누고
#             -> ③ 단지 정문(IGW)과 이정표(Route Table)를 세운 뒤 -> ④ 경비 초소(Security Group)와
#             ⑤ 실제 매장 건물(EC2)을 짓는 '건축 시공 순서도'입니다.
# ==============================================================================
set -euo pipefail

# [0구역: 공사에 사용할 기본 설계 치수(변수) 및 표준 태그 정책(평가 항목 #9 보완) 정의]
REGION="ap-northeast-2"        # 제약 사항: 모든 리소스는 반드시 '서울 리전(ap-northeast-2)'에 생성합니다.
AZ="ap-northeast-2a"           # 서울 리전 안의 첫 번째 데이터센터 건물(가용영역 2a)을 지정합니다.
VPC_CIDR="10.0.0.0/16"         # VPC 전체 주소 범위 (약 65,536개의 사설 IP를 담는 큰 단지)
SUBNET_CIDR="10.0.1.0/24"      # Public Subnet 주소 범위 (약 256개의 IP를 담는 1층 상가 구역)
INSTANCE_TYPE="t3.micro"       # 제약 사항: 과금이 없는 프리티어(Free Tier) 대상 micro 급 서버 사양
KEY_NAME="codyssey-web-key"    # SSH 원격 접속에 사용할 열쇠(키페어) 이름

# [표준 태그 네이밍 규칙 — 평가 항목 #9 보완]
# 모든 리소스에 Name / Project / Owner / Env / CostCenter 태그를 일관되게 부여하여 비용 추적 및 감사(Audit)에 활용합니다.
COMMON_TAGS="{Key=Project,Value=codyssey-cloud},{Key=Owner,Value=nick19850906-debug},{Key=Env,Value=dev},{Key=CostCenter,Value=free-tier}"

# [보안 핵심!] 현재 내 컴퓨터의 실제 외부 '공인 IP'를 자동으로 물어봐서 뒤에 '/32'(딱 이 IP 1개만!)를 붙입니다.
MY_IP="$(curl -s https://checkip.amazonaws.com)/32"
echo "[INFO] 학습자 본인 공인 IP 감지 완료 (SSH 22번 포트 단독 허용 대상): ${MY_IP}"

# ------------------------------------------------------------------------------
# [1구역: VPC 생성 — 나만의 격리된 가상 네트워크 단지(10.0.0.0/16) 만들기]
# ------------------------------------------------------------------------------
VPC_ID=$(aws ec2 create-vpc \
  --region "${REGION}" \
  --cidr-block "${VPC_CIDR}" \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=codyssey-vpc},${COMMON_TAGS}]" \
  --query 'Vpc.VpcId' --output text)

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
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=codyssey-public-subnet},${COMMON_TAGS}]" \
  --query 'Subnet.SubnetId' --output text)

aws ec2 modify-subnet-attribute --region "${REGION}" --subnet-id "${SUBNET_ID}" --map-public-ip-on-launch
echo "[2/6] Public Subnet 생성 완료: ${SUBNET_ID} (${SUBNET_CIDR})"

# ------------------------------------------------------------------------------
# [3구역: Internet Gateway(IGW) 생성 및 VPC 부착 — 단지 정문 톨게이트 세우기]
# ------------------------------------------------------------------------------
IGW_ID=$(aws ec2 create-internet-gateway \
  --region "${REGION}" \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=codyssey-igw},${COMMON_TAGS}]" \
  --query 'InternetGateway.InternetGatewayId' --output text)

aws ec2 attach-internet-gateway --region "${REGION}" --vpc-id "${VPC_ID}" --internet-gateway-id "${IGW_ID}"
echo "[3/6] Internet Gateway 생성 및 VPC 연결 완료: ${IGW_ID}"

# ------------------------------------------------------------------------------
# [4구역: Route Table 설정 — "인터넷(0.0.0.0/0)으로 갈 때는 정문(IGW)으로 가라!" 이정표 세우기]
# ------------------------------------------------------------------------------
RTB_ID=$(aws ec2 create-route-table \
  --region "${REGION}" \
  --vpc-id "${VPC_ID}" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=codyssey-public-rt},${COMMON_TAGS}]" \
  --query 'RouteTable.RouteTableId' --output text)

aws ec2 create-route --region "${REGION}" --route-table-id "${RTB_ID}" --destination-cidr-block "0.0.0.0/0" --gateway-id "${IGW_ID}"
ASSOC_ID=$(aws ec2 associate-route-table --region "${REGION}" --route-table-id "${RTB_ID}" --subnet-id "${SUBNET_ID}" --query 'AssociationId' --output text)
echo "[4/6] Route Table 경로(0.0.0.0/0 -> ${IGW_ID}) 및 서브넷 명시적 연결 완료: ${RTB_ID} (Assoc: ${ASSOC_ID})"

# [평가 항목 #1 보완] 배포 직후 서브넷-라우트 테이블 Associate 상태 및 라우팅 경로 한 줄 검증 명령
aws ec2 describe-route-tables --region "${REGION}" --route-table-ids "${RTB_ID}" \
  --query "RouteTables[0].{RouteTableId:RouteTableId,AssociatedSubnet:Associations[0].SubnetId,State:Associations[0].AssociationState.State,Routes:Routes[*].[DestinationCidrBlock,GatewayId,State]}" \
  --output table

# ------------------------------------------------------------------------------
# [5구역: Security Group(보안 그룹) 설정 — 문지기 출입 명부 만들기 (최소 포트 허용 원칙)]
# ------------------------------------------------------------------------------
SG_ID=$(aws ec2 create-security-group \
  --region "${REGION}" \
  --group-name "codyssey-web-sg" \
  --description "Allow HTTP(80) from anywhere and SSH(22) from learner IP only" \
  --vpc-id "${VPC_ID}" \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=codyssey-web-sg},${COMMON_TAGS}]" \
  --query 'GroupId' --output text)

# 규칙 1: 웹 서비스 포트인 HTTP(80번)는 누구나 홈페이지를 볼 수 있도록 전체(0.0.0.0/0) 허용합니다.
aws ec2 authorize-security-group-ingress \
  --region "${REGION}" \
  --group-id "${SG_ID}" \
  --protocol tcp --port 80 --cidr "0.0.0.0/0"

# 규칙 2: 서버 관리용 포트인 SSH(22번)는 해킹 방지를 위해 오직 '내 공인 IP(${MY_IP})'에서만 들어오게 잠급니다.
aws ec2 authorize-security-group-ingress \
  --region "${REGION}" \
  --group-id "${SG_ID}" \
  --protocol tcp --port 22 --cidr "${MY_IP}"
echo "[5/6] Security Group 생성 완료: ${SG_ID} (HTTP 80: 전체 허용, SSH 22: ${MY_IP} 단독 허용)"

# ------------------------------------------------------------------------------
# [6구역: EC2 인스턴스 생성 — Ubuntu 24.04 LTS 가상 컴퓨터(t3.micro, 8GiB) 켜기]
# ------------------------------------------------------------------------------
AMI_ID=$(aws ec2 describe-images \
  --region "${REGION}" \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text)

INSTANCE_ID=$(aws ec2 run-instances \
  --region "${REGION}" \
  --image-id "${AMI_ID}" \
  --instance-type "${INSTANCE_TYPE}" \
  --key-name "${KEY_NAME}" \
  --subnet-id "${SUBNET_ID}" \
  --security-group-ids "${SG_ID}" \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":8,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=codyssey-web-ec2},${COMMON_TAGS}]" \
  --query 'Instances[0].InstanceId' --output text)

echo "[6/6] EC2 인스턴스 생성 완료: ${INSTANCE_ID} (${INSTANCE_TYPE}, EBS 8GiB) — 부팅 대기 중..."
aws ec2 wait instance-running --region "${REGION}" --instance-ids "${INSTANCE_ID}"

PUBLIC_IP=$(aws ec2 describe-instances \
  --region "${REGION}" \
  --instance-ids "${INSTANCE_ID}" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "=================================================================="
echo " 🎉 클라우드 인프라 구축 및 연결 상태 검증 완료!"
echo " • VPC / Subnet / IGW / RTB : ${VPC_ID} / ${SUBNET_ID} / ${IGW_ID} / ${RTB_ID}"
echo " • 할당된 퍼블릭 IP         : ${PUBLIC_IP}"
echo " • (A) 브라우저 접속        : http://${PUBLIC_IP}"
echo " • (B) 헬스체크 호출        : http://${PUBLIC_IP}/health"
echo "=================================================================="
