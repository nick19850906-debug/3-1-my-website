#!/usr/bin/env bash
# ==============================================================================
# [파일 이름] scripts/cleanup-aws.sh (기능 요구사항 6: 과금 방지를 위한 리소스 안전 정리)
# [파일 역할] 실습이 끝난 뒤 과금 위험이 남지 않도록 모든 AWS 리소스를 '생성했던 반대 순서(의존성 역순)'로
#            안전하게 종료(Terminate) 및 삭제(Delete)하는 스크립트입니다.
# [실생활 비유] 아파트 모델하우스 철거 시 바깥 울타리(VPC)부터 부수려 하면 안에 건물(EC2)이 남아 있어
#             철거가 거부(DependencyViolation)되므로, 가장 안쪽의 ① 건물(EC2) -> ② 창고/주소(EBS/EIP) ->
#             ③ 정문(IGW) -> ④ 구역/이정표/초소(Subnet/RT/SG) -> ⑤ 울타리(VPC) 순서로 깔끔하게 철거합니다!
# ==============================================================================
set -euo pipefail

REGION="ap-northeast-2"  # 정리할 대상 리전: 서울 리전(ap-northeast-2)

echo "=================================================================="
echo " 🧹 [Cleanup] AWS 서울 리전 (${REGION}) 리소스 안전 철거 시작"
echo "=================================================================="

# ------------------------------------------------------------------------------
# [1단계: EC2 인스턴스 종료 (Terminated 확인)]
# - 주의! '중지(Stop)'만 하면 하드디스크(EBS) 요금이 계속 나가므로 반드시 '종료(Terminate)'해야 합니다.
# ------------------------------------------------------------------------------
INSTANCE_IDS=$(aws ec2 describe-instances \
  --region "${REGION}" \
  --filters "Name=tag:Name,Values=codyssey-web-ec2" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text)

if [[ -n "${INSTANCE_IDS}" ]]; then
  echo "[1/7] EC2 인스턴스 종료(Terminate) 실행 중: ${INSTANCE_IDS}"
  aws ec2 terminate-instances --region "${REGION}" --instance-ids ${INSTANCE_IDS}
  # 인스턴스가 완전히 'terminated' 상태가 될 때까지 기다립니다 (그래야 서브넷/보안그룹이 지워집니다!).
  aws ec2 wait instance-terminated --region "${REGION}" --instance-ids ${INSTANCE_IDS}
  echo "      -> EC2 상태 'terminated' (완전 종료) 확인 완료!"
else
  echo "[1/7] 실행 중이거나 중지된 EC2 인스턴스가 없습니다 (이미 종료 완료)."
fi

# ------------------------------------------------------------------------------
# [2단계: Elastic IP(탄력적 고정 IP) 해제 (Release 확인)]
# - 왜 지우나요? Elastic IP는 안 쓰고 가지고만 있어도 시간당 요금이 부과되는 대표 과금 요인입니다!
# ------------------------------------------------------------------------------
ALLOC_IDS=$(aws ec2 describe-addresses \
  --region "${REGION}" \
  --query 'Addresses[].AllocationId' --output text)

for ALLOC_ID in ${ALLOC_IDS}; do
  echo "[2/7] Elastic IP 할당 해제(Release): ${ALLOC_ID}"
  aws ec2 release-address --region "${REGION}" --allocation-id "${ALLOC_ID}"
done
echo "[2/7] Elastic IP 잔여 0개 확인 완료."

# ------------------------------------------------------------------------------
# [3단계: 미사용(available) EBS 볼륨(하드디스크) 삭제 확인]
# - 왜 지우나요? EC2와 연결이 끊어진 채 남아있는('available' 상태) EBS 볼륨은 GB/월 요금이 나갑니다!
# ------------------------------------------------------------------------------
VOL_IDS=$(aws ec2 describe-volumes \
  --region "${REGION}" \
  --filters "Name=status,Values=available" \
  --query 'Volumes[].VolumeId' --output text)

