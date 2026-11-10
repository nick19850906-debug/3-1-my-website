#!/usr/bin/env bash
# ==============================================================================
# [요구사항 1~3] AWS 서울 리전(ap-northeast-2) VPC · Subnet · IGW · SG · EC2 프로비저닝
# 실행 전제: AdministratorAccess가 아닌 최소권한 IAM 사용자(codyssey-cloud-user) 자격증명
# ==============================================================================
set -euo pipefail

REGION="ap-northeast-2"
AZ="ap-northeast-2a"
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR="10.0.1.0/24"
INSTANCE_TYPE="t3.micro"
KEY_NAME="codyssey-web-key"

# 현재 학습자 공인 IP 자동 조회 (/32 단일 호스트 제한)
MY_IP="$(curl -s https://checkip.amazonaws.com)/32"
echo "[INFO] Detected Learner Public IP for SSH(22): ${MY_IP}"

# 1. VPC 생성 (10.0.0.0/16)
VPC_ID=$(aws ec2 create-vpc \
  --region "${REGION}" \
  --cidr-block "${VPC_CIDR}" \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=codyssey-vpc}]' \
  --query 'Vpc.VpcId' --output text)
aws ec2 modify-vpc-attribute --region "${REGION}" --vpc-id "${VPC_ID}" --enable-dns-hostnames "{\"Value\":true}"
echo "[1/6] Created VPC: ${VPC_ID} (${VPC_CIDR})"

# 2. Public Subnet 생성 (10.0.1.0/24) 및 퍼블릭 IP 자동 할당 활성화
SUBNET_ID=$(aws ec2 create-subnet \
  --region "${REGION}" \
  --vpc-id "${VPC_ID}" \
  --cidr-block "${SUBNET_CIDR}" \
  --availability-zone "${AZ}" \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=codyssey-public-subnet}]' \
  --query 'Subnet.SubnetId' --output text)
aws ec2 modify-subnet-attribute --region "${REGION}" --subnet-id "${SUBNET_ID}" --map-public-ip-on-launch
echo "[2/6] Created Public Subnet: ${SUBNET_ID} (${SUBNET_CIDR})"

# 3. Internet Gateway 생성 및 VPC 연결
IGW_ID=$(aws ec2 create-internet-gateway \
  --region "${REGION}" \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=codyssey-igw}]' \
  --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --region "${REGION}" --vpc-id "${VPC_ID}" --internet-gateway-id "${IGW_ID}"
echo "[3/6] Created & Attached Internet Gateway: ${IGW_ID}"

# 4. Public Route Table 생성, 0.0.0.0/0 -> IGW 경로 추가, Public Subnet 연결
RTB_ID=$(aws ec2 create-route-table \
  --region "${REGION}" \
  --vpc-id "${VPC_ID}" \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=codyssey-public-rt}]' \
  --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --region "${REGION}" --route-table-id "${RTB_ID}" --destination-cidr-block "0.0.0.0/0" --gateway-id "${IGW_ID}"
aws ec2 associate-route-table --region "${REGION}" --route-table-id "${RTB_ID}" --subnet-id "${SUBNET_ID}"
echo "[4/6] Configured Route Table: ${RTB_ID} (0.0.0.0/0 -> ${IGW_ID})"

# 5. Security Group 생성 (최소 포트 허용 원칙: HTTP 80은 0.0.0.0/0, SSH 22는 내 IP만 허용)
SG_ID=$(aws ec2 create-security-group \
  --region "${REGION}" \
  --group-name "codyssey-web-sg" \
  --description "Allow HTTP(80) from anywhere and SSH(22) from learner IP only" \
  --vpc-id "${VPC_ID}" \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=codyssey-web-sg}]' \
  --query 'GroupId' --output text)

# HTTP (80) -> 0.0.0.0/0
aws ec2 authorize-security-group-ingress \
  --region "${REGION}" \
  --group-id "${SG_ID}" \
  --protocol tcp --port 80 --cidr "0.0.0.0/0"

# SSH (22) -> 내 IP(${MY_IP})로만 제한 (0.0.0.0/0 전체 포트 허용 금지 준수)
aws ec2 authorize-security-group-ingress \
  --region "${REGION}" \
  --group-id "${SG_ID}" \
  --protocol tcp --port 22 --cidr "${MY_IP}"
echo "[5/6] Created Security Group: ${SG_ID} (80: 0.0.0.0/0, 22: ${MY_IP})"

# 6. Ubuntu 24.04 LTS AMI 조회 및 프리티어 EC2(t3.micro, EBS 8GiB) 생성
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
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=codyssey-web-ec2}]' \
  --query 'Instances[0].InstanceId' --output text)

echo "[6/6] Launched EC2 Instance: ${INSTANCE_ID} (${INSTANCE_TYPE}, EBS 8GiB)"
aws ec2 wait instance-running --region "${REGION}" --instance-ids "${INSTANCE_ID}"

PUBLIC_IP=$(aws ec2 describe-instances \
  --region "${REGION}" \
  --instance-ids "${INSTANCE_ID}" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "=================================================================="
echo " Provisioning Complete!"
echo " Public IP : ${PUBLIC_IP}"
echo " URL (A)   : http://${PUBLIC_IP}"
echo " Health (B): http://${PUBLIC_IP}/health"
echo "=================================================================="
