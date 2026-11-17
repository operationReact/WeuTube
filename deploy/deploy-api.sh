#!/usr/bin/env bash
# Invoked on the EC2 instance through AWS Systems Manager Run Command.
# Requires only IAM instance-role credentials, not long-lived AWS keys.
set -euo pipefail
umask 077

if [ "$#" -lt 4 ] || [ "$#" -gt 6 ]; then
  echo "Usage: deploy-api.sh <artifact-bucket> <commit-sha> <api-domain> <cognito-issuer> [bootstrap|verify] [cognito-client-id]" >&2
  exit 2
fi
BUCKET="$1"
COMMIT="$2"
DOMAIN="$3"
ISSUER="$4"
MODE="${5:-verify}"
AUTH_CLIENT_ID="${6:-}"
[[ "$MODE" == "bootstrap" || "$MODE" == "verify" ]] || { echo "Unsupported health-check mode" >&2; exit 2; }
REGION="ap-south-1"
[[ -z "$AUTH_CLIENT_ID" || "$AUTH_CLIENT_ID" =~ ^[a-zA-Z0-9]{10,128}$ ]] || { echo "Invalid Cognito client" >&2; exit 2; }
[[ "$BUCKET" =~ ^[a-z0-9.-]+$ ]] || { echo "Invalid artifact bucket" >&2; exit 2; }
[[ "$COMMIT" =~ ^[a-f0-9]{40}$ ]] || { echo "Invalid revision" >&2; exit 2; }
[[ "$DOMAIN" =~ ^[a-z0-9.-]+$ ]] || { echo "Invalid API domain" >&2; exit 2; }
[[ "$ISSUER" =~ ^https://cognito-idp\.ap-south-1\.amazonaws\.com/ap-south-1_[A-Za-z0-9]+$ ]] || {
  echo "Invalid Cognito issuer" >&2; exit 2;
}
# Recover from interrupted EC2 cloud-init without SSH/CloudShell.
# On Amazon Linux 2023 the Docker package may not be present initially.
if ! command -v docker >/dev/null 2>&1; then
  dnf install -y docker
fi
systemctl enable --now docker
if ! docker compose version >/dev/null 2>&1; then
  mkdir -p /usr/local/lib/docker/cli-plugins
  curl --fail --location --retry 3 --silent --show-error \
    https://github.com/docker/compose/releases/download/v2.40.3/docker-compose-linux-x86_64 \
    --output /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi
docker compose version
if ! docker buildx version >/dev/null 2>&1; then
  mkdir -p /usr/local/lib/docker/cli-plugins
  curl --fail --location --retry 3 --silent --show-error \
    https://github.com/docker/buildx/releases/download/v0.19.0/buildx-v0.19.0.linux-amd64 \
    --output /usr/local/lib/docker/cli-plugins/docker-buildx
  chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx
fi
docker buildx version
if ! command -v crontab >/dev/null 2>&1; then
  dnf install -y cronie
fi
systemctl enable --now crond
cd /opt/weutube
mkdir -p secrets
chmod 700 secrets

temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT
for file in app.jar Dockerfile docker-compose.yml Caddyfile backup-db.sh web-dist.zip; do
  aws s3 cp --region "$REGION" "s3://$BUCKET/releases/$COMMIT/$file" "$temp/$file" --only-show-errors
done

# Create stable PostgreSQL credentials once; never regenerate them on redeploy.
if [ ! -f secrets/db.env ]; then
  DB_PASSWORD="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
  printf 'POSTGRES_USER=weutube\nPOSTGRES_PASSWORD=%s\n' "$DB_PASSWORD" > secrets/db.env
fi
chmod 600 secrets/db.env
# Safe because the generated password contains only hexadecimal characters.
set -a
# shellcheck disable=SC1091
source secrets/db.env
set +a

# Fetch three exact parameter names that the owner already created in SSM.
# Do not enable shell tracing or print these values.
CLIENT_ID="$(aws ssm get-parameter --region "$REGION" --name /weutube/prod/youtube/client-id --with-decryption --query Parameter.Value --output text)"
CLIENT_SECRET="$(aws ssm get-parameter --region "$REGION" --name /weutube/prod/youtube/client-secret --with-decryption --query Parameter.Value --output text)"
TOKEN_KEY="$(aws ssm get-parameter --region "$REGION" --name /weutube/prod/youtube/token-key-base64 --with-decryption --query Parameter.Value --output text)"

if [[ -z "$CLIENT_ID" || -z "$CLIENT_SECRET" || -z "$TOKEN_KEY" ]]; then
  echo "Required YouTube configuration is unavailable" >&2
  exit 1
fi

# Generate environment file without emitting its contents in SSM command logs.
# The API process reads SSM directly at startup as well (role permissions needed).
cat > secrets/app.env <<EOF
PORT=8080
DATABASE_URL=jdbc:postgresql://postgres:5432/weutube
DATABASE_USERNAME=weutube
DATABASE_PASSWORD=$POSTGRES_PASSWORD
COGNITO_ISSUER_URI=$ISSUER
WEUTUBE_COGNITO_REGION=$REGION
WEUTUBE_COGNITO_CLIENT_ID=$AUTH_CLIENT_ID
WEUTUBE_YOUTUBE_SSM_ENABLED=true
WEUTUBE_RELEASE_SHA=$COMMIT
# Operator-authorized shared-channel creator uploads; uploads remain PRIVATE until review.
WEUTUBE_YOUTUBE_CREATOR_AUTO_UPLOAD_ENABLED=true
WEUTUBE_YOUTUBE_SSM_REGION=$REGION
WEUTUBE_YOUTUBE_REDIRECT_URI=https://$DOMAIN/api/admin/youtube/callback
EOF
chmod 600 secrets/app.env
WEB_DOMAIN="${DOMAIN#api.}"
[[ "$DOMAIN" == "api.$WEB_DOMAIN" ]] || { echo "Expected api.<domain> hostname" >&2; exit 2; }
printf 'WEUTUBE_API_DOMAIN=%s\nWEUTUBE_WEB_DOMAIN=%s\n' "$DOMAIN" "$WEB_DOMAIN" > .env
chmod 600 .env

# The app itself loads OAuth secrets via AWS SDK; do not put them in app.env.
install -m 600 "$temp/app.jar" app.jar
install -m 644 "$temp/Dockerfile" Dockerfile
install -m 600 "$temp/docker-compose.yml" docker-compose.yml
install -m 644 "$temp/Caddyfile" Caddyfile
install -m 700 "$temp/backup-db.sh" backup-db.sh
# Unpack the prebuilt Flutter website; CloudFront is not required.
rm -rf web-dist.next
mkdir -p web-dist.next
python3 -m zipfile -e "$temp/web-dist.zip" web-dist.next
test -f web-dist.next/index.html
rm -rf web-dist
mv web-dist.next web-dist
# Static web files are public assets: nginx worker must be able to traverse
# directories and read assets, even though deploy runs with umask 077.
find web-dist -type d -exec chmod 755 {} +
find web-dist -type f -exec chmod 644 {} +

docker compose config --quiet
# Amazon Linux 2023 Docker 25 ships Buildx 0.12; modern Compose needs >=0.17.
# Build the vetted local API image directly using the Docker classic builder,
# then explicitly prohibit Compose from rebuilding it with the old plugin.
DOCKER_BUILDKIT=0 docker build --pull -t weutube-api:local -f Dockerfile .
docker compose up -d --no-build --remove-orphans --force-recreate
# Bootstrap mode validates the live Spring Boot process inside the Docker
# network before DNS is changed; it NEVER claims public HTTPS is ready.
if [ "$MODE" = "bootstrap" ]; then
  healthy=false
  for _ in $(seq 1 36); do
    if docker compose exec -T web wget -qO- http://api:8080/actuator/health >/dev/null 2>&1; then
      healthy=true
      break
    fi
    sleep 5
  done
  if [ "$healthy" != true ]; then
    echo "Backend internal health check failed; inspect the API and database containers" >&2
    exit 1
  fi
  printf '15 2 * * * root /opt/weutube/backup-db.sh %s >> /var/log/weutube-db-backup.log 2>&1\n' "$BUCKET" > /etc/cron.d/weutube-db-backup
  chmod 644 /etc/cron.d/weutube-db-backup
  echo "WeuTube backend internal health check passed; PUBLIC HTTPS NOT YET VERIFIED."
  exit 0
fi
# Check the HTTPS site, including ACME certificate validation, not just the container exit code.
healthy=false
for _ in $(seq 1 36); do
  if curl --silent --show-error --fail --max-time 5 \
    --resolve "$DOMAIN:443:127.0.0.1" \
    "https://$DOMAIN/actuator/health" >/dev/null 2>&1; then
    healthy=true
    break
  fi
  sleep 5
done
if [ "$healthy" = true ]; then
  curl --silent --show-error --fail --max-time 10 \
    --resolve "$WEB_DOMAIN:443:127.0.0.1" \
    "https://$WEB_DOMAIN/" > /dev/null || healthy=false
fi
if [ "$healthy" != true ]; then
  echo "HTTPS health check failed; check DNS, certificate, and API logs via SSM" >&2
  exit 1
fi
# Install an off-instance database backup job after the site passed its health check.
printf '15 2 * * * root /opt/weutube/backup-db.sh %s >> /var/log/weutube-db-backup.log 2>&1\n' "$BUCKET" > /etc/cron.d/weutube-db-backup
chmod 644 /etc/cron.d/weutube-db-backup
echo "WeuTube backend HTTPS health check passed for deployment $COMMIT"
