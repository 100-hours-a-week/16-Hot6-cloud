#!/bin/bash
set -e

echo "▶️ 필수 디렉토리 생성"
mkdir -p /home/ubuntu/backend
mkdir -p /var/log/onthetop/backend
chown -R ubuntu:ubuntu /var/log/onthetop/backend

echo "▶️ Docker 설치"
if ! command -v docker &> /dev/null; then
  apt-get update && apt-get install -y docker.io
fi

echo "▶️ GCP Secret Manager에서 secrets.properties 가져오기"

SECRETS_FILE="/home/ubuntu/backend/secrets.properties"
mkdir -p "$(dirname "$SECRETS_FILE")"
touch "$SECRETS_FILE"

SECRET_NAME="onthetop-backend-secrets"
SECRET_LABELS="backend_shared backend_prod"

for LABEL in $SECRET_LABELS; do
  gcloud secrets list --filter="labels.env=$LABEL" --format="value(name)" | while read SECRET_NAME; do
    SECRET_VALUE=$(gcloud secrets versions access latest --secret="$SECRET_NAME")
    IFS='-' read -r SERVICE KEY ENV <<< "$SECRET_NAME"
    echo "${KEY}=${SECRET_VALUE}" >> "$SECRETS_FILE"
  done
done

chown ubuntu:ubuntu "$SECRETS_FILE"

echo "▶️ GCP Secret Manager에서 확정된 Docker 버전 가져오기"
RAW_VERSION=$(gcloud secrets versions access latest --secret=confirmed-backend-version | tr -d '\r\n ')
DOCKER_VERSION="v${RAW_VERSION}"
echo "✅ CONFIRMED_VERSION = $DOCKER_VERSION"

echo "▶️ Docker 이미지 pull 및 실행"
docker pull luckyprice1103/onthetop-backend:$DOCKER_VERSION

docker run -d \
  --name onthetop-backend-blue \
  -p 8080:8080 \
  --memory=512m \
  --cpus=0.5 \
  -v /home/ubuntu/backend/secrets.properties:/app/secrets.properties \
  -v /var/log/onthetop/backend:/logs \
  -e SPRING_PROFILES_ACTIVE=prod \
  luckyprice1103/onthetop-backend:$DOCKER_VERSION \
  --logging.file.name=/logs/backend.log \
  --spring.config.additional-location=file:/app/secrets.properties

echo "▶️ Nginx 설치 및 설정"
apt-get install -y nginx

cat <<EOF > /etc/nginx/sites-available/backend
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

ln -sf /etc/nginx/sites-available/backend /etc/nginx/sites-enabled/backend
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl restart nginx

echo "✅ 컨테이너 및 Nginx 기동 완료: onthetop-backend:$DOCKER_VERSION"
