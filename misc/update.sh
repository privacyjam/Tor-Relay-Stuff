#!/bin/bash

CHECK_INTERVAL=30    # Interval in minutes
URL="https://raw.githubusercontent.com/DontSmiteMeDown/Tor-Relay-Stuff/refs/heads/main/exit-torrc"  # URL to fetch the config from
LOCAL_CONFIG_PATH="/etc/tor/torrc"  # Path to the local Torrc
BACKUP_PATH="$LOCAL_CONFIG_PATH.backup"  # Path to backup config file
CURL_TIMEOUT=20  # Timeout for curl in seconds
TOR_SERVICE_NAME="tor"  # Name of the Tor service

# Function to perform the update check
perform_update() {
    # Download the config
    echo "Downloading new config file from $URL..."
    curl --max-time $CURL_TIMEOUT "$URL" -o "$LOCAL_CONFIG_PATH.new"

    if [ $? -eq 0 ]; then
        echo "Download successful, extracting version information..."

        # Get the version info (first line) from the downloaded config
        DOWNLOADED_VERSION=$(head -n 1 "$LOCAL_CONFIG_PATH.new" | sed 's/#//')

        # Get the local version info (first line) from the current config file
        LOCAL_VERSION=$(head -n 1 "$LOCAL_CONFIG_PATH" | sed 's/#//')

        echo "Local version: $LOCAL_VERSION"
        echo "Downloaded version: $DOWNLOADED_VERSION"

        # Compare the versions
        if [ "$LOCAL_VERSION" != "$DOWNLOADED_VERSION" ]; then
            echo "New version detected, backing up and updating..."

            # Backup the current config file before replacing it
            cp "$LOCAL_CONFIG_PATH" "$BACKUP_PATH"

            # Replace the config file with the downloaded one
            mv "$LOCAL_CONFIG_PATH.new" "$LOCAL_CONFIG_PATH"

            # Restart Tor service to apply new configuration
            echo "Reloading Tor service..."
            sudo systemctl reload $TOR_SERVICE_NAME

            # Confirm the update
            echo "Update successful, config file updated, and Tor reloaded"
        else
            echo "No new version detected."
            # Clean up the downloaded file if it's not used
            rm "$LOCAL_CONFIG_PATH.new"
        fi
    else
        echo "Failed to download the config file from the Gist. Skipping this check."
    fi
}

# Loop to perform update at specified interval
while true; do
    perform_update
    sleep $((CHECK_INTERVAL * 60))  # Wait for the specified interval (in minutes)
done
