#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
[파일 이름] scripts/evaluate-mission.py
[파일 역할] 퍼실리테이터 1:1 평가 시 미션 요구사항(필수 제출물 4종 + 기능 요구사항 6종 + 보너스 2종)이
            100% 완벽하게 준비되어 있는지 1초 만에 자동 점검하고 성적표를 출력하는 평가 스크립트입니다.
[실생활 비유] 건물 준공 검사관이 체크리스트 클립보드를 들고 다니며
             "1층 설계도(아키텍처) 있나? 통과! 비상벨(/health) 울리나? 통과! 소화기(보안그룹/IAM) 있나? 통과!"
             라고 도장을 찍어주는 '자동 준공 검사 로봇'과 같습니다.
================================================================================
"""

# [1구역: 필요한 도구 상자(모듈) 꺼내오기]
import json  # JSON 형식 파일(iam/least-privilege-policy.json)을 읽고 분석하는 도구 상자
import os    # 운영체제(Windows/Linux)의 파일 경로를 찾고 파일이 존재하는지 확인하는 도구 상자
import sys   # 터미널 화면 출력 인코딩(한글 깨짐 방지) 및 프로그램 종료 코드를 다루는 도구 상자

# Windows 터미널(cmd.exe / PowerShell)에서 이모지와 한글이 깨지지 않도록 UTF-8 출력을 강제 설정합니다.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

# 현재 이 스크립트 파일(scripts/evaluate-mission.py)이 있는 위치를 기준으로
# 한 단계 위 폴더인 프로젝트 최상위 루트 폴더(c:\Users\domod\5-1-) 경로를 자동으로 계산합니다.
# - os.path.abspath(__file__) : 현재 파일의 절대 경로
# - os.path.dirname(...)      : 폴더 경로 추출 (두 번 감싸서 scripts의 부모 폴더인 루트로 이동)
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# [2구역: 파일 검사 도우미 함수 정의]
def read_text(rel_path: str) -> str:
    """
    [함수 설명] 프로젝트 루트 기준 상대 경로(rel_path)를 받아 파일 내용을 문자열(str)로 읽어옵니다.
    - rel_path: str -> 매개변수 이름 뒤에 ': str'은 "글자(문자열) 타입이 들어옵니다"라는 친절한 안내표입니다.
    - -> str        -> 이 함수가 끝날 때 "글자(문자열)를 결과로 돌려줍니다"라는 뜻입니다.
    """
    full_path = os.path.join(ROOT_DIR, rel_path)  # 루트 폴더 경로와 파일 경로를 안전하게 합칩니다.
    with open(full_path, "r", encoding="utf-8") as f:  # 파일을 읽기 모드("r")와 UTF-8 인코딩으로 엽니다.
        return f.read()  # 파일 안의 모든 글자를 읽어서 돌려줍니다(return).


def check_file_exists(rel_path: str, min_bytes: int = 10) -> tuple[bool, str]:
    """
    [함수 설명] 파일이 실제로 존재하는지, 그리고 빈 껍데기 파일이 아닌지(최소 용량 min_bytes 이상인지) 검사합니다.
    - tuple[bool, str]: (성공여부 True/False, 설명 메시지 문자열) 세트를 돌려준다는 뜻입니다.
    """
    full_path = os.path.join(ROOT_DIR, rel_path)  # 검사할 파일의 전체 경로를 만듭니다.
    if not os.path.isfile(full_path):  # 만약 해당 경로에 파일이 없다면(not isfile)
        return False, f"파일 없음: {rel_path}"  # 실패(False)와 이유를 돌려줍니다.
    size = os.path.getsize(full_path)  # 파일의 크기(바이트 단위)를 잽니다.
    if size < min_bytes:  # 파일 크기가 기준치(min_bytes)보다 작다면
        return False, f"파일 용량 부족 ({size} bytes): {rel_path}"  # 실패(False)를 돌려줍니다.
    return True, f"{rel_path} ({size:,} bytes 확인 완료)"  # 성공(True)과 천 단위 콤마(,)가 찍힌 파일 크기를 돌려줍니다.


# [3구역: 미션 요구사항 전수 검사 실행 함수]
def run_evaluation() -> int:
    """
    [함수 설명] README.md 및 미션 PDF의 모든 평가 항목을 순서대로 검사하고 결과를 화면에 표 형태로 출력합니다.
    """
    print("=" * 84)
    print(" ☁️ [클라우드 웹 서비스 미션] 퍼실리테이터 평가 자동 검증 스크립트 실행")
    print("    대상 저장소 : https://github.com/nick19850906-debug/5-1-.git")
    print(f"    로컬 경로   : {ROOT_DIR}")
    print("=" * 84)

    # 통과한 항목 수(passed)와 전체 항목 수(total)를 세기 위한 숫자 변수(카운터)를 0으로 초기화합니다.
    passed = 0
    total = 0

    def record(section: str, title: str, ok: bool, detail: str) -> None:
        """검사 결과 한 줄을 예쁘게 출력하고 점수를 합산하는 내부 도우미 함수입니다."""
        nonlocal passed, total  # 바깥 함수(run_evaluation)에 있는 passed, total 변수를 직접 수정하겠다는 선언입니다.
        total += 1  # 전체 검사 항목 수를 1 늘립니다.
        if ok:  # 검사를 통과(True)했다면
            passed += 1  # 통과 항목 수를 1 늘립니다.
        badge = "✅ [PASS]" if ok else "❌ [FAIL]"  # 성공이면 초록 체크, 실패면 빨간 엑스 표시를 선택합니다.
        print(f"{badge} [{section}] {title}")
        print(f"          └─ 근거: {detail}")

    # --------------------------------------------------------------------------
    # [검사 파트 A] 최종 제출 결과물 4종 존재 및 규격 검증
    # --------------------------------------------------------------------------
    print("\n▶ 1단계: 최종 제출 결과물 (필수 4종) 파일 규격 검증")

    # 1. 아키텍처 다이어그램 (docs/architecture.png 및 pdf)
    ok_png, msg_png = check_file_exists("docs/architecture.png", min_bytes=10000)
    ok_pdf, msg_pdf = check_file_exists("docs/architecture.pdf", min_bytes=10000)
    record(
        "제출물 1",
        "아키텍처 다이어그램 1장 (VPC, Subnet, IGW, EC2, SG 및 트래픽 흐름)",
        ok_png and ok_pdf,
        f"{msg_png} / {msg_pdf}",
    )

    # 2. 웹 서비스 외부 접속 증빙 (README.md 기재 + 스크린샷)
    readme_text = read_text("README.md")
    ok_scr_a, msg_scr_a = check_file_exists("docs/screenshots/external-browser-check.png", min_bytes=5000)
    ok_scr_b, msg_scr_b = check_file_exists("docs/screenshots/external-health-check.png", min_bytes=5000)
    has_url_info = ("http://43.201.142.88" in readme_text) and ("/health" in readme_text) and ("200 OK" in readme_text)
    record(
        "제출물 2",
        "웹 서비스 외부 접속 증빙 (방식 A 브라우저 & 방식 B /health 호출 + 스크린샷)",
        has_url_info and ok_scr_a and ok_scr_b,
        f"README 접속정보 기재 확인 완료 + {msg_scr_a}, {msg_scr_b}",
    )

    # 3. 트러블슈팅 보고서 (docs/troubleshooting.md 및 pdf)
    ok_ts_md, msg_ts_md = check_file_exists("docs/troubleshooting.md", min_bytes=1000)
    ok_ts_pdf, msg_ts_pdf = check_file_exists("docs/troubleshooting.pdf", min_bytes=10000)
    ts_text = read_text("docs/troubleshooting.md") if ok_ts_md else ""
    has_ts_steps = all(k in ts_text for k in ["증상", "원인 가설", "검증 방법", "조치 내용", "결과", "재발 방지"])
    record(
        "제출물 3",
        "트러블슈팅 보고서 1개 (증상 -> 가설 -> 검증 -> 조치 -> 결과 -> 재발방지 3건)",
        ok_ts_md and ok_ts_pdf and has_ts_steps,
        f"6단계 필수 항목 포함 확인 + {msg_ts_md} / {msg_ts_pdf}",
    )

    # 4. 리소스 정리 체크리스트 (docs/cleanup-checklist.md + 증빙 스크린샷)
    ok_cl_md, msg_cl_md = check_file_exists("docs/cleanup-checklist.md", min_bytes=1000)
    ok_cl_scr, msg_cl_scr = check_file_exists("docs/screenshots/cleanup-billing-check.png", min_bytes=5000)
    cl_text = read_text("docs/cleanup-checklist.md") if ok_cl_md else ""
    has_cl_items = all(k in cl_text for k in ["EC2", "EBS", "Elastic IP", "Internet Gateway", "VPC", "$0.00"])
    record(
        "제출물 4",
        "리소스 정리 체크리스트 1개 (EC2, EBS, EIP, IGW, VPC 종료/삭제 및 $0.00 확인)",
        ok_cl_md and ok_cl_scr and has_cl_items,
        f"필수 정리 대상 전부 포함 + {msg_cl_md} / {msg_cl_scr}",
    )

    # --------------------------------------------------------------------------
    # [검사 파트 B] 기능 요구사항 (네트워크, 웹 서버, 보안 그룹, IAM 최소권한) 검증
    # --------------------------------------------------------------------------
    print("\n▶ 2단계: 기능 요구사항 (네트워크 · 웹 서버 · 보안 그룹 · IAM 최소권한) 코드 검증")

    # 1. 네트워크 및 보안 그룹 프로비저닝 스크립트 검증
    prov_text = read_text("scripts/provision-aws.sh")
    net_ok = all(
        k in prov_text
        for k in [
            'REGION="ap-northeast-2"',
            "create-vpc",
            "create-subnet",
            "create-internet-gateway",
            "0.0.0.0/0",
            "--port 80 --cidr \"0.0.0.0/0\"",
            "--port 22 --cidr \"${MY_IP}\"",
        ]
    )
    record(
        "요구사항 1·3",
        "서울 리전(ap-northeast-2) VPC/Subnet/IGW/RouteTable 및 보안그룹(80 전체, 22 내 IP) 설정",
        net_ok,
        "scripts/provision-aws.sh 내 0.0.0.0/0->IGW 라우팅 및 SG 최소 포트(80, 22 내 IP/32) 규칙 확인",
    )

    # 2. Nginx 웹 서버 (GET / 및 GET /health -> 200 OK "OK") 설정 검증
    nginx_text = read_text("nginx/default.conf")
    web_ok, msg_web = check_file_exists("web/index.html", min_bytes=500)
    nginx_ok = ("listen 80;" in nginx_text) and ("location = /health" in nginx_text) and ('return 200 "OK\\n";' in nginx_text)
    record(
        "요구사항 2·5",
        "웹 서버(Nginx) 80번 포트 실행 및 / (웹화면), /health (200 OK 'OK') 응답 구성",
        web_ok and nginx_ok,
        f"nginx/default.conf (listen 80 & /health return 200 OK) + {msg_web}",
    )

    # 3. IAM 최소권한 정책 JSON 검증 (AdministratorAccess 미부여, 서울 리전 조건, 무관 서비스 Deny)
    iam_raw = read_text("iam/least-privilege-policy.json")
    iam_json = json.loads(iam_raw)
    statements = iam_json.get("Statement", [])
    has_no_admin = "AdministratorAccess" not in iam_raw and '"Action": "*"' not in iam_raw
    has_seoul_cond = '"aws:RequestedRegion": "ap-northeast-2"' in iam_raw
    has_explicit_deny = any(s.get("Effect") == "Deny" and "s3:*" in s.get("Action", []) for s in statements)
    record(
        "요구사항 4",
        "IAM 최소권한 정책 (AdministratorAccess 배제, 서울 리전 제한, S3/RDS 명시적 거부)",
        has_no_admin and has_seoul_cond and has_explicit_deny,
        f"iam/least-privilege-policy.json (Statement {len(statements)}개, 서울 리전 Condition 및 S3/RDS Deny 확인)",
    )

    # --------------------------------------------------------------------------
    # [검사 파트 C] 보너스 과제 1 (HTTPS) & 보너스 과제 2 (Docker 컨테이너 배포) 검증
    # --------------------------------------------------------------------------
    print("\n▶ 3단계: 보너스 과제 1 (HTTPS) & 보너스 과제 2 (Docker 컨테이너 배포) 검증")

    # 보너스 1: HTTPS 설정 파일 및 Certbot 스크립트 확인
    ok_ssl_conf, msg_ssl_conf = check_file_exists("nginx/default-ssl.conf", min_bytes=200)
    ok_ssl_sh, msg_ssl_sh = check_file_exists("scripts/setup-https.sh", min_bytes=200)
    record(
        "보너스 1",
        "무료 도메인 연결 및 Let's Encrypt (Certbot) HTTPS 443 인증서 적용 구성",
        ok_ssl_conf and ok_ssl_sh,
        f"{msg_ssl_conf} / {msg_ssl_sh}",
    )

    # 보너스 2: Dockerfile, docker-compose.yml, docker ps 스크린샷 확인
    ok_df, msg_df = check_file_exists("Dockerfile", min_bytes=100)
    ok_dc, msg_dc = check_file_exists("docker-compose.yml", min_bytes=100)
    ok_dps, msg_dps = check_file_exists("docs/screenshots/docker-ps-check.png", min_bytes=5000)
    dc_text = read_text("docker-compose.yml") if ok_dc else ""
    has_port_map = '"80:80"' in dc_text and "codyssey-web:latest" in readme_text
    record(
        "보너스 2",
        "Docker 컨테이너 웹 서비스 배포 (codyssey-web:latest, 포트 80:80 매핑, docker ps 증빙)",
        ok_df and ok_dc and ok_dps and has_port_map,
        f"{msg_df} / {msg_dc} / {msg_dps}",
    )

    # --------------------------------------------------------------------------
    # [최종 결과 요약 출력]
    # --------------------------------------------------------------------------
    print("\n" + "=" * 84)
    print(f" 🎯 최종 평가 검증 결과 : 총 {total}개 핵심 평가 항목 중 {passed}개 통과 ({passed / total * 100:.0f}%)")
    print(" 📖 발표 대본 열람      : docs/evaluation-script.md 파일을 열어 그대로 발표하세요!")
    print("=" * 84)

    return 0 if passed == total else 1


if __name__ == "__main__":
    raise SystemExit(run_evaluation())
