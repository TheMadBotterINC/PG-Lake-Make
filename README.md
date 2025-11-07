# pg_lake Sandbox (Postgres + pgduck_server + MinIO) --- README

Spin up a **shared pg_lake test sandbox** your team can query from
Blazer/psql.\
Tested on **Ubuntu LTS** (fresh VM or an existing box).

------------------------------------------------------------------------

## What you get

-   **Postgres** with the `pg_lake` extension enabled\
-   **pgduck_server** (DuckDB worker for Parquet/S3 reads)\
-   **MinIO** (S3-compatible object storage) with a **seed Parquet**
    (MRO-ish `mro_events.parquet`)\
-   Makefile targets to bring the whole stack **up/down/seed** in one
    command

------------------------------------------------------------------------

## 0) Prereqs (Ubuntu LTS)

``` bash
# 0.1 Update & basics
sudo apt-get update -y

# 0.2 Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker  # (or log out/in)

# 0.3 (Optional, recommended) Install Tailscale for private access
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh   # or use an auth key if you have one
```

> If this is a brand-new cloud VM, you can also provision it via
> **cloud-init** (we have a ready file). Otherwise, continue below.

------------------------------------------------------------------------

## 1) Get the files onto the server

Put the repo contents (or copy this folder) to `/opt/pg-lake`:

    /opt/pg-lake/
      docker-compose.yml              # base compose (from pg_lake/docker or our copy)
      docker-compose.override.yml     # adds MinIO + seed job + mounts
      duckdb_init.sql                 # DuckDB S3 settings (MinIO)
      pg_init/00_pg_lake.sql          # Postgres init: CREATE EXTENSION + foreign table
      seed.duckdb.sql                 # generates Parquet into MinIO
      Makefile                        # one-command wrapper

If you don't have the base compose from the pg_lake repo, use the one
bundled here.\
Make sure your **compose files** match the service names used in the
Makefile.

------------------------------------------------------------------------

## 2) Configure (optional)

Default credentials are fine for a sandbox, but you can override:

``` bash
export MINIO_ROOT_USER=minioadmin
export MINIO_ROOT_PASSWORD=minioadmin
# Optional public domain for MinIO behind Caddy (leave empty to keep private)
export DOMAIN=""
```

If you're using **Tailscale**, you can keep everything bound to
`127.0.0.1` and connect through the tailnet.\
If not, you can expose ports publicly later (not recommended for
Postgres).

------------------------------------------------------------------------

## 3) Bring it up (the "setup & go")

From `/opt/pg-lake`:

``` bash
make up
```

What this does:

1)  `docker compose up -d --wait` → starts **Postgres**,
    **pgduck_server**, **MinIO**\
2)  Runs the **seed** job → writes `mro_events.parquet` to
    `s3://opdi/flight_list/` in MinIO\
3)  Postgres init script enables `pg_lake` and defines
    `mro_events_parquet` foreign table

Check status/logs:

``` bash
make ps
make logs
```

------------------------------------------------------------------------

## 4) Verify with psql

``` bash
make psql
```

Then run:

``` sql
-- Extension present?
SELECT extname FROM pg_extension WHERE extname LIKE 'pg_lake%';

-- Parquet foreign table reachable?
SELECT COUNT(*) FROM mro_events_parquet;

-- Quick analytic
SELECT event_type, COUNT(*) AS events, ROUND(AVG(downtime_hours),2) AS avg_downtime
FROM mro_events_parquet
GROUP BY 1
ORDER BY events DESC;
```

------------------------------------------------------------------------

## 5) Connect Blazer (from your Rails app)

In `config/blazer.yml` add a data source (adjust host as needed):

``` yaml
data_sources:
  pg_lake_local:
    url: postgres://postgres:postgres@127.0.0.1:5432/postgres
    time_zone: "UTC"
```

If connecting from a **different machine**, either:

-   use a **Tailscale** port-forward (recommended):

    ``` bash
    # on your laptop
    ssh -N -L 5432:127.0.0.1:5432 root@<tailscale-hostname-or-ip>
    # then point Blazer at postgres://postgres:postgres@127.0.0.1:5432/postgres
    ```

-   or expose Postgres publicly (not advised) and firewall it to trusted
    IPs only.

------------------------------------------------------------------------

## 6) (Optional) Materialize into Iceberg

``` sql
CREATE TABLE IF NOT EXISTS mro_events_iceberg
USING iceberg AS
SELECT * FROM mro_events_parquet;

SELECT COUNT(*) FROM mro_events_iceberg;
```

------------------------------------------------------------------------

## 7) Common operations

``` bash
make ps        # show containers
make logs      # follow logs
make seed      # regenerate Parquet into MinIO and re-query
make psql      # open psql inside the Postgres container
make down      # stop & remove everything (including volumes)
make restart   # down + up
```

------------------------------------------------------------------------

## 8) Troubleshooting

-   **`mro_events_parquet` is empty or missing**\
    Run `make seed` and check `make logs` to confirm the seed job
    succeeded.\
    Verify MinIO is healthy and the bucket/object exists.

-   **MinIO auth / S3 path errors**\
    Confirm `duckdb_init.sql` S3 settings match your MinIO creds and
    endpoint:

        SET s3_endpoint = 'minio:9000';
        SET s3_url_style = 'path';
        SET s3_use_ssl = false;
        SET s3_access_key_id/secret_access_key = ...

-   **Can't connect to Postgres from a laptop**\
    Use Tailscale and an SSH local forward (see §5). If you must expose
    it, add a public mapping and restrict with UFW to your IPs.

-   **Ports already in use**\
    Edit the `ports:` in `docker-compose*.yml` or stop conflicting
    services.

------------------------------------------------------------------------

## 9) (Optional) One-shot cloud-init (fresh VM)

If you're creating a brand-new Ubuntu LTS VM, you can paste our
**cloud-init** in the provider's "User Data" field to auto-install
Docker, Tailscale, and write these same files under `/opt/pg-lake`, then
`docker compose up -d`. (Ask if you want that file included here
verbatim.)

------------------------------------------------------------------------

### That's it

Your team can now hit a **real pg_lake** instance backed by **Parquet on
S3 (MinIO)** for Blazer queries, demos, and integration tests---without
every dev running Docker locally.
