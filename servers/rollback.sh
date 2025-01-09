#!/bin/bash

# Define variables
PROJECT=""  # Replace with your project name
BASE_DIR="/home/vea/dungna31/${PROJECT}"
ROLLBACK_DIR="${BASE_DIR}/rollback"
LOG_DIR="${BASE_DIR}/logs"
LOG_FILE="${LOG_DIR}/rollback_$(date +"%Y%m%d%H%M%S").log"

# Database variables
CONTAINER_NAME="${PROJECT}_mariadb_1"
DB_USER=""  # Replace with your DB user
DB_PASS=""  # Replace with your DB password
DB_NAME=""  # Replace with your database name

# Ensure required directories exist
mkdir -p "$LOG_DIR"

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

BACKUP_IMAGE="${ROLLBACK_DIR}/${VERSION}/${PROJECT}_${VERSION}.tar"

if [ ! -f "$BACKUP_IMAGE" ]; then
  log "Error: Backup image for version ${VERSION} not found. Aborting."
  exit 1
fi

# Stop current container
log "Stopping and removing current container..."
sudo docker stop ${PROJECT}_${PROJECT}_1 | tee -a "$LOG_FILE"
sudo docker rm ${PROJECT}_${PROJECT}_1 | tee -a "$LOG_FILE"

# Load and start the rollback image
log "Rolling back to version ${VERSION}..."
if sudo docker load -i "$BACKUP_IMAGE" | tee -a "$LOG_FILE"; then
  log "Image loaded successfully."

  log "Starting container with the rolled-back image..."
  if sudo docker-compose up -d | tee -a "$LOG_FILE"; then
    log "Rollback to version ${VERSION} successful."
  else
    log "Failed to start container. Manual intervention required."
    exit 1
  fi
else
  log "Failed to load image for version ${VERSION}. Manual intervention required."
  exit 1
fi

# Finish
log "Rollback process completed."
sudo docker logs -f ${PROJECT}_${PROJECT}_1
