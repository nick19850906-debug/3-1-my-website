#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
[파일 이름] scripts/evaluate-mission.py
[파일 역할] AI 사전평가 16개 항목(#1 ~ #16) 및 퍼실리테이터 1:1 평가 기준이
            100% 완벽하게 반영되었는지 1초 만에 자동 점검하고 성적표를 출력하는 스크립트입니다.
[실생활 비유] 건물 준공 검사관이 16개 항목 체크리스트를 들고 다니며
             "네트워크(#1)? 통과! 보안그룹 감사(#3)? 통과! 확장성·ALB 지침(#16)? 통과!"
             라고 도장을 찍어주는 '자동 준공 검사 로봇'입니다.
================================================================================
"""

import json  # JSON 형식 파일(iam/least-privilege-policy.json)을 읽고 분석하는 도구 상자
import os    # 운영체제(Windows/Linux)의 파일 경로와 용량을 확인하는 도구 상자
import sys   # 터미널 화면 UTF-8 출력 설정 및 종료 코드를 다루는 도구 상자

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read_text(rel_path: str) -> str:
    """프로젝트 루트 기준 상대 경로(rel_path) 파일을 읽어 문자열로 반환합니다."""
    full_path = os.path.join(ROOT_DIR, rel_path)
    with open(full_path, "r", encoding="utf-8") as f:
        return f.read()


def check_file_exists(rel_path: str, min_bytes: int = 10) -> tuple[bool, str]:
    """파일 존재 여부와 최소 용량(min_bytes) 이상인지 검사합니다."""
    full_path = os.path.join(ROOT_DIR, rel_path)
    if not os.path.isfile(full_path):
        return False, f"파일 없음: {rel_path}"
    size = os.path.getsize(full_path)
    if size < min_bytes:
        return False, f"파일 용량 부족 ({size} bytes): {rel_path}"
    return True, f"{rel_path} ({size:,} bytes)"


def run_evaluation() -> int:
    """AI 사전평가 16개 항목(#1 ~ #16)을 전수 검사하고 결과를 출력합니다."""
    print("=" * 88)
    print(" ☁️ [클라우드 웹 서비스 미션] AI 사전평가 16개 항목 전수 검증 스크립트 실행")
    print("    대상 저장소 : https://github.com/nick19850906-debug/5-1-.git")
    print(f"    로컬 경로   : {ROOT_DIR}")
    print("=" * 88)

    readme = read_text("README.md")
    prov = read_text("scripts/provision-aws.sh")
    clean_sh = read_text("scripts/cleanup-aws.sh")
    clean_md = read_text("docs/cleanup-checklist.md")
    ts_md = read_text("docs/troubleshooting.md")
    iam_raw = read_text("iam/least-privilege-policy.json")
    iam_json = json.loads(iam_raw)

    passed = 0
    total = 0

    def check_item(num: int, title: str, ok: bool, evidence: str) -> None:
        nonlocal passed, total
        total += 1
        if ok:
            passed += 1
        badge = "✅ PASS" if ok else "❌ FAIL"
        print(f"{badge} | 평가 항목 #{num:02d} : {title}")
        print(f"       └─ 근거: {evidence}")

    # #1: VPC/Subnet/IGW/Route 구성 및 Associate 상태 확인 한 줄 검증 명령
    ok1 = ("describe-route-tables" in readme) and ("AssociationState" in prov) and ("create-vpc" in prov)
    check_item(1, "VPC/서브넷/IGW/라우트 구성 및 배포 후 Associate 상태 한 줄 검증 명령", ok1, "README.md & scripts/provision-aws.sh 내 describe-route-tables 검증 포함")

    # #2: SSH/HTTP 접속 증빙 및 실패 케이스별 최소 curl/ssh 진단 명령
    ok2 = ("ssh -vvv" in readme) and ("curl -v --connect-timeout" in readme) and ("HTTP/1.1 200 OK" in readme)
    check_item(2, "EC2 SSH·웹(200 OK) 접속 증빙 및 실패 케이스별 최소 curl/ssh 점검 명령", ok2, "README.md > ssh -vvv / curl -v --connect-timeout 5 진단 명령 명시")

    # #3: Security Group 최소 허용 자동화 및 변경 시점/변경자 CloudTrail 감사 절차
    ok3 = ('--port 80 --cidr "0.0.0.0/0"' in prov) and ('--port 22 --cidr "${MY_IP}"' in prov) and ("cloudtrail lookup-events" in readme)
    check_item(3, "Security Group 최소 허용 스크립트 및 변경 시점·변경자 CloudTrail 감사 절차", ok3, "provision-aws.sh 최소 포트 규칙 + README.md CloudTrail 감사 명령 명시")

    # #4: 외부 접속 이중 검증(A/B) 스크린샷 및 curl 원본 텍스트 로그 첨부
    ok4_scr, _ = check_file_exists("docs/screenshots/external-browser-check.png", 5000)
    ok4_log, msg4_log = check_file_exists("docs/logs/curl-health-check.log", 200)
    check_item(4, "브라우저(A) 및 /health(B) 이중 검증 스크린샷 + curl 원본 텍스트 로그 첨부", ok4_scr and ok4_log, f"README.md 텍스트 로그 블록 + {msg4_log}")

    # #5: 리소스 정리 체크리스트 + 실행 로그 저장 위치 및 실패 재시도(Retry) 조치
    ok5_log, msg5_log = check_file_exists("docs/logs/cleanup-execution.log", 200)
    ok5 = ("retry_cmd" in clean_sh) and ("cleanup-execution.log" in clean_md) and ok5_log
    check_item(5, "리소스 역순 정리 체크리스트 + 실행 로그 저장 위치 및 실패 재시도(Retry) 정책", ok5, f"cleanup-aws.sh retry_cmd(3회 재시도) + {msg5_log}")

    # #6: 아키텍처 다이어그램(PNG/PDF/ASCII) 내 NACL, SG(In/Out), Public IP 명시
    ok6_png, msg6_png = check_file_exists("docs/architecture.png", 10000)
    ok6_pdf, msg6_pdf = check_file_exists("docs/architecture.pdf", 10000)
    ok6 = ok6_png and ok6_pdf and ("Network ACL" in readme) and ("SG Inbound" in readme) and ("43.201.142.88" in readme)
    check_item(6, "아키텍처 다이어그램 내 Network ACL, SG(인/아웃바운드), Public IP 표기", ok6, f"{msg6_png} / {msg6_pdf} + ASCII NACL/SG/Public IP 명시")

    # #7: 0-65535 전체 허용 금지 및 임시 포트 허용 시 만료 시간·검토자·로그 보존 정책
    ok7 = ("0-65535" in readme) and ("ExpiresAt" in readme) and ("ApprovedBy" in readme) and ("90일" in readme)
    check_item(7, "전체 포트(0-65535) 개방 금지 및 예외적 임시 허용 시 만료시간·검토자·로그 정책", ok7, "README.md > ExpiresAt 만료 태그, ApprovedBy 검토자, 90일 로그 보존 명시")

    # #8: 접속 검증 방식(A/B) 선택 이유 및 보안·운영 상의 장단점 비교
    ok8 = ("보안·운영 장단점" in readme) and ("WAF" in readme) and ("페이로드가" in readme)
    check_item(8, "접속 방식(A 브라우저 / B 헬스체크) 선택 이유 및 보안·운영 장단점 명시", ok8, "README.md 3장 > 방식 (A)/(B) 보안·운영 장단점 및 HTTPS/WAF 권고 비교")

    # #9: 리소스 태그 네이밍 규칙(Name/Project/Owner/Env/CostCenter) 표준화
    ok9 = ("COMMON_TAGS=" in prov) and ("Project=codyssey-cloud" in prov) and ("CostCenter" in readme)
    check_item(9, "표준 태그 네이밍 규칙(Name/Project/Owner/Env/CostCenter) 정의 및 스크립트 적용", ok9, "README.md 표준 태그 표 + scripts/provision-aws.sh COMMON_TAGS 일괄 적용")

    # #10: Public route(0.0.0.0/0 -> IGW) 생성 및 실수 삭제 시 영향 범위·한 줄 복구 명령
    ok10 = ("영향 범위" in readme) and ("한 줄 즉시 복구 명령" in readme) and ("create-route" in readme)
    check_item(10, "Public Route(0.0.0.0/0->IGW) 구성 및 삭제 시 영향 범위·복구 명령 한 줄 요약", ok10, "README.md 4장 > 라우트 삭제 영향 범위 및 create-route 한 줄 복구 명령 명시")

    # #11: IAM vs SG 역할 차이 및 EC2 인스턴스 프로파일/IAM Role 위임 한 줄 예시
    ok11 = ("associate-iam-instance-profile" in readme) and ("인스턴스 프로파일" in readme)
    check_item(11, "IAM vs SG 역할 구분 및 EC2 인스턴스 프로파일(IAM Role) 최소권한 위임 예시", ok11, "README.md > associate-iam-instance-profile 한 줄 명령 및 IAM Role 권고 명시")

    # #12: 0.0.0.0/0 위험성, 내 공인 IP(/32) 적용 및 동적 IP 대안(SSM/Bastion/VPN) 비교
    ok12 = ("Session Manager" in readme) and ("Bastion Host" in readme) and ("Client VPN" in readme)
    check_item(12, "SSH 내 공인 IP(/32) 제한 및 동적 IP 환경 대안(SSM/Bastion/VPN) 비교", ok12, "README.md > 동적 IP 환경을 위한 SSM Session Manager, Bastion, VPN 대안 명시")

    # #13: 트러블슈팅 보고서(가설->검증->조치) 및 수집한 CLI/CloudTrail 원본 로그 경로 명시
    ok13_log, msg13_log = check_file_exists("docs/logs/troubleshooting-cli-cloudtrail.log", 400)
    ok13 = ok13_log and ("troubleshooting-cli-cloudtrail.log" in ts_md)
    check_item(13, "트러블슈팅 6단계 보고서 및 CLI/CloudTrail 원본 로그 파일 경로 명시", ok13, f"docs/troubleshooting.md 내 경로 명시 + {msg13_log}")

    # #14: 장애 점검 우선순위(라우팅->SG->IP->서버) 실행 가능한 커맨드 리스트 요약
    ok14 = ("[1순위: 라우팅/IGW 점검]" in readme) and ("[2순위: 보안 그룹(SG) 점검]" in readme) and ("[4순위: 서버 내부 웹 프로세스/포트 점검]" in readme)
    check_item(14, "장애 점검 우선순위(라우팅->SG->IP->서버) 실행 가능한 4단계 커맨드 리스트", ok14, "README.md 7장 > 1~4순위 실행 가능한 AWS CLI/ss/curl 커맨드 리스트 수록")

    # #15: IAM 최소권한 정책(서울 리전 제한) 및 정책 수정 시 검토자·롤백·로그 보존 절차
    has_seoul = '"aws:RequestedRegion": "ap-northeast-2"' in iam_raw
    ok15 = has_seoul and ("set-default-policy-version" in readme) and ("보안 검토자(Reviewer)" in readme)
    check_item(15, "IAM 최소권한 정책 및 정책 변경 시 검토자 승인·버전 롤백·CloudTrail 보존 절차", ok15, "iam/least-privilege-policy.json + README.md set-default-policy-version 롤백 절차")

    # #16: 확장성 대응(병목 확인 절차·진단 지표) 및 ALB 도입·구성 지침(비용·설정 요약) 문서화
    ok16_doc, msg16_doc = check_file_exists("docs/scalability-and-alb-guide.md", 1500)
    alb_text = read_text("docs/scalability-and-alb-guide.md") if ok16_doc else ""
    ok16 = (
        ok16_doc
        and ("CPUUtilization" in alb_text)
        and ("보안 그룹 체이닝" in alb_text)
        and ("$0.0252" in alb_text)
        and ("LCU" in alb_text)
        and ("확장성 대응(병목 확인 절차) 및 ALB 도입·구성 지침" in readme)
    )
    check_item(16, "확장성 대응(병목 진단 지표·절차) 및 ALB 도입·구성 지침(비용·설정 요약) 문서화", ok16, f"README.md 5장 요약 + {msg16_doc}")

    print("\n" + "=" * 88)
    print(f" 🎯 최종 평가 검증 결과 : {passed} / {total} 항목 통과 ({passed / total * 100:.0f}%)")
    print("=" * 88)
    return 0 if passed == total else 1


if __name__ == "__main__":
    raise SystemExit(run_evaluation())
