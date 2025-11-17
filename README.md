# 🧊 pg_lake Sandbox

**Turn PostgreSQL into a data lakehouse.** Query Parquet files on S3-compatible storage directly through Postgres using DuckDB's engine.

Deploy locally for development or on a cloud VM for production. Works with MinIO 🪣 or SeaweedFS 🌾 backends.

## Quick Start

### Local Development

```bash
git clone https://github.com/TheMadBotterINC/PG-Lake-Make.git
cd PG-Lake-Make

# Copy environment template and customize if needed
cp .env.example .env

# Start the stack (MinIO by default)
make up
make seed
make psql
```

Query your data:
```sql
SELECT event_type, COUNT(*)
FROM mro_events_parquet
GROUP BY 1 ORDER BY 2 DESC;
```

**Using SeaweedFS instead?** Just add `MODE=seaweed-fs` to any make command.

### Cloud Deployment

**Option 1: Automated Script**
```bash
./deploy-to-do.sh <droplet_ip> minio <github_token>
```

**Option 2: Cloud-Init**
1. Create an Ubuntu 22.04+ droplet
2. Paste `cloud-init-minio.yml` into **User Data** during creation
3. Wait 3-5 minutes for automatic setup
4. Access:
   - PostgreSQL: `psql -h <droplet_ip> -U postgres -d postgres`
   - MinIO Console: `http://<droplet_ip>:9001` (minioadmin/minioadmin)

## Common Commands

| Command | Description |
|---------|-------------|
| `make up` | Start the stack |
| `make seed` | Load sample data |
| `make psql` | Connect to PostgreSQL |
| `make logs` | View container logs |
| `make down` | Stop and remove everything |

Add `MODE=seaweed-fs` to use SeaweedFS instead of MinIO.

## Security

⚠️ **Default credentials are for development only!**

**Before production:**
1. Copy `.env.example` to `.env` and set strong passwords
2. Configure firewall rules for ports: 5432 (PostgreSQL), 9000/9001 (MinIO)
3. Enable SSL/TLS for PostgreSQL
4. Restrict `pg_hba.conf` to specific IP ranges
5. Use a secrets manager for credential storage

## What's Inside

- **PostgreSQL** with [pg_lake](https://github.com/Snowflake-Labs/pg_lake) extension
- **DuckDB** via pgduck_server for Parquet processing
- **MinIO** or **SeaweedFS** for S3-compatible storage
- Pre-built Docker images (no compilation required)
- Sample MRO maintenance dataset

## Architecture

Queries flow through PostgreSQL → DuckDB engine → Parquet files on S3 storage. The `pg_lake` extension creates foreign tables that map to Parquet files, while DuckDB handles the actual data reading and processing.

## Contributing

Issues and pull requests welcome! This project builds on [Snowflake Labs' pg_lake](https://github.com/Snowflake-Labs/pg_lake).

## License

MIT License - see [LICENSE](LICENSE) for details.
