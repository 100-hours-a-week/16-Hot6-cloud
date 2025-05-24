#!/bin/bash
set -e

echo "🚀 Starting backend instance bootstrap..."

# 0. 필수 패키지 설치
apt update && apt install -y jq openjdk-21-jre

# 1. 메타데이터에서 버전 정보 가져오기
METADATA_URL="http://metadata.google.internal/computeMetadata/v1/instance/attributes"
VERSION=$(curl -s -H "Metadata-Flavor: Google" "$METADATA_URL/startup-version")
ENV="prod"

echo "✅ Version: $VERSION"
echo "✅ Environment: $ENV"

# 2. GitHub 릴리스에서 backend.jar 다운로드
GITHUB_REPO="100-hours-a-week/16-Hot6-be"
JAR_NAME="backend.jar"

DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/tags/v$VERSION" |
  jq -r ".assets[] | select(.name == \"$JAR_NAME\") | .browser_download_url")

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "❌ Failed to resolve download URL for version $VERSION"
  exit 1
fi

APP_DIR="/home/ubuntu/backend"
mkdir -p "$APP_DIR"
curl -L "$DOWNLOAD_URL" -o "$APP_DIR/backend.jar"
chmod +x "$APP_DIR/backend.jar"

echo "✅ backend.jar downloaded."

# 3. Secret Manager에서 secrets.properties 생성 (확장형)
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

# 4. 로그 디렉토리 생성
LOG_DIR="/var/log/onthetop/backend"
mkdir -p "$LOG_DIR"
chown -R ubuntu:ubuntu "$LOG_DIR"

# 5. 애플리케이션 실행
echo "🚀 Launching backend.jar..."
cd "$APP_DIR"
nohup java -jar backend.jar \
  --spring.config.additional-location=file:$SECRETS_FILE \
  --spring.profiles.active=prod \
  > "$LOG_DIR/backend.log" 2>&1 &

echo "✅ Backend started."
