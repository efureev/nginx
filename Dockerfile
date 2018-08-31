FROM debian:stretch-slim
LABEL Description="Image with Nginx latest" Vendor="fureev@gmail.com"

RUN \
  apt-get -yq update && apt-get install -y gnupg2 curl \
  && echo "deb http://nginx.org/packages/debian/ stretch nginx" >> /etc/apt/sources.list.d/nginx.list \
  && curl -L http://nginx.org/keys/nginx_signing.key | apt-key add - \
  && apt-get -yq update && apt-get install -y nginx openssl \
  && nginx -v \
  && apt-get -yqq clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && rm -rfv /usr/share/nginx/html

COPY ./data/config /etc/nginx
COPY ./data/html /usr/share/nginx/html
COPY ./docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]

STOPSIGNAL SIGTERM

# Add VOLUMEs to allow backup of config and logs, and use socket:
#   /var/run/nginx/nginx.pid
# And logs:
#   /var/log/nginx/error.log
#   /var/log/nginx/access.log
VOLUME ["/var/run/nginx", "/var/log/nginx"]

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
