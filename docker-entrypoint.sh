#!/bin/sh
# Docker entrypoint for Oaks
# Restores DB if needed, creates pre-migration backup, runs migrations,
# then starts the app with Litestream replication

set -e

DATABASE_PATH="${DATABASE_PATH:-/data/oaks.db}"
BACKUP_DIR="/data/backups"
# Litestream keeps continuous backups in S3; these local copies only cover a
# migration going wrong, so keep a few (each is a full copy of the database).
MAX_BACKUPS=3

# Fix ownership of data directory and any existing litestream files
# This handles the case where the volume was created by a different deployment
if [ -d /data ]; then
  chown -R oaks:oaks /data
fi

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"
chown oaks:oaks "$BACKUP_DIR"

# Restore from Litestream if no database exists
if [ ! -f "$DATABASE_PATH" ]; then
  echo "No database found, attempting restore from Litestream..."
  # -if-replica-exists exits 0 when there is no replica, so check for the file too.
  if litestream restore -if-replica-exists -o "$DATABASE_PATH" s3://oaks-db-backups/litestream \
    && [ -f "$DATABASE_PATH" ]; then
    chown oaks:oaks "$DATABASE_PATH"
    echo "Database restored from Litestream."
  else
    echo "ERROR: No database and no Litestream backup available."
    echo "Upload a database to the volume or configure Litestream backups."
    exit 1
  fi
fi

# Back up and migrate only when there are migrations to run. Any failure to
# count them falls through to the backup + migrate path, which then fails loudly.
PENDING=$(su-exec oaks /app/bin/oaks eval 'IO.puts(Oaks.Release.pending_migration_count())' | tail -n 1) || PENDING="unknown"

if [ "$PENDING" = "0" ]; then
  echo "No pending migrations; skipping pre-migration backup."
else
  BACKUP_NAME="pre-migrate-$(date +%Y%m%d-%H%M%S).db"
  echo "Pending migrations: $PENDING. Creating pre-migration backup: $BACKUP_NAME"
  if ! sqlite3 "$DATABASE_PATH" ".backup '$BACKUP_DIR/$BACKUP_NAME'"; then
    # Don't leave a partial copy behind (a full disk otherwise fills up with them).
    rm -f "$BACKUP_DIR/$BACKUP_NAME"
    echo "ERROR: pre-migration backup failed; not running migrations."
    exit 1
  fi
  chown oaks:oaks "$BACKUP_DIR/$BACKUP_NAME"

  # Cleanup old backups (keep only MAX_BACKUPS most recent)
  cd "$BACKUP_DIR"
  ls -t pre-migrate-*.db 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm -f
  cd /app

  # Run database migrations
  # Note: release_command doesn't work with SQLite volumes on Fly.io because
  # the release machine gets a forked snapshot that doesn't persist changes
  echo "Running database migrations..."
  su-exec oaks /app/bin/oaks eval 'Oaks.Release.migrate()'
fi

# Switch to oaks user and start litestream with the app
exec su-exec oaks litestream replicate -exec "/app/bin/server"
