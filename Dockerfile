FROM nginx:1.27-alpine

# 기본 Nginx 설정을 제거하고 커스텀 설정(/ 및 /health 엔드포인트 지원) 적용
RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

# 정적 웹 서비스 페이지 복사
COPY web/index.html /usr/share/nginx/html/index.html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