for VOL_ID in ${VOL_IDS}; do
  echo "[3/7] 미사용 EBS 볼륨 삭제: ${VOL_ID}"
  aws ec2 delete-volume --region "${REGION}" --volume-id "${VOL_ID}"
done
echo "[3/7] 미사용 EBS 볼륨 잔여 0개 확인 완료."

# 우리가 만들었던 VPC('codyssey-vpc')의 고유 ID를 조회합니다.
VPC_ID=$(aws ec2 describe-vpcs \
  --region "${REGION}" \
  --filters "Name=tag:Name,Values=codyssey-vpc" \
  --query 'Vpcs[0].VpcId' --output text)

if [[ "${VPC_ID}" != "None" && -n "${VPC_ID}" ]]; then
  # ----------------------------------------------------------------------------
  # [4단계: Internet Gateway(정문) VPC에서 분리(Detach) 후 삭제(Delete)]
  # - VPC에 붙어있는 상태에서는 삭제가 안 되므로 반드시 '분리(detach)'를 먼저 해야 합니다!
  # ----------------------------------------------------------------------------
  IGW_ID=$(aws ec2 describe-internet-gateways \
    --region "${REGION}" \
    --filters "Name=attachment.vpc-id,Values=${VPC_ID}" \
    --query 'InternetGateways[0].InternetGatewayId' --output text)
  if [[ "${IGW_ID}" != "None" && -n "${IGW_ID}" ]]; then
    echo "[4/7] Internet Gateway 분리(Detach) 및 삭제: ${IGW_ID}"
    aws ec2 detach-internet-gateway --region "${REGION}" --internet-gateway-id "${IGW_ID}" --vpc-id "${VPC_ID}"
    aws ec2 delete-internet-gateway --region "${REGION}" --internet-gateway-id "${IGW_ID}"
  fi

  # ----------------------------------------------------------------------------
  # [5단계: Public Subnet(구역) 삭제]
  # ----------------------------------------------------------------------------
  SUBNET_IDS=$(aws ec2 describe-subnets \
    --region "${REGION}" \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'Subnets[].SubnetId' --output text)
  for SUB_ID in ${SUBNET_IDS}; do
    echo "[5/7] Subnet 삭제: ${SUB_ID}"
    aws ec2 delete-subnet --region "${REGION}" --subnet-id "${SUB_ID}"
  done

  # ----------------------------------------------------------------------------
  # [6단계: 커스텀 Route Table(이정표) 및 Security Group(보안 그룹) 삭제]
  # ----------------------------------------------------------------------------
  RTB_IDS=$(aws ec2 describe-route-tables \
    --region "${REGION}" \
    --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=codyssey-public-rt" \
    --query 'RouteTables[].RouteTableId' --output text)
  for RTB_ID in ${RTB_IDS}; do
    echo "[6/7] Route Table 삭제: ${RTB_ID}"
    aws ec2 delete-route-table --region "${REGION}" --route-table-id "${RTB_ID}"
  done

  SG_IDS=$(aws ec2 describe-security-groups \
    --region "${REGION}" \
    --filters "Name=vpc-id,Values=${VPC_ID}" "Name=group-name,Values=codyssey-web-sg" \
    --query 'SecurityGroups[].GroupId' --output text)
  for SG_ID in ${SG_IDS}; do
    echo "[6/7] Security Group 삭제: ${SG_ID}"
    aws ec2 delete-security-group --region "${REGION}" --group-id "${SG_ID}"
  done

  # ----------------------------------------------------------------------------
  # [7단계: 마지막으로 빈 껍데기가 된 VPC(울타리) 최종 삭제]
  # ----------------------------------------------------------------------------
  echo "[7/7] VPC 최종 삭제: ${VPC_ID}"
  aws ec2 delete-vpc --region "${REGION}" --vpc-id "${VPC_ID}"
fi

echo "=================================================================="
echo " ✅ 모든 AWS 실습 리소스 안전 삭제 완료! (과금 위험 $0.00)"
echo "=================================================================="
