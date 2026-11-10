# ==============================================================================
# [파일 이름] Dockerfile (보너스 과제 2: Docker 컨테이너로 웹 서비스 배포하기)
# [실생활 비유] 어느 컴퓨터(EC2)에 가져가도 똑같은 웹 서버 가게를 1초 만에 차릴 수 있는
#              '프랜차이즈 밀키트 조리법'입니다.
# ==============================================================================

# [1구역: 기본 밀키트 반죽 가져오기]
# - FROM : "~로부터 시작한다" (바탕이 될 베이스 이미지를 지정하는 명령어)
# - nginx:1.27-alpine : 전 세계에서 가장 많이 쓰는 웹 서버 'nginx' 1.27 버전에
#                       용량이 아주 가볍고 빠른 'alpine' 리눅스를 결합한 공식 이미지입니다.
FROM nginx:1.27-alpine

# [2구역: 기존 기본 설정표를 치우고 우리가 만든 안내 데스크 매뉴얼 넣기]
# - RUN : 밀키트를 조리(빌드)하는 도중에 리눅스 명령어를 실행하라는 뜻입니다.
# - rm -f : 묻지 않고 강제로(-f, force) 파일을 지우라(rm, remove)는 뜻입니다.
# - /etc/nginx/conf.d/default.conf : Nginx 안에 원래 들어있던 초기 설정 파일 위치입니다.
RUN rm -f /etc/nginx/conf.d/default.conf

# - COPY <내폴더파일> <컨테이너안쪽경로> : 내 컴퓨터의 파일을 컨테이너 안으로 복사해 넣습니다.
# - 우리가 만든 nginx/default.conf (일반 접속 / 과 헬스체크 /health 가 모두 설정된 파일)를 넣어줍니다.
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

# [3구역: 손님에게 보여줄 홈페이지 화면(index.html) 넣기]
# - web/index.html 파일을 컨테이너 내부의 웹 문서 기본 서랍장(/usr/share/nginx/html/)으로 복사합니다.
COPY web/index.html /usr/share/nginx/html/index.html

# [4구역: 출입문 번호(80번 포트) 안내 표시]
# - EXPOSE 80 : "이 컨테이너는 웹 표준 포트인 80번 문을 사용합니다"라고 알려주는 표지판입니다.
#   (실제 외부와 연결할 때는 docker run -p 80:80 옵션으로 호스트 80번과 연결합니다.)
EXPOSE 80

# [5구역: 컨테이너 자가 건강검진(HEALTHCHECK) 설정]
# - --interval=30s     : 30초마다 한 번씩 스스로 건강 상태를 점검합니다.
# - --timeout=3s       : 3초 안에 대답이 없으면 응답 실패로 간주합니다.
# - --start-period=5s  : 컨테이너가 막 켜진 뒤 첫 5초 동안은 준비 시간으로 봐줍니다.
# - --retries=3        : 3번 연속 대답을 못 하면 '아픔(unhealthy)' 상태로 표시합니다.
# - CMD wget -qO- http://localhost/health || exit 1 :
#   컨테이너 스스로 http://localhost/health 를 호출해 "OK" 대답이 잘 나오면 정상(healthy),
#   실패하면(||) 에러 코드 1(exit 1)을 반환합니다. (docker ps 에서 'Up (healthy)'가 뜨는 비결!)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost/health || exit 1

# [6구역: 컨테이너가 켜질 때 웹 서버 영업 시작 명령]
# - CMD ["nginx", "-g", "daemon off;"] :
#   컨테이너가 시작될 때 Nginx를 백그라운드 숨김 모드 없이(daemon off;) 정면에서 계속 실행시켜
#   컨테이너가 꺼지지 않고 24시간 내내 손님 요청을 받도록 유지합니다.
CMD ["nginx", "-g", "daemon off;"]
