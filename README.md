# 🧊 **pg_lake Sandbox**

### Postgres + DuckDB + Parquet + Object Store = Data Lake Magic

🚀 *Spin up a full mini "lakehouse" stack locally or on a cloud VM.*\
Works with both **MinIO** 🪣 and **SeaweedFS** 🌾 backends --- just pick
your flavor.

------------------------------------------------------------------------

## 🧩 What's Inside

  -----------------------------------------------------------------------
  Component                              Purpose
  -------------------------------------- --------------------------------
  🐘 **Postgres**                        Runs the `pg_lake` extension
                                         (foreign data wrapper for
                                         Parquet/S3)

  🦆 **pgduck_server**                   DuckDB engine that does the
                                         heavy lifting for Parquet reads

  🪣 **MinIO / SeaweedFS**               Your local S3-compatible object
                                         store

  📦 **duckdb_init.sql**                 Connection config for the object
                                         store

  🧰 **Makefile**                        One-liner shortcuts to launch /
                                         seed / inspect everything

  📈 **seed.duckdb.sql**                 Generates fake MRO maintenance
                                         data in Parquet

  ☁️ \*\*cloud-init-\*.yml\*\*           Ready-to-paste configs for new
                                         droplets
  -----------------------------------------------------------------------

------------------------------------------------------------------------

## ⚙️ Quick Start (Local)

``` bash
# clone the repo
git clone https://github.com/TheMadBotterINC/PG-Lake-Make.git
cd PG-Lake-Make

# bring up the default (MinIO) stack
make up

# seed test data into MinIO
make seed

# connect to Postgres
make psql
```

Now try a quick query:

``` sql
SELECT event_type, COUNT(*)
FROM mro_events_parquet
GROUP BY 1
ORDER BY 2 DESC;
```

------------------------------------------------------------------------

## 🌾 SeaweedFS Mode

Prefer SeaweedFS? Easy:

``` bash
make up MODE=seaweed-fs
make seed MODE=seaweed-fs
```

By default the Seaweed S3 gateway runs on **:8333**.\
You can confirm everything's live with:

``` bash
make ps MODE=seaweed-fs
```

------------------------------------------------------------------------

## ☁️ Deploying on DigitalOcean (or any Ubuntu LTS)

1.  Create a new droplet (Ubuntu 22.04+).\

2.  Scroll to **Advanced Options → User Data**.\

3.  Paste one of these:

    -   `cloud-init-minio.yml` for 🪣 MinIO\
    -   `cloud-init-seaweed-fs.yml` for 🌾 SeaweedFS\

4.  Click **Create Droplet**.\

5.  Wait \~3--5 min. Then SSH in:

    ``` bash
    ssh root@<your_droplet_ip>
    docker ps
    ```

6.  Verify data:

    ``` bash
    docker exec -it $(docker ps -qf name=pg_lake-postgres)      psql -U postgres -d postgres -c "SELECT COUNT(*) FROM mro_events_parquet;"
    ```

MinIO console → `http://<droplet_ip>:9001`\
SeaweedFS S3 gateway → `http://<droplet_ip>:8333`

------------------------------------------------------------------------

## 🧰 Useful Commands

  Command       Action
  ------------- -------------------------------------------------
  `make up`     Start stack (`MODE=minio` or `MODE=seaweed-fs`)
  `make seed`   Generate synthetic MRO data as Parquet
  `make logs`   Tail all container logs
  `make ps`     Show running services
  `make psql`   Drop into Postgres shell
  `make down`   Stop and remove containers/volumes

------------------------------------------------------------------------

## 🧠 Notes

-   Images are automatically built and published to GHCR via GitHub Actions.\
-   Each compose file is self-contained; no rebuilds or submodules
    needed.
-   MinIO's default creds: `minioadmin / minioadmin`.
-   SeaweedFS auto-creates buckets on PUT; no manual setup needed.

------------------------------------------------------------------------

## 🕹️ Pro Tips

-   🔒 **Pin versions:** When you're happy, swap `:latest` for a tagged
    release (or digest).\
-   💾 **Add swap** on small droplets:
    `fallocate -l 4G /swapfile && mkswap /swapfile && swapon /swapfile`.\
-   🚧 **No Docker Desktop?** Works fine under Podman too.\
-   🌈 **Extend it:** Add PostGIS, pgaudit, or your own `init.sql` in
    `pg_init/`.

------------------------------------------------------------------------

## 🐙 Credits

Built with ❤️ by humans + a 🤖\
Inspired by Snowflake-Labs' `pg_lake` and DuckDB's Parquet engine.
