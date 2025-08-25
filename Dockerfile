# Dockerfile
ARG PG_MAJOR=17
FROM postgres:${PG_MAJOR}-bookworm

# Install pg_cron from PGDG
RUN apt-get update && apt-get install -y --no-install-recommends wget gnupg ca-certificates \
 && echo "deb http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
 && wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg \
 && apt-get update && apt-get install -y --no-install-recommends postgresql-${PG_MAJOR}-cron \
 && rm -rf /var/lib/apt/lists/*

# Preload pg_cron on first initdb
RUN set -eux; \
    echo "shared_preload_libraries = 'pg_cron'" >> /usr/share/postgresql/postgresql.conf.sample; \
    echo "cron.database_name = 'postgres'"      >> /usr/share/postgresql/postgresql.conf.sample

COPY docker-entrypoint-initdb.d/000_create_pg_cron.sql /docker-entrypoint-initdb.d/