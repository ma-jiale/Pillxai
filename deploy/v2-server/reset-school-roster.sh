#!/usr/bin/env bash
# One-time school V2 roster reset, after all terminals and old labels are isolated.
set -euo pipefail
umask 077
root="$HOME/projects/pillxa-dispenser/v2"
test -f "$root/shared/DEPLOYMENT_READY"
exec 9>>"$root/.deploy.lock"
flock -n 9
container() {
    local id
    id=$(docker ps -q --filter label=com.docker.compose.project=pillxai-v2 \
        --filter "label=com.docker.compose.service=$1")
    [[ -n $id && $id != *$'\n'* ]] || return 1
    printf '%s' "$id"
}
db=$(container db)
api=$(container api)
sql=(docker exec -i "$db" psql -X -U postgres -d pillxai_v2 -v ON_ERROR_STOP=1)
dir="$root/backups/roster-reset-20261103"
# An existing directory prevents a second run from deleting newly entered residents.
mkdir "$dir"
docker stop "$api" >/dev/null
trap 'docker start "$api" >/dev/null' EXIT
docker exec "$db" pg_dump -Fc -U postgres -d pillxai_v2 > "$dir/before.dump"
docker exec -i "$db" pg_restore --file=/dev/null < "$dir/before.dump"
"${sql[@]}" <<'SQL'
BEGIN;
SET LOCAL lock_timeout = '5s';
LOCK TABLE dispensing_tasks IN ACCESS EXCLUSIVE MODE;
DO $$
BEGIN
    IF EXISTS (SELECT FROM dispensing_tasks WHERE active) THEN
        RAISE EXCEPTION 'Unfinished dispensing task. Reset cancelled.';
    END IF;
END $$;
TRUNCATE TABLE residents, resident_versions, prescriptions, prescription_versions,
    medicines, resident_labels, prescription_parameters, plan_previews, dispensing_tasks,
    execution_events, deleted_tasks RESTRICT;
ALTER SEQUENCE resident_barcode_number RESTART WITH 1;
DO $$
BEGIN
    IF EXISTS (SELECT FROM residents) OR
       (SELECT last_value <> 1 OR is_called FROM resident_barcode_number) THEN
        RAISE EXCEPTION 'Reset verification failed.';
    END IF;
END $$;
COMMIT;
SQL
docker start "$api" >/dev/null
trap - EXIT
echo "Roster cleared. Next barcode: 000001. Backup: $dir/before.dump"
