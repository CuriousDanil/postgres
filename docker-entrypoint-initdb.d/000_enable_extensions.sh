#!/usr/bin/env bash
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<'SQL'
  CREATE EXTENSION IF NOT EXISTS pg_cron;
  CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
  CREATE EXTENSION IF NOT EXISTS pgaudit;
SQL

if [ -n "${POSTGRES_DB:-}" ] && [ "$POSTGRES_DB" != "postgres" ]; then
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'SQL'
  CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
  CREATE EXTENSION IF NOT EXISTS pgaudit;
SQL
fi