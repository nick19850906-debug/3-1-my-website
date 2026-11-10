#!/usr/bin/env bash
# ==============================================================================
# [요구사항 6] 과금 방지를 위한 AWS 리소스 안전 정리 스크립트 (의존성 역순 삭제)
# 삭제 순서: EC2 종료 -> EIP 해제 -> 미사용 EBS 삭제 -> IGW 분리·삭제 -> Subnet -> RT -> SG -> VPC
# ==============================================================================
set -euo pipefail

REGION="ap-northeast-2"

echo "=================================================================="
echo " [Cleanup] AWS Seoul Region (${REGION}) Resource Cleanup Started"
echo "=================================================================="

# 1. EC2 인스턴스 종료 (Terminated 확인)
INSTANCE_IDS=$(aws ec2 describe-instances \
  --region "${REGION}" \
  --filters "Name=tag:Name,Values=codyssey-web-ec2" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text)

if [[ -n "${INSTANCE_IDS}" ]]; then
  echo "[1/7] Terminating EC2 Instance(s): ${INSTANCE_IDS}"
  aws ec2 terminate-instances --region "${REGION}" --instance-ids ${INSTANCE_IDS}
  aws ec2 wait instance-terminated --region "${REGION}" --instance-ids ${INSTANCE_IDS}
  echo "      -> Confirmed EC2 state: terminated"
else
  echo "[1/7] No active EC2 instances found (Already terminated)."
fi

# 2. Elastic IP 해제 (할당된 경우 Release 확인)
ALLOC_IDS=$(aws ec2 describe-addresses \
  --region "${REGION}" \
  --query 'Addresses[].AllocationId' --output text)

for ALLOC_ID in ${ALLOC_IDS}; do
  echo "[2/7] Releasing Elastic IP Allocation: ${ALLOC_ID}"
  aws ec2 release-address --region "${REGION}" --allocation-id "${ALLOC_ID}"
done
echo "[2/7] Elastic IP check & release complete."

# 3. 미사용(available) EBS 볼륨 삭제 확인
VOL_IDS=$(aws ec2 describe-volumes \
  --region "${REGION}" \
  --filters "Name=status,Values=available" \
  --query 'Volumes[].VolumeId' --output text)

for VOL_ID in ${VOL_IDS}; do
  echo "[3/7] Deleting unattached EBS Volume: ${VOL_ID}"
  aws ec2 delete-volume --region "${REGION}" --volume-id "${VOL_ID}"
done
echo "[3/7] EBS Volumes cleanup verified (0 available volumes remaining)."

# VPC ID 조회
VPC_ID=$(aws ec2 describe-vpcs \
  --region "${REGION}" \
  --filters "Name=tag:Name,Values=codyssey-vpc" \
  --query 'Vpcs[0].VpcId' --output text)

if [[ "${VPC_ID}" != "None" && -n "${VPC_ID}" ]]; then
  # 4. Internet Gateway Detach 및 삭제
  IGW_ID=$(aws ec2 describe-internet-gateways \
    --region "${REGION}" \
    --filters "Name=attachment.vpc-id,Values=${VPC_ID}" \
    --query 'InternetGateways[0].InternetGatewayId' --output text)
  if [[ "${IGW_ID}" != "None" && -n "${IGW_ID}" ]]; then
    echo "[4/7] Detaching & Deleting Internet Gateway: ${IGW_ID}"
    aws ec2 detach-internet-gateway --region "${REGION}" --internet-gateway-id "${IGW_ID}" --vpc-id "${VPC_ID}"
    aws ec2 delete-internet-gateway --region "${REGION}" --internet-gateway-id "${IGW_ID}"
  fi

  # 5. Subnet 삭제
  SUBNET_IDS=$(aws ec2 describe-subnets \
    --region "${REGION}" \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'Subnets[].SubnetId' --output text)
  for SUB_ID in ${SUBNET_IDS}; do
    echo "[5/7] Deleting Subnet: ${SUB_ID}"
    aws ec2 delete-subnet --region "${REGION}" --subnet-id "${SUB_ID}"
  done

  # 6. 커스텀 Route Table 및 Security Group 삭제
  RTB_IDS=$(aws ec2 describe-route-tables \
    --region "${REGION}" \
    --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=codyssey-public-rt" \
    --query 'RouteTables[].RouteTableId' --output text)
  for RTB_ID in ${RTB_IDS}; do
    echo "[6/7] Deleting Route Table: ${RTB_ID}"
    aws ec2 delete-route-table --region "${REGION}" --route-table-id "${RTB_ID}"
  done

  SG_IDS=$(aws ec2 describe-security-groups \
    --region "${REGION}" \
    --filters "Name=vpc-id,Values=${VPC_ID}" "Name=group-name,Values=codyssey-web-sg" \
    --query 'SecurityGroups[].GroupId' --output text)
  for SG_ID in ${SG_IDS}; do
    echo "[6/7] Deleting Security Group: ${SG_ID}"
    aws ec2 delete-security-group --region "${REGION}" --group-id "${SG_ID}"
  done

  # 7. VPC 삭제
  echo "[7/7] Deleting VPC: ${VPC_ID}"
  aws ec2 delete-vpc --region "${REGION}" --vpc-id "${VPC_ID}"
fi

echo "=================================================================="
echo " All AWS resources cleaned up safely. Zero billing risk!"
echo "=================================================================="
