#!/usr/bin/env bash
set -Eeu pipefail

ETHDO="./ethdo"

[ -x "$ETHDO" ] || { echo "ERROR: ethdo not found at $ETHDO"; exit 1; }

echo "Creating offline preparation file..."
echo "This requires connection to a beacon node."
echo

# Prompt for beacon node URL
read -p "Enter beacon node URL (e.g., https://mainnet.beacon-api.nimbus.team): " BEACON_URL

if [ -z "$BEACON_URL" ]; then
    echo "ERROR: Beacon node URL is required"
    exit 1
fi

# Determine network name for filename
if [[ "$BEACON_URL" =~ mainnet ]]; then
    NETWORK="mainnet"
elif [[ "$BEACON_URL" =~ holesky ]]; then
    NETWORK="holesky"
elif [[ "$BEACON_URL" =~ localhost ]] || [[ "$BEACON_URL" =~ 127.0.0.1 ]] || [[ "$BEACON_URL" =~ "://".*":5052" ]]; then
    echo "Detected local beacon node endpoint."
    echo "Which network is your local node running?"
    echo "1. Mainnet"
    echo "2. Hoodi Testnet"
    echo "3. Holesky Testnet"
    read -p "Choose (1-3): " local_choice
    
    case $local_choice in
        1)
            NETWORK="mainnet"
            ;;
        2)
            NETWORK="hoodi"
            ;;
        3)
            NETWORK="holesky"
            ;;
        *)
            echo "Invalid choice, defaulting to hoodi"
            NETWORK="hoodi"
            ;;
    esac
else
    NETWORK="custom"
fi

OUTPUT_FILE="offline-preparation-${NETWORK}.json"

echo "Connecting to: $BEACON_URL"
echo "Output file: $OUTPUT_FILE"
echo "This may take a few minutes..."
echo

# Create offline preparation file
if "$ETHDO" validator credentials set \
    --prepare-offline \
    --connection "$BEACON_URL" \
    --timeout 300s \
    --allow-insecure-connections
then
    # Rename the generated file to network-specific name
    mv offline-preparation.json "$OUTPUT_FILE" 2>/dev/null || true
    echo "✓ Offline preparation file created successfully!"
    echo "  File: $OUTPUT_FILE"
    echo "  Size: $(du -h "$OUTPUT_FILE" | cut -f1)"
    echo
    echo "This file contains all validator state data needed for offline operations."
else
    echo "✗ Failed to create offline preparation file"
    echo "Check your beacon node connection and try again."
    exit 1
fi