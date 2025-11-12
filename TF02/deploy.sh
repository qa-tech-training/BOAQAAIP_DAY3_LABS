#!/bin/bash
apt-get update
which docker || apt-get install -y docker.io
docker run -d -p 8080:80 nginx:alpine
docker run -d -p 8081:80 httpd:alpine