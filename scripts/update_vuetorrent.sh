#!/bin/bash

# --- Configuration ---
# Define the absolute path to your VueTorrent installation on your Unraid array.
# This is the directory where you initially ran 'git clone ...'.
VUETORRENT_REPO_DIR="/mnt/cache/appdata/binhex-qbittorrentvpn/vuetorrent"

# Define the exact name of your qBittorrent Docker container.
# This should match the name shown in your Unraid Docker tab (e.g., 'binhex-qbittorrentvpn').
QBITTORRENT_CONTAINER_NAME="binhex-qbittorrentvpn"

# --- Script Logic ---
echo "--- Starting VueTorrent Updater Plugin Script ---"
echo "Run time: $(date)"
echo "VueTorrent repository path: $VUETORRENT_REPO_DIR"
echo "qBittorrent container name: $QBITTORRENT_CONTAINER_NAME"
echo " " # Empty line for readability

# Step 1: Verify the Git repository exists
if [ ! -d "$VUETORRENT_REPO_DIR/.git" ]; then
    echo "ERROR: Git repository not found in '$VUETORRENT_REPO_DIR'."
    echo "Please ensure the initial 'git clone --single-branch --branch latest-release https://github.com/VueTorrent/VueTorrent.git .' was performed correctly into this directory."
    echo "Script aborted as VueTorrent files cannot be updated."
    # Send an alert notification for this critical error
    notifysend -t alert -i error "VueTorrent Updater: Update Failed!" "Git repository not found at '$VUETORRENT_REPO_DIR'. Please check script configuration or perform initial setup."
    exit 1
fi

# Step 2: Navigate to the VueTorrent repository directory
cd "$VUETORRENT_REPO_DIR" || {
    echo "ERROR: Failed to change directory to '$VUETORRENT_REPO_DIR'."
    echo "Check if the path is correct and accessible. Script aborted."
    # Send an alert notification for this critical error
    notifysend -t alert -i error "VueTorrent Updater: Update Failed!" "Could not access VueTorrent directory '$VUETORRENT_REPO_DIR'. Please check path and permissions."
    exit 1
}

echo "Attempting to pull latest changes from VueTorrent Git repository (latest-release branch)..."
# Step 3: Perform the git pull operation and check for changes
# 'git pull origin latest-release' will fetch new commits from the remote 'latest-release' branch
# and automatically merge them into your local copy, overwriting older files.
git_pull_output=$(git pull origin latest-release 2>&1) # Capture stdout and stderr
pull_status=$? # Capture the exit status of git pull

RESTART_CONTAINER=false # Initialize flag

if [[ "$pull_status" -ne 0 ]]; then
    echo "WARNING: 'git pull' command failed or encountered an error."
    echo "Git output: $git_pull_output"
    # Send a warning notification if git pull itself failed
    notifysend -t warning -i warning "VueTorrent Updater: Update Warning!" "Git pull failed for VueTorrent. Output: $git_pull_output"
    RESTART_CONTAINER=true # Attempt restart even on pull failure (might be transient)
elif [[ "$git_pull_output" == *"Already up to date."* ]]; then
    echo "VueTorrent is already up to date. No container restart needed."
    RESTART_CONTAINER=false
else
    echo "Successfully pulled latest VueTorrent changes."
    RESTART_CONTAINER=true # Restart needed
fi

echo " " # Empty line for readability

# Step 4: Conditional restart of the Docker container and notification
if [ "$RESTART_CONTAINER" = true ]; then
    echo "Restarting Docker container '$QBITTORRENT_CONTAINER_NAME' to apply new VueTorrent files..."
    # Check if the container exists and is running before attempting to restart.
    if docker inspect -f '{{.State.Running}}' "$QBITTORRENT_CONTAINER_NAME" &> /dev/null; then
        if docker restart "$QBITTORRENT_CONTAINER_NAME"; then
            echo "Successfully restarted '$QBITTORRENT_CONTAINER_NAME'."
            echo "VueTorrent update process completed."
            # Send success notification
            notifysend -t normal -i info "VueTorrent Updater: Updated!" "VueTorrent UI has been updated to the latest version and '$QBITTORRENT_CONTAINER_NAME' container restarted."
        else
            echo "ERROR: Failed to restart '$QBITTORRENT_CONTAINER_NAME'."
            echo "Please check your Docker containers in Unraid. You may need to restart it manually."
            # Send error notification for restart failure
            notifysend -t alert -i error "VueTorrent Updater: Update Error!" "Failed to restart '$QBITTORRENT_CONTAINER_NAME' after update. Manual intervention required."
        fi
    else
        echo "ERROR: Docker container '$QBITTORRENT_CONTAINER_NAME' not found or not running. Cannot restart."
        # Send error notification if container not found/running
        notifysend -t alert -i error "VueTorrent Updater: Update Error!" "Container '$QBITTORRENT_CONTAINER_NAME' not found or not running. Cannot apply VueTorrent update."
    fi
fi

echo "--- VueTorrent Updater Plugin Script Finished ---"
exit 0