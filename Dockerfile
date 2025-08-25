# Dockerfile
ARG PG_MAJOR=17
FROM postgres:${PG_MAJOR}-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends wget gnupg ca-certificates \
 && echo "deb http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
 && wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg \
 && apt-get update && apt-get install -y --no-install-recommends \
      postgresql-${PG_MAJOR}-cron \
      postgresql-contrib-${PG_MAJOR} \
      postgresql-${PG_MAJOR}-pgaudit \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
  echo "shared_preload_libraries = 'pg_cron,pg_stat_statements,pgaudit'" >> /usr/share/postgresql/postgresql.conf.sample; \
  echo "cron.database_name = 'postgres'"                                   >> /usr/share/postgresql/postgresql.conf.sample; \
  echo "pg_stat_statements.max = 10000"                                    >> /usr/share/postgresql/postgresql.conf.sample; \
  echo "pg_stat_statements.track = top"                                    >> /usr/share/postgresql/postgresql.conf.sample; \
  echo "pg_stat_statements.save = on"                                      >> /usr/share/postgresql/postgresql.conf.sample; \
  echo "pgaudit.log = 'write, ddl'"                                        >> /usr/share/postgresql/postgresql.conf.sample; \
  echo "pgaudit.log_parameter = on"                                        >> /usr/share/postgresql/postgresql.conf.sample; \
  echo "pgaudit.log_relation = on"                                         >> /usr/share/postgresql/postgresql.conf.sample

COPY docker-entrypoint-initdb.d/000_enable_extensions.sh /docker-entrypoint-initdb.d/