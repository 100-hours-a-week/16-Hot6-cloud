#!/bin/bash
set -e

echo "🚀 Starting backend instance bootstrap (Docker version)..."


# 0. 필수 패키지 설치
apt update && apt install -y docker.io jq

# 1. 메타데이터에서 버전 정보 가져오기
METADATA_URL="http://metadata.google.internal/computeMetadata/v1/instance/attributes"
VERSION=$(curl -s -H "Metadata-Flavor: Google" "$METADATA_URL/startup-version")
ENV="prod"

echo "✅ Version: $VERSION"
echo "✅ Environment: $ENV"

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
echo "🧹 Cleaning up existing Docker container..."
docker rm -f backend || true


# 5. Docker 이미지 pull
echo "📦 Pulling Docker image luckyprice1103/onthetop-backend:$VERSION"
docker pull luckyprice1103/onthetop-backend:$VERSION

#6. Docker 이미지 실행

echo "🚀 Running backend Docker container..."
docker run -d \
  --name backend \
  -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=prod \
  -v "$SECRETS_FILE":/app/secrets.properties \
  -v "$LOG_DIR":/logs \
  luckyprice1103/onthetop-backend:$VERSION \
  --spring.config.additional-location=file:/app/secrets.properties \
  --logging.file.path=/logs/backend.log

echo "✅ Backend Docker container is up and running."
