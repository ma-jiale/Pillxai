#!/bin/sh
# Runs as the deployment account UID, with no Docker socket or host privileges.
set -eu
umask 077
export PGPASSWORD="$(cat /run/secrets/app-password)"
while :; do
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    temporary="$(mktemp /backups/.daily-XXXXXX)"
    if pg_dump -h db -U pillxai_v2 -d pillxai_v2 -Fc --no-owner > "$temporary" && \
       pg_restore --list "$temporary" > /dev/null; then
        destination="/backups/daily-$stamp.dump"
        mv "$temporary" "$destination"
        sha256sum "$destination" > "$destination.sha256"
        date -u +%s > /backups/last-success
        echo "Daily database backup completed: $stamp"
        sleep 86400
    else
        rm -f "$temporary"
        echo 'Database backup failed; retry in 5 minutes.' >&2
        sleep 300
    fi
done
