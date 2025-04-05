#!/bin/bash

CHECK_INTERVAL=30    # Interval in minutes
URL="https://raw.githubusercontent.com/DontSmiteMeDown/Tor-Relay-Stuff/refs/heads/main/NAMEHERE"
LOCAL_CONFIG_PATH="/etc/tor/torrc"
BACKUP_PATH="$LOCAL_CONFIG_PATH.backup"
CURL_TIMEOUT=20
TOR_SERVICE_NAME="tor"

# Function to compare versions
version_greater() {
    # Compare two version strings, returns 0 if the first is greater
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n 1)" != "$1" ]
}

perform_update() {
    echo "Downloading new config file from $URL..."
    curl --fail --max-time $CURL_TIMEOUT "$URL" -o "$LOCAL_CONFIG_PATH.new"

    if [ $? -ne 0 ]; then
        echo "Failed to download the config file. Skipping this check."
        return 1
    fi

    if [ ! -f "$LOCAL_CONFIG_PATH" ]; then
        echo "Local config file not found. Skipping update."
        return 1
    fi

    DOWNLOADED_VERSION=$(head -n 1 "$LOCAL_CONFIG_PATH.new" | sed 's/#//')
    LOCAL_VERSION=$(head -n 1 "$LOCAL_CONFIG_PATH" | sed 's/#//')

    echo "Local version: $LOCAL_VERSION"
    echo "Downloaded version: $DOWNLOADED_VERSION"

    if version_greater "$DOWNLOADED_VERSION" "$LOCAL_VERSION"; then
        echo "New version detected. Validating config..."

        tor -f "$LOCAL_CONFIG_PATH.new" --verify-config
        if [ $? -ne 0 ]; then
            echo "Downloaded config is invalid. Aborting update."
            rm "$LOCAL_CONFIG_PATH.new"
            return 1
        fi

        echo "Config is valid. Backing up and updating..."
        cp "$LOCAL_CONFIG_PATH" "$BACKUP_PATH-$(date +%Y%m%d-%H%M%S)"
        mv "$LOCAL_CONFIG_PATH.new" "$LOCAL_CONFIG_PATH"

        echo "Reloading Tor service..."
        sudo systemctl reload $TOR_SERVICE_NAME

        echo "Update successful, config file updated, and Tor reloaded."
    else
        echo "Downloaded version is older or the same as the local version. Skipping update."
        rm "$LOCAL_CONFIG_PATH.new"
    fi
}

while true; do
    perform_update
    sleep $((CHECK_INTERVAL * 60))
done
