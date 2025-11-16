# Changelog

## 2025-11-16 - Bug Fixes

### Fixed pg_lake_iceberg Extension Issues

#### Issue 1: Temp File Directory Error
**Problem:** Creating Iceberg tables failed with error:
```
ERROR: IO Error: Cannot open file "/home/postgres/data/base/pgsql_tmp/pgsql_tmp.pg_lake_iceberg_*.0": No such file or directory
```

**Root Cause:** The `pgduck_server` container didn't have access to PostgreSQL's temp file directory because the `postgres-data` volume wasn't shared between containers.

**Solution:**
1. Added `postgres-data:/home/postgres/data` volume mount to `pgduck_server` service in `docker-compose-minio.yml`
2. Added initialization commands to create and set correct permissions (2777 with sticky bit) on `/home/postgres/data/base/pgsql_tmp` directory

**Reference:** Similar issue documented in Snowflake-Labs/pg_lake GitHub issues regarding persistent volumes and pgsql_tmp directory permissions.

#### Issue 2: MinIO Credentials Not Persisting
**Problem:** MinIO credentials weren't persisted in docker-compose configuration, requiring manual reconfiguration on each deployment.

**Solution:**
1. Created `.env` file with default MinIO credentials:
   ```
   MINIO_ROOT_USER=minioadmin
   MINIO_ROOT_PASSWORD=minioadmin
   ```
2. Docker Compose already references these environment variables with defaults, so they now persist across deployments

### Changes Made

#### docker-compose-minio.yml
- Added temp directory initialization in postgres service command:
  ```yaml
  mkdir -p /home/postgres/data/base/pgsql_tmp
  chmod 2777 /home/postgres/data/base/pgsql_tmp
  chown postgres:postgres /home/postgres/data/base/pgsql_tmp
  ```
- Added `postgres-data` volume mount to `pgduck_server` service

#### New Files
- `.env` - Environment variables for MinIO credentials (already in .gitignore)

### Testing
After these changes, Iceberg tables can be successfully created, and data can be inserted and queried:

```sql
CREATE TABLE test_iceberg (
    id INT,
    name TEXT,
    created_at TIMESTAMP
) USING iceberg;

INSERT INTO test_iceberg (id, name, created_at) VALUES 
(1, 'Test 1', '2025-11-16 12:00:00'),
(2, 'Test 2', '2025-11-16 13:00:00');

SELECT * FROM test_iceberg;
```

### Production Deployment Notes
When deploying to production:
1. Update `.env` with secure MinIO credentials
2. Ensure firewall rules allow PostgreSQL port 5432
3. Update `postgresql.conf` to set `listen_addresses = '*'`
4. Update `pg_hba.conf` to allow remote connections with appropriate authentication
