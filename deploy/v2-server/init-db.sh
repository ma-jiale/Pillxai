#!/bin/sh
set -eu
PILLXAI_APP_PASSWORD="$(cat /run/secrets/app-password)"
export PILLXAI_APP_PASSWORD
psql -v ON_ERROR_STOP=1 --username postgres --dbname postgres <<'SQL'
\getenv app_password PILLXAI_APP_PASSWORD
SELECT format('CREATE ROLE pillxai_v2 LOGIN PASSWORD %L', :'app_password') \gexec
CREATE DATABASE pillxai_v2 OWNER pillxai_v2;
SQL
unset PILLXAI_APP_PASSWORD
