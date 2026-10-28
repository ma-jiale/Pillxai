#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
PREFIX="$ROOT/.tools/conda/backend"
export CONDA_PKGS_DIRS="$ROOT/.tools/conda/pkgs"
export CONDA_ENVS_PATH="$ROOT/.tools/conda/envs"
export CONDA_REGISTER_ENVS=false
export XDG_CACHE_HOME="$ROOT/.tools/cache"
export PIP_CACHE_DIR="$ROOT/.tools/pip-cache"
export TMPDIR="$ROOT/.tools/tmp"
export PYTHONPATH="$ROOT/apps/api/src"
ACTION="${1:-help}"
mkdir -p "$ROOT/.var" "$ROOT/.tools" "$TMPDIR"

if [[ "$ACTION" == bootstrap ]]; then
  CONDA_BIN="${PILLXAI_CONDA:-/home/jiale/miniforge3/bin/conda}"
  if [[ ! -x "$PREFIX/bin/python" ]]; then
    if [[ -f "$ROOT/apps/api/conda-linux-64.lock" ]]; then
      "$CONDA_BIN" create --yes --prefix "$PREFIX" --file "$ROOT/apps/api/conda-linux-64.lock"
    else
      "$CONDA_BIN" create --yes --prefix "$PREFIX" --override-channels -c conda-forge python=3.12 postgresql=18 pip
    fi
  fi
  if [[ -f "$ROOT/apps/api/requirements.lock" ]]; then
    "$PREFIX/bin/python" -m pip install -r "$ROOT/apps/api/requirements.lock"
    "$PREFIX/bin/python" -m pip install --no-deps --no-build-isolation -e "$ROOT/apps/api[test]"
  else
    "$PREFIX/bin/python" -m pip install -e "$ROOT/apps/api[test]"
    "$PREFIX/bin/python" -m pip list --format=freeze --exclude pillxai-api --exclude pip --exclude setuptools --exclude wheel > "$ROOT/apps/api/requirements.lock"
  fi
  "$CONDA_BIN" list --prefix "$PREFIX" --explicit > "$ROOT/apps/api/conda-linux-64.lock"
  exit 0
fi

if [[ ! -x "$PREFIX/bin/python" ]]; then
  echo 'Run backend.ps1 bootstrap first.' >&2
  exit 1
fi
export PATH="$PREFIX/bin:$PATH"
PGPORT="${PILLXAI_PGPORT:-5432}"
DATA_DIR="$ROOT/.var/postgres"
if [[ -f "$ROOT/.var/backend-pgdata.txt" ]]; then DATA_DIR="$(cat "$ROOT/.var/backend-pgdata.txt")"; fi
if [[ "$ACTION" == db-init && -n "${2:-}" ]]; then DATA_DIR="$2"; fi
PASSWORD_FILE="$ROOT/.var/backend-password"

if [[ "$ACTION" == db-init ]]; then
  mkdir -p "$DATA_DIR"
  chmod 700 "$DATA_DIR"
  if [[ "$(stat -c %a "$DATA_DIR")" != 700 ]]; then
    echo 'PostgreSQL needs a directory supporting mode 0700. Supply an approved WSL-native project directory.' >&2
    exit 1
  fi
  if [[ ! -f "$PASSWORD_FILE" ]]; then
    python -c 'import secrets; print(secrets.token_hex(32))' > "$PASSWORD_FILE"
  fi
  if [[ ! -f "$DATA_DIR/PG_VERSION" ]]; then
    initdb -D "$DATA_DIR" --username=pillxai --pwfile="$PASSWORD_FILE" --auth=scram-sha-256 --encoding=UTF8 --locale=C
  fi
  printf '%s\n' "$DATA_DIR" > "$ROOT/.var/backend-pgdata.txt"
fi

if [[ -f "$PASSWORD_FILE" ]]; then
  export PGPASSWORD="$(cat "$PASSWORD_FILE")"
  export PILLXAI_DATABASE_URL="postgresql+psycopg://pillxai:$PGPASSWORD@127.0.0.1:$PGPORT/pillxai_dev"
  export PILLXAI_TEST_DATABASE_URL="postgresql+psycopg://pillxai:$PGPASSWORD@127.0.0.1:$PGPORT/pillxai_test"
fi

case "$ACTION" in
  db-init|db-start)
    if [[ ! -f "$DATA_DIR/PG_VERSION" ]]; then echo 'Run db-init first.' >&2; exit 1; fi
    if ! pg_ctl -D "$DATA_DIR" status >/dev/null 2>&1; then
      pg_ctl -D "$DATA_DIR" -l "$DATA_DIR/server.log" -o "-h 127.0.0.1 -p $PGPORT -k ''" -w start
    fi
    for database in pillxai_dev pillxai_test; do
      exists="$(psql -h 127.0.0.1 -p "$PGPORT" -U pillxai -d postgres -Atc "SELECT 1 FROM pg_database WHERE datname='$database'")"
      if [[ "$exists" != 1 ]]; then createdb -h 127.0.0.1 -p "$PGPORT" -U pillxai "$database"; fi
    done
    ;;
  db-stop) pg_ctl -D "$DATA_DIR" -m fast -w stop ;;
  migrate)
    alembic -c apps/api/alembic.ini upgrade head
    PILLXAI_DATABASE_URL="$PILLXAI_TEST_DATABASE_URL" alembic -c apps/api/alembic.ini upgrade head
    ;;
  serve)
    export PILLXAI_ENABLE_CONTRACT_PROBE=true
    exec uvicorn pillxai_api.app:create_app --factory --host "${PILLXAI_API_HOST:-127.0.0.1}" --port "${PILLXAI_API_PORT:-8000}"
    ;;
  test)
    : "${PILLXAI_TEST_DATABASE_URL:?Run db-init and migrate before the integration tests}"
    python -m pytest apps/api/tests -q --capture=sys
    ;;
  lint) ruff check apps/api ;;
  seed) python apps/api/tools/seed_local.py ;;
  export) python apps/api/tools/export_openapi.py ;;
  *) echo 'Actions: bootstrap, db-init [WSL data directory], db-start, db-stop, migrate, seed, serve, test, lint, export' ;;
esac
