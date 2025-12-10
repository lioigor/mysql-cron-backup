#!/bin/bash
tail -F /mysql_backup.log &

# Get hostname: try read from file, else get from env
[ -z "${MYSQL_HOST_FILE}" ] || { MYSQL_HOST=$(head -1 "${MYSQL_HOST_FILE}"); }
[ -z "${MYSQL_HOST}" ] && { echo "=> MYSQL_HOST cannot be empty" && exit 1; }
# Get username: try read from file, else get from env
[ -z "${MYSQL_USER_FILE}" ] || { MYSQL_USER=$(head -1 "${MYSQL_USER_FILE}"); }
[ -z "${MYSQL_USER}" ] && { echo "=> MYSQL_USER cannot be empty" && exit 1; }
# Get password: try read from file, else get from env
[ -z "${MYSQL_PASS_FILE}" ] || { MYSQL_PASS=$(head -1 "${MYSQL_PASS_FILE}"); }
[ -z "${MYSQL_PASS:=$MYSQL_PASSWORD}" ] && { echo "=> MYSQL_PASS cannot be empty" && exit 1; }

if [ "${INIT_BACKUP:-0}" -gt "0" ]; then
  echo "=> Create a backup on the startup"
  /backup.sh
elif [ -n "${INIT_RESTORE_LATEST}" ]; then
  echo "=> Restore latest backup"
  until nc -z "$MYSQL_HOST" "$MYSQL_PORT"
  do
      echo "waiting database container..."
      sleep 1
  done
  find /backup -maxdepth 1 -name '[0-9]*.*.sql.gz' | sort | tail -1 | xargs /restore.sh
fi

function final_backup {
    echo "=> Captured trap for final backup"
    echo "=> Requested last backup at $(date "+%Y-%m-%d %H:%M:%S")"
    exec /backup.sh
    exit 0
}

if [ -n "${EXIT_BACKUP}" ]; then
  echo "=> Listening on container shutdown gracefully to make last backup before close"
  trap final_backup SIGHUP SIGINT SIGTERM
fi

touch /HEALTHY.status

# Create crontab with environment variables embedded
cat > /tmp/crontab.conf << EOF
MYSQL_HOST=${MYSQL_HOST}
MYSQL_PORT=${MYSQL_PORT:-3306}
MYSQL_USER=${MYSQL_USER}
MYSQL_PASS=${MYSQL_PASS}
MYSQL_DB=${MYSQL_DB:-}
MYSQL_DATABASE=${MYSQL_DATABASE:-}
MYSQLDUMP_OPTS=${MYSQLDUMP_OPTS:-}
MAX_BACKUPS=${MAX_BACKUPS:-}
GZIP_LEVEL=${GZIP_LEVEL:-6}
USE_PLAIN_SQL=${USE_PLAIN_SQL:-}
MYSQL_SSL_OPTS=${MYSQL_SSL_OPTS:-}

${CRON_TIME} /backup.sh >> /mysql_backup.log 2>&1
EOF

crontab /tmp/crontab.conf
echo "=> Running cron task manager in foreground"
crond -n -s &

echo "Listening on crond, and wait..."

tail -f /dev/null & wait $!

echo "Script is shutted down."
