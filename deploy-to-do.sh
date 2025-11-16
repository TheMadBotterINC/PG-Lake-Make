#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Deploy pg_lake stack to DigitalOcean droplet
# ==============================================================================
# Usage:
#   ./deploy-to-do.sh <droplet_ip> <mode> <github_token>
#
# Arguments:
#   droplet_ip    - IP address of your DO droplet
#   mode          - Either 'minio' or 'seaweed-fs'
#   github_token  - GitHub Personal Access Token with packages:read scope
#
# Example:
#   ./deploy-to-do.sh 192.168.1.100 minio ghp_xxxxxxxxxxxxx
# ==============================================================================

if [ $# -ne 3 ]; then
    echo "Usage: $0 <droplet_ip> <mode> <github_token>"
    echo ""
    echo "  droplet_ip    - IP address of your DO droplet"
    echo "  mode          - Either 'minio' or 'seaweed-fs'"
    echo "  github_token  - GitHub PAT with packages:read scope"
    exit 1
fi

DROPLET_IP="$1"
MODE="$2"
GH_TOKEN="$3"
GH_USER="${GH_USER:-themadbotterinc}"

if [[ "$MODE" != "minio" && "$MODE" != "seaweed-fs" ]]; then
    echo "❌ Error: mode must be 'minio' or 'seaweed-fs'"
    exit 1
fi

echo "🚀 Deploying pg_lake stack to $DROPLET_IP (mode: $MODE)"
echo ""

# ==============================================================================
# Step 1: Install Docker on droplet
# ==============================================================================
echo "📦 Installing Docker on droplet..."
ssh root@$DROPLET_IP bash <<'ENDSSH'
set -euo pipefail

# Install dependencies
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    ca-certificates curl apt-transport-https ufw git

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

echo "✅ Docker installed"
ENDSSH

# ==============================================================================
# Step 2: Configure firewall
# ==============================================================================
echo "🔥 Configuring firewall..."
ssh root@$DROPLET_IP bash <<'ENDSSH'
set -euo pipefail

ufw allow OpenSSH
ufw allow 5432/tcp   # Postgres
ufw allow 9000/tcp   # MinIO S3
ufw allow 9001/tcp   # MinIO Console
ufw allow 8333/tcp   # SeaweedFS S3
ufw allow 8888/tcp   # SeaweedFS Filer
ufw --force enable

echo "✅ Firewall configured"
ENDSSH

# ==============================================================================
# Step 3: Authenticate with GitHub Container Registry
# ==============================================================================
echo "🔐 Authenticating with GHCR..."
ssh root@$DROPLET_IP bash <<ENDSSH
set -euo pipefail

echo "$GH_TOKEN" | docker login ghcr.io -u "$GH_USER" --password-stdin

echo "✅ Authenticated with GHCR"
ENDSSH

# ==============================================================================
# Step 4: Create deployment directory and copy files
# ==============================================================================
echo "📁 Creating deployment directory..."
ssh root@$DROPLET_IP "mkdir -p /opt/pg-lake"

echo "📤 Copying configuration files..."
if [ "$MODE" = "minio" ]; then
    scp docker-compose-minio.yml root@$DROPLET_IP:/opt/pg-lake/docker-compose.yml
    scp duckdb_init.sql root@$DROPLET_IP:/opt/pg-lake/
    scp .env root@$DROPLET_IP:/opt/pg-lake/
else
    scp docker-compose-seaweed-fs.yml root@$DROPLET_IP:/opt/pg-lake/docker-compose.yml
    scp duckdb_init_seaweed.sql root@$DROPLET_IP:/opt/pg-lake/duckdb_init_seaweed.sql
fi

scp -r seed root@$DROPLET_IP:/opt/pg-lake/

echo "✅ Files copied"

# ==============================================================================
# Step 5: Pull images and start stack
# ==============================================================================
echo "🐳 Pulling images and starting stack..."
ssh root@$DROPLET_IP bash <<'ENDSSH'
set -euo pipefail

cd /opt/pg-lake

# Pull images
echo "Pulling images..."
docker compose pull

# Start stack
echo "Starting stack..."
docker compose up -d

# Wait for services to be healthy
echo "Waiting for services to be ready..."
sleep 10

echo "✅ Stack is running"
ENDSSH

# ==============================================================================
# Step 6: Create bucket and seed data
# ==============================================================================
echo "🪣 Creating bucket..."
ssh root@$DROPLET_IP bash <<'ENDSSH'
set -euo pipefail

cd /opt/pg-lake

# Create bucket (will wait for minio to be healthy)
docker compose up create-bucket --abort-on-container-exit

echo "✅ Bucket created"
ENDSSH

echo "🌱 Seeding data..."
ssh root@$DROPLET_IP bash <<'ENDSSH'
set -euo pipefail

cd /opt/pg-lake

# Run seed container (depends on create-bucket completion)
docker compose up parquet-seed --abort-on-container-exit

echo "✅ Data seeded"
ENDSSH

# ==============================================================================
# Step 7: Setup Postgres foreign table
# ==============================================================================
echo "🐘 Setting up Postgres foreign table..."
ssh root@$DROPLET_IP bash <<'ENDSSH'
set -euo pipefail

# Wait for postgres to be fully ready
sleep 5

PG_CONTAINER=$(docker ps -qf "name=pg_lake-postgres")

if [ -z "$PG_CONTAINER" ]; then
    echo "❌ Error: pg_lake-postgres container not found"
    exit 1
fi

# Create extension and foreign table
docker exec $PG_CONTAINER psql -U postgres -d postgres -c \
    "CREATE EXTENSION IF NOT EXISTS pg_lake CASCADE;"

docker exec $PG_CONTAINER psql -U postgres -d postgres -c \
    "CREATE FOREIGN TABLE IF NOT EXISTS mro_events_parquet() 
     SERVER pg_lake 
     OPTIONS (path 's3://opdi/flight_list/mro_events.parquet');"

echo "✅ Foreign table created"
ENDSSH

# ==============================================================================
# Step 8: Verify deployment
# ==============================================================================
echo ""
echo "🎉 Deployment complete!"
echo ""
echo "Verifying data..."
ssh root@$DROPLET_IP bash <<'ENDSSH'
set -euo pipefail

PG_CONTAINER=$(docker ps -qf "name=pg_lake-postgres")
COUNT=$(docker exec $PG_CONTAINER psql -U postgres -d postgres -t -c \
    "SELECT COUNT(*) FROM mro_events_parquet;" | xargs)

echo "✅ mro_events_parquet contains $COUNT rows"
ENDSSH

echo ""
echo "📊 Access your deployment:"
echo "  - Postgres: psql -h $DROPLET_IP -U postgres -d postgres"
if [ "$MODE" = "minio" ]; then
    echo "  - MinIO Console: http://$DROPLET_IP:9001 (minioadmin/minioadmin)"
    echo "  - MinIO S3 API: http://$DROPLET_IP:9000"
else
    echo "  - SeaweedFS S3 API: http://$DROPLET_IP:8333"
    echo "  - SeaweedFS Filer: http://$DROPLET_IP:8888"
fi
echo ""
echo "🔍 View logs:"
echo "  ssh root@$DROPLET_IP 'cd /opt/pg-lake && docker compose logs -f'"
