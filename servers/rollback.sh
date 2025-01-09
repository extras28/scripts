#!/bin/bash

# Define variables
BASE_DIR="/home/vea/dungna31/${PROJECT}"
ROLLBACK_DIR="${BASE_DIR}/rollback"
LOG_DIR="${BASE_DIR}/logs"
DB_BACKUP_DIR="${ROLLBACK_DIR}/db_backups"
LOG_FILE="${LOG_DIR}/rollback_$(date +"%Y%m%d%H%M%S").log"

# Database variables
CONTAINER_NAME="${PROJECT}_mariadb_1"
DB_USER=""  # Replace with your DB user
DB_PASS=""  # Replace with your DB password
DB_NAME=""  # Replace with your database name

# Ensure required directories exist
mkdir -p "$LOG_DIR"
mkdir -p "$DB_BACKUP_DIR"

# Log function
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "$LOG_FILE"
}

# List available rollback versions
log "Available rollback versions:"
ls -1 "$ROLLBACK_DIR" | tee -a "$LOG_FILE"

# Keep only the latest 6 rollback versions
log "Pruning old rollback versions to keep only the latest 5..."
cd "$ROLLBACK_DIR" || exit 1
ls -t | tail -n +7 | xargs -I {} rm -rf {}
log "Old rollback versions pruned."

# Prompt user for version
log "Enter the version you want to roll back to (e.g., 20250109123045):"
read VERSION

BACKUP_IMAGE="${ROLLBACK_DIR}/${PROJECT}_${VERSION}.tar"
DB_BACKUP_FILE="${DB_BACKUP_DIR}/${VERSION}/${DB_NAME}_backup.sql"

if [ ! -f "$BACKUP_IMAGE" ]; then
  log "Error: Backup image for version ${VERSION} not found. Aborting."
  exit 1
fi

# Stop current container
log "Stopping and removing current container..."
sudo docker stop ${PROJECT}_${PROJECT}_1 | tee -a "$LOG_FILE"
sudo docker rm ${PROJECT}_${PROJECT}_1 | tee -a "$LOG_FILE"

# Backup current database
log "Backing up current database..."
CONTAINER_IP=$(sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER_NAME")
VERSION_DB_BACKUP_DIR="${DB_BACKUP_DIR}/${VERSION}"
mkdir -p "$VERSION_DB_BACKUP_DIR"
if mysqldump -h "$CONTAINER_IP" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$DB_BACKUP_FILE"; then
  log "Database backup successful: $DB_BACKUP_FILE"
else
  log "Database backup failed. Manual intervention required."
fi

# Load and start the rollback image
log "Rolling back to version ${VERSION}..."
if sudo docker load -i "$BACKUP_IMAGE" | tee -a "$LOG_FILE"; then
  log "Image loaded successfully."

  log "Starting container with the rolled-back image..."
  if sudo docker-compose up -d | tee -a "$LOG_FILE"; then
    log "Rollback to version ${VERSION} successful."
  else
    log "Failed to start container. Manual intervention required."
  fi
else
  log "Failed to load image for version ${VERSION}. Manual intervention required."
fi

# Finish
log "Rollback process completed."
