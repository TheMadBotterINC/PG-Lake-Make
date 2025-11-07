#!/bin/bash
set -e

echo "🔨 Building pg_lake images locally for testing..."
echo ""

# Clone pg_lake source if needed
if [ ! -d /tmp/pg_lake ]; then
  echo "📦 Cloning pg_lake source..."
  git clone https://github.com/Snowflake-Labs/pg_lake.git /tmp/pg_lake
fi

cd /tmp/pg_lake/docker

echo ""
echo "🐘 Building pg_lake-postgres image..."
docker build \
  --target pg_lake_postgres \
  --build-arg BASE_IMAGE_OS=almalinux \
  --build-arg BASE_IMAGE_TAG=9 \
  -t ghcr.io/themadbotterinc/pg_lake-postgres:latest \
  .

echo ""
echo "🦆 Building pgduck_server image..."
docker build \
  --target pgduck_server \
  --build-arg BASE_IMAGE_OS=almalinux \
  --build-arg BASE_IMAGE_TAG=9 \
  -t ghcr.io/themadbotterinc/pgduck_server:latest \
  .

echo ""
echo "✅ Images built successfully!"
echo ""
echo "Now you can test with:"
echo "  make up MODE=minio"
echo "  make seed"
echo "  make psql"
