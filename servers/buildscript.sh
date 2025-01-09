#!/bin/bash

# Define variables
PROJECT=""
PERSONAL_DIR=""
SERVER_NAME=""
VERSION=$(date +"%Y%m%d%H%M%S")  # Use timestamp as version
BASE_DIR="/home/${SERVER_NAME}/${PERSONAL_DIR}/${PROJECT}"
LOG_DIR="${BASE_DIR}/logs"       # Log directory
ROLLBACK_DIR="${BASE_DIR}/rollback"  # Directory for rollback images
VERSION_BACKUP_DIR="${ROLLBACK_DIR}/${VERSION}" # Directory for database backups
LOG_FILE="${LOG_DIR}/build_${VERSION}.log"
NEW_IMAGE="${BASE_DIR}/${PROJECT}.tar"
OLD_IMAGE="${ROLLBACK_DIR}/${VERSION}/${PROJECT}_${VERSION}.tar"

# Database variables
DB_CONTAINER_NAME="${PROJECT}_mariadb_1"
DB_USER=""  # Replace with your DB user
DB_PASS=""  # Replace with your DB password
DB_NAME=""  # Replace with your database name

# Ensure required directories exist
mkdir -p "$LOG_DIR"
mkdir -p "$ROLLBACK_DIR"
mkdir -p "$VERSION_BACKUP_DIR"

# Log function
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "$LOG_FILE"
}

# Stop and backup old container/image
log "Stopping and removing current container..."
sudo docker stop ${PROJECT}_${PROJECT}_1 | tee -a "$LOG_FILE"
sudo docker rm ${PROJECT}_${PROJECT}_1 | tee -a "$LOG_FILE"

log "Backing up current image..."
if sudo docker save -o "$OLD_IMAGE" ${PROJECT} | tee -a "$LOG_FILE"; then
  log "Image backup successful: $OLD_IMAGE"
else
  log "Image backup failed, aborting deployment."
  exit 1
fi

# Backup database
log "Backing up database..."
CONTAINER_IP=$(sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$DB_CONTAINER_NAME")
if mysqldump -h "$CONTAINER_IP" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "${VERSION_BACKUP_DIR}/${DB_NAME}_backup.sql"; then
  log "Database backup successful: ${VERSION_BACKUP_DIR}/${DB_NAME}_backup.sql"
else
  log "Database backup failed, aborting deployment."
  exit 1
fi

# Deploy new version
log "Removing old image..."
sudo docker image rm ${PROJECT} | tee -a "$LOG_FILE"

log "Loading new image..."
if sudo docker load -i "$NEW_IMAGE" | tee -a "$LOG_FILE"; then
  log "New image loaded successfully."
else
  log "Failed to load new image, aborting deployment."
  exit 1
fi

log "Starting new container..."
if sudo docker-compose up -d | tee -a "$LOG_FILE"; then
  log "Deployment successful."
else
  log "Deployment failed, rolling back to previous version."

  # Rollback to the old version
  log "Loading old image..."
  if sudo docker load -i "$OLD_IMAGE" | tee -a "$LOG_FILE"; then
    log "Old image loaded successfully."

    log "Starting container with old image..."
    if sudo docker-compose up -d | tee -a "$LOG_FILE"; then
      log "Rollback successful."
    else
      log "Rollback failed. Manual intervention required."
    fi
  else
    log "Failed to load old image. Manual intervention required."
  fi
fi

# Log cleanup: Remove logs older than 1 month
log "Cleaning up old logs..."
find "$LOG_DIR" -type f -mtime +30 -exec rm -f {} \;
log "Old logs cleaned up."

# Rollback directory cleanup: Keep only the 7 most recent versions
log "Cleaning up old rollback versions..."
BACKUP_COUNT=$(ls -1 "$ROLLBACK_DIR" | grep -E `${PROJECT}_\d{8}\.tar` | wc -l)
if [ "$BACKUP_COUNT" -gt 7 ]; then
  # Get the oldest files to delete
  OLD_FILES=$(ls -1t "$ROLLBACK_DIR" | grep -E `${PROJECT}_\d{8}\.tar` | tail -n +8)
  for FILE in $OLD_FILES; do
    rm -f "$ROLLBACK_DIR/$FILE"
    log "Removed old rollback image: $FILE"
  done
fi

# Finish
log "Build process completed."
sudo docker logs -f ${PROJECT}_${PROJECT}_1
