# PostgreSQL 17 — with **pg_cron**, **pg_stat_statements**, and **pgaudit** (multi-arch)

[![GHCR](https://img.shields.io/badge/GHCR-ghcr.io%2Fcuriousdanil%2Fpostgres%3A17-1f6feb?logo=github)](https://ghcr.io/curiousdanil)
![Architectures](https://img.shields.io/badge/architectures-amd64%20%7C%20arm64-0ea5e9)
[![License](https://img.shields.io/badge/license-Apache%202.0-10b981)](./LICENSE)

A lean, production-minded PostgreSQL 17 image that **“just works”** with:

- **pg_cron** — schedule SQL jobs inside Postgres  
- **pg_stat_statements** — visibility into query performance  
- **pgaudit** — auditable DDL & write operations  
- **Sane defaults** baked in  
- **Multi-arch** builds for `linux/amd64` and `linux/arm64`

Built on top of the official `postgres:17-bookworm`. Licensed under **Apache 2.0**.

## Table of Contents

- [Why this image?](#why-this-image)
- [What’s inside](#whats-inside)
- [Quickstart](#quickstart)
- [Configuration notes](#configuration-notes)
- [Usage Examples](#usage-examples)
- [Troubleshooting](#troubleshooting)
- [Further Reading](#further-reading)

---

## ✨ Why this image?

The official image doesn’t enable **pg_cron**, **pg_stat_statements**, or **pgaudit** out of the box.  
This image saves you from hand-rolling preload config & init scripts every time—so you can schedule jobs, profile queries, and capture audit logs **on day one**.

---

## 📦 What’s inside

Installed packages:

- `postgresql-17-cron`
- `postgresql-contrib-17`
- `postgresql-17-pgaudit`

Preloaded at first init (via `postgresql.conf` sample):

```conf
shared_preload_libraries = 'pg_cron,pg_stat_statements,pgaudit'
cron.database_name = 'postgres'

pg_stat_statements.max = 10000
pg_stat_statements.track = top
pg_stat_statements.save = on

pgaudit.log = 'write, ddl'
pgaudit.log_parameter = on
pgaudit.log_relation = on
```

---

## 🚀 Quickstart

### Pull & run

```bash
docker pull ghcr.io/curiousdanil/postgres:17

# default DB is "postgres"
docker run --rm -e POSTGRES_PASSWORD=pass -p 5432:5432 \
  ghcr.io/curiousdanil/postgres:17
```

### docker-compose

```yaml
services:
  db:
    image: ghcr.io/curiousdanil/postgres:17
    environment:
      POSTGRES_PASSWORD: mypassword
      POSTGRES_DB: postgres
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
volumes:
  pgdata:
```

### Sanity checks

```bash
# Show which libs are preloaded and which DB pg_cron is bound to
psql "postgres://postgres:pass@localhost:5432/postgres" -c "SHOW shared_preload_libraries;"
psql "postgres://postgres:pass@localhost:5432/postgres" -c "SHOW cron.database_name;"
```

---

## ⚙️ Configuration notes

### Cron DB binding

This image fixes `cron.database_name = 'postgres'`.  
Create cron jobs from the `postgres` DB:

```sql
SELECT cron.schedule('reset_pg_stat', '0 3 * * *',
  $$SELECT pg_stat_statements_reset();$$);
```

Need a job to run in another DB? Use:

```sql
SELECT cron.schedule_in_database(
  job_name := 'refresh_mv',
  schedule := '*/5 * * * *',
  command  := $$REFRESH MATERIALIZED VIEW app.mv$$,
  database := 'myappdb'
);
```

### Environment variables (same as the official image)

- `POSTGRES_PASSWORD` (required)  
- `POSTGRES_DB` (optional, default `postgres`)  
- `POSTGRES_USER` (optional, default `postgres`)

### Auditing (pgaudit)

Basic auditing is enabled (`write, ddl`). Ensure logs are collected:

```sql
ALTER SYSTEM SET logging_collector = on;
ALTER SYSTEM SET log_destination    = 'stderr';
ALTER SYSTEM SET log_line_prefix    = '%m [%p] user=%u db=%d app=%a ';
SELECT pg_reload_conf();
```

Scope auditing to specific users (recommended):

```sql
CREATE ROLE auditor;
ALTER SYSTEM SET pgaudit.role = 'auditor';
SELECT pg_reload_conf();
GRANT auditor TO app_user;  -- only this user’s activity is audited
```

### pg_stat_statements usage

```sql
-- find top total time queries
SELECT query, calls, total_exec_time, mean_exec_time
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;

-- reset stats (e.g., nightly via cron)
SELECT pg_stat_statements_reset();
```

### Logging

Audit entries and general Postgres logs go to container stdout/stderr.  
Ensure your platform collects these logs.

---

## 📝 Usage Examples

### pg_cron

1. Schedule a daily vacuum:
   ```sql
   SELECT cron.schedule('daily-vacuum', '0 4 * * *', 'VACUUM ANALYZE;');
   ```

2. Schedule an hourly materialized view refresh in a custom DB:
   ```sql
   SELECT cron.schedule_in_database(
     job_name := 'hourly-refresh',
     schedule := '0 * * * *',
     command  := $$REFRESH MATERIALIZED VIEW CONCURRENTLY app.sales_summary;$$,
     database := 'myappdb'
   );
   ```

### pgaudit

1. Log a DDL operation (e.g., creating a table) and check the audit log in container output:
   ```sql
   CREATE TABLE test_audit (id SERIAL PRIMARY KEY);
   ```
   (Look for entries like: `AUDIT: SESSION,1,1,DDL,CREATE TABLE,...`)

2. Log a write operation with parameters (e.g., insert) for an audited user:
   ```sql
   INSERT INTO users (name, email) VALUES ('John Doe', 'john@example.com');
   ```
   (Audit log will include the statement and parameters if `pgaudit.log_parameter = on`.)

### pg_stat_statements

1. Identify slowest queries by mean time:
   ```sql
   SELECT query, calls, mean_exec_time
   FROM pg_stat_statements
   ORDER BY mean_exec_time DESC
   LIMIT 10;
   ```

2. Track shared buffer hits for queries:
   ```sql
   SELECT query, shared_blks_hit, shared_blks_read
   FROM pg_stat_statements
   WHERE calls > 100
   ORDER BY shared_blks_hit DESC;
   ```

---

## 🛠️ Troubleshooting

- **Extension not loaded?** Check container logs for errors during init (e.g., `docker logs <container>`). Ensure the container has write access to `/var/lib/postgresql/data`. Extensions are created in the DB named "postgres"—if using a custom `POSTGRES_DB`, switch to "postgres" for setup or sanity checks.
- **TestContainers Integration:** Explicitly name the DB as "postgres" to align with extension creation:
  ```kotlin
  @Container
  @ServiceConnection
  @JvmStatic
  val postgres =
      PostgreSQLContainer(
          DockerImageName
              .parse("ghcr.io/curiousdanil/postgres:17")
              .asCompatibleSubstituteFor("postgres"),
      ).withDatabaseName("postgres") // HERE!
  ```
- **pg_cron Issues:** If jobs aren't running, verify `cron.database_name` via `SHOW cron.database_name;`. Check pg_cron logs in the Postgres log for scheduling errors. Ensure the cron extension is installed: `SELECT * FROM pg_extension WHERE extname = 'pg_cron';`.
- **pgaudit Not Logging?** Confirm `pgaudit.log` settings with `SHOW pgaudit.log;`. Reload config after changes (`SELECT pg_reload_conf();`). Test with a simple DDL/write and grep logs for "AUDIT:".
- **pg_stat_statements Empty?** Run some queries first to populate stats. If still empty, check if it's preloaded (`SHOW shared_preload_libraries;`) and restart the container if needed.
- **Custom Config Overrides:** Mount a custom `postgresql.conf` via volumes to tweak settings: `-v ./my.conf:/etc/postgresql/postgresql.conf`.

---

## 🔗 Further Reading

- [pg_cron Docs](https://github.com/citusdata/pg_cron)
- [pg_stat_statements](https://www.postgresql.org/docs/current/pgstatstatements.html)
- [pgaudit](https://www.pgaudit.org/)
- [Official Postgres Docker Image](https://hub.docker.com/_/postgres)
- [Docker Documentation](https://docs.docker.com/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
