#!/bin/bash
apt-get update
which docker || apt-get install -y docker.io
cat - > /opt/nginx.conf <<EOF
events {}
http {
  server {
    listen 80;
    location /nginx {
      proxy_pass http://{{ SERVER_IP }}:8080;
    }
    location /apache {
      proxy_pass http://{{ SERVER_IP }}:8081;
    }
  }
}
EOF
docker run -d -p 80:80 --mount type=bind,src=/opt/nginx.conf,target=/etc/nginx/nginx.conf nginx:alpine