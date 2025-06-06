#!/bin/bash
set -e

echo "🚀 Starting backend instance bootstrap (Docker version)..."


# 0. 필수 패키지 설치
apt update && apt install -y docker.io jq
apt install -y docker.io jq gettext

# 1. 메타데이터에서 버전 정보 가져오기

# 환경 변수에서 우선 가져오고, 없으면 메타데이터에서 fallback
VERSION="${BE_VERSION:-$(curl -s -H "Metadata-Flavor: Google" "$METADATA_URL/startup-version")}"
PORT="${BE_PORT:-$(curl -s -H "Metadata-Flavor: Google" "$METADATA_URL/be-port")}"
SLOT="${BE_SLOT:-$(curl -s -H "Metadata-Flavor: Google" "$METADATA_URL/be-slot")}"
ENV="prod"
CONTAINER_NAME="backend-$SLOT"
NGINX_TEMPLATE="/etc/nginx/templates/backend-template.conf"
NGINX_CONF="/etc/nginx/sites-enabled/backend.conf"


echo "✅ [DRY RUN] Version: $VERSION"
echo "✅ [DRY RUN] Port: $PORT"
echo "✅ [DRY RUN] Slot: $SLOT"
echo "✅ [DRY RUN] Container Name: $CONTAINER_NAME"
echo "✅ [DRY RUN] Environment: $ENV"


echo "🔐 [DRY RUN] Would fetch secrets from Secret Manager..."
echo "🧹 [DRY RUN] Would remove container named $CONTAINER_NAME if exists"
echo "📦 [DRY RUN] Would pull Docker image luckyprice1103/onthetop-backend:$VERSION"
echo "🐳 [DRY RUN] Would run container on port $PORT"
echo "🛠 [DRY RUN] Would generate Nginx config and reload"

# 2. Secret Manager에서 secrets.properties 생성 (확장형)
echo "🔐 Fetching secrets from Secret Manager..."

SECRETS_FILE="/home/ubuntu/backend/secrets.properties"
mkdir -p "$(dirname "$SECRETS_FILE")"
touch "$SECRETS_FILE"

SECRET_LABELS="backend_shared backend_prod"

for LABEL in $SECRET_LABELS; do
  gcloud secrets list --filter="labels.env=$LABEL" --format="value(name)" | while read SECRET_NAME; do
    SECRET_VALUE=$(gcloud secrets versions access latest --secret="$SECRET_NAME")
    IFS='-' read -r SERVICE KEY ENV <<< "$SECRET_NAME"
    echo "${KEY}=${SECRET_VALUE}" >> "$SECRETS_FILE"
  done
done

chown ubuntu:ubuntu "$SECRETS_FILE"


echo "✅ secrets.properties written."

# 3. 로그 디렉토리 생성
LOG_DIR="/var/log/onthetop/backend"
mkdir -p "$LOG_DIR"
chown -R ubuntu:ubuntu "$LOG_DIR"

# 4. 이전 컨테이너 제거
echo "🧹 Cleaning up old container named $CONTAINER_NAME..."
EXISTING_CONTAINER=$(docker ps -aq --filter "name=^/$CONTAINER_NAME\$" || true)
if [ -n "$EXISTING_CONTAINER" ]; then
  docker rm -f "$EXISTING_CONTAINER"
fi


# 5. Docker 이미지 pull
echo "📦 Pulling Docker image luckyprice1103/onthetop-backend:$VERSION"
docker pull luckyprice1103/onthetop-backend:$VERSION

#6. Docker 이미지 실행

echo "🚀 Running backend Docker container on port $PORT..."
docker run -d \
  --name "$CONTAINER_NAME" \
  -p "$PORT":8080 \
  -e SPRING_PROFILES_ACTIVE=$ENV \
  -v "$SECRETS_FILE":/app/secrets.properties \
  -v "$LOG_DIR":/logs \
  luckyprice1103/onthetop-backend:$VERSION \
  --spring.config.additional-location=file:/app/secrets.properties \
  --logging.file.path=/logs/backend.log

echo "✅ Backend container is running on port $PORT"

# 7. Nginx 설정 템플릿 직접 생성
echo "🛠 Generating Nginx template..."
cat <<EOF > "$NGINX_TEMPLATE"
server {
  listen 80;
  server_name localhost;

  location / {
    proxy_pass http://localhost:\$PORT;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
  }
}
EOF

chown ubuntu:ubuntu "$NGINX_TEMPLATE"
chmod 644 "$NGINX_TEMPLATE"

# 8. Nginx 설정 파일 동적 생성 및 reload
echo "⚙️ Updating nginx config for slot $SLOT..."
envsubst '\$PORT \$SLOT' < "$NGINX_TEMPLATE" > "$NGINX_CONF"
nginx -s reload || systemctl reload nginx
echo "✅ Nginx reloaded with new config."