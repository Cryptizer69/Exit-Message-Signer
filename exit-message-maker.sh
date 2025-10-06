#!/usr/bin/env bash
set -Eu pipefail

ETHDO="./ethdo"
OUT_DIR="./exit-messages"
KEYSTORE_DIR="./keystores"

mkdir -p "$OUT_DIR"
mkdir -p "$KEYSTORE_DIR"

[ -x "$ETHDO" ] || { echo "ERROR: ethdo not found at $ETHDO"; exit 1; }

# Ask user which method to use
echo "How do you want to create exit messages?"
echo "1. From keystore files"
echo "2. From mnemonic phrase"
read -p "Choose (1 or 2): " method_choice

case $method_choice in
    1)
        METHOD="keystore"
        ;;
    2)
        METHOD="mnemonic"
        ;;
    *)
        echo "ERROR: Invalid choice. Please enter 1 or 2."
        exit 1
        ;;
esac

echo

# Ask user which network to use
echo "Which network do you want to create exit messages for?"
echo "1. Mainnet"
echo "2. Hoodi Testnet"
read -p "Choose (1 or 2): " network_choice

case $network_choice in
    1)
        PREP_FILE="./offline-preparation-mainnet.json"
        NETWORK="Mainnet"
        ;;
    2)
        PREP_FILE="./offline-preparation-hoodi.json"
        NETWORK="Hoodi Testnet"
        ;;
    *)
        echo "ERROR: Invalid choice. Please enter 1 or 2."
        exit 1
        ;;
esac

if [ ! -f "$PREP_FILE" ]; then
    echo "ERROR: $PREP_FILE not found"
    echo "Please create the offline preparation file for $NETWORK first."
    exit 1
fi

echo "Using $NETWORK offline preparation file: $PREP_FILE"

# Copy the network-specific file to the name ethdo expects
cp "$PREP_FILE" "./offline-preparation.json"

if [ "$METHOD" = "keystore" ]; then
    # Keystore method validation
    if [ ! -d "$KEYSTORE_DIR" ] || [ -z "$(ls -A "$KEYSTORE_DIR"/keystore-*.json 2>/dev/null)" ]; then
        echo "ERROR: No keystore files found in $KEYSTORE_DIR/"
        echo "Please place your keystore-*.json files in the keystores/ directory."
        exit 1
    fi
    
    echo "Found keystore files in: $KEYSTORE_DIR"
    echo
    
    # Count keystores
    TOTAL_COUNT=$(ls "$KEYSTORE_DIR"/keystore-*.json 2>/dev/null | wc -l)
    echo "Found $TOTAL_COUNT keystore files"
else
    # Mnemonic method - ask for details
    echo
    echo "Enter your mnemonic (input hidden):"
    read -s -r MNEMONIC
    echo
    
    WORD_COUNT=$(echo "$MNEMONIC" | wc -w)
    if [[ "$WORD_COUNT" -ne 12 && "$WORD_COUNT" -ne 24 ]]; then
        echo "ERROR: Mnemonic must be 12 or 24 words (got $WORD_COUNT)"
        exit 1
    fi
    
    read -s -p "Enter mnemonic passphrase (press Enter if none): " MNEMONIC_PASSPHRASE
    echo
    
    read -p "Starting validator index (usually 0): " START_INDEX
    [[ "$START_INDEX" =~ ^[0-9]+$ ]] || { echo "ERROR: Invalid start index"; exit 1; }
    
    read -p "How many validators? " VALIDATOR_COUNT
    [[ "$VALIDATOR_COUNT" =~ ^[0-9]+$ ]] && [ "$VALIDATOR_COUNT" -ge 1 ] || { echo "ERROR: Invalid count"; exit 1; }
    
    TOTAL_COUNT=$VALIDATOR_COUNT
    END_INDEX=$((START_INDEX + VALIDATOR_COUNT - 1))
fi

echo

echo "Total to process: $TOTAL_COUNT"
read -p "Continue? (y/N): " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
echo

success=0
failed=0
current=0

if [ "$METHOD" = "keystore" ]; then
    # Ask for password once for keystores
    read -s -p "Enter password for all keystores: " password
    echo
    echo
    
    # Process keystores
    for keyfile in "$KEYSTORE_DIR"/keystore-*.json; do
        [ -f "$keyfile" ] || continue
        
        ((current++))
        echo "Processing $current of $TOTAL_COUNT: $(basename "$keyfile")..."
        
        # Extract public key from keystore
        pubkey=$(jq -r '.pubkey' "$keyfile" 2>/dev/null || grep -o '"pubkey":\s*"[^"]*"' "$keyfile" | sed 's/.*"pubkey":\s*"\([^"]*\)".*/\1/')
        if [ -z "$pubkey" ]; then
            echo "✗ Failed to extract public key from $keyfile"
            ((failed++))
            echo "   Progress: $success successful, $failed failed, $((success + failed)) of $TOTAL_COUNT processed"
            echo
            continue
        fi
        
        # Add 0x prefix if not present
        if [[ ! "$pubkey" =~ ^0x ]]; then
            pubkey="0x$pubkey"
        fi
        
        # Create exit message
        output_file="$OUT_DIR/${pubkey:0:12}--${pubkey:90}-exit.json"
        
        # Create exit message (with explicit error handling)
        "$ETHDO" validator exit \
            --offline \
            --json \
            --validator "$keyfile" \
            --passphrase "$password" > "$output_file" 2>&1
        exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            echo "✓ Created $(basename "$output_file")"
            ((success++))
            echo "   Progress: $success of $TOTAL_COUNT messages created"
        else
            echo "✗ Failed to create exit message (exit code: $exit_code):"
            cat "$output_file"
            # Remove the failed file to avoid confusion
            rm -f "$output_file"
            ((failed++))
            echo "   Progress: $success successful, $failed failed, $((success + failed)) of $TOTAL_COUNT processed"
        fi
        echo
    done
else
    # Process with mnemonic
    echo "Creating $TOTAL_COUNT exit messages from mnemonic (indices $START_INDEX-$END_INDEX)..."
    echo
    
    for ((i=START_INDEX; i<=END_INDEX; i++)); do
        ((current++))
        echo "Processing $current of $TOTAL_COUNT: validator index $i..."
        
        output_file="$OUT_DIR/validator-${i}-exit.json"
        
        # Create exit message from mnemonic
        if [ -z "$MNEMONIC_PASSPHRASE" ]; then
            "$ETHDO" validator exit \
                --offline \
                --json \
                --mnemonic "$MNEMONIC" \
                --path "m/12381/3600/$i/0/0" > "$output_file" 2>&1
        else
            "$ETHDO" validator exit \
                --offline \
                --json \
                --mnemonic "$MNEMONIC" \
                --passphrase "$MNEMONIC_PASSPHRASE" \
                --path "m/12381/3600/$i/0/0" > "$output_file" 2>&1
        fi
        exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            # Extract validator index from the exit message and rename file
            if command -v jq >/dev/null 2>&1; then
                validator_index=$(jq -r '.message.validator_index' "$output_file" 2>/dev/null)
            else
                # Fallback without jq - extract validator_index using grep and sed
                validator_index=$(grep -o '"validator_index":"[^"]*"' "$output_file" 2>/dev/null | sed 's/.*"validator_index":"\([^"]*\)".*/\1/')
            fi
            
            if [ "$validator_index" != "null" ] && [ -n "$validator_index" ]; then
                # Get public key using account derive
                if [ -z "$MNEMONIC_PASSPHRASE" ]; then
                    pubkey_full=$("$ETHDO" account derive --mnemonic "$MNEMONIC" --path "m/12381/3600/$i/0/0" 2>/dev/null | grep "Public key:" | cut -d' ' -f3)
                else
                    pubkey_full=$("$ETHDO" account derive --mnemonic "$MNEMONIC" --passphrase "$MNEMONIC_PASSPHRASE" --path "m/12381/3600/$i/0/0" 2>/dev/null | grep "Public key:" | cut -d' ' -f3)
                fi
                
                # Use same format as keystore method
                if [ -n "$pubkey_full" ] && [[ "$pubkey_full" =~ ^0x ]]; then
                    # Same format as keystore: first 12 chars -- last part
                    new_filename="$OUT_DIR/${pubkey_full:0:12}--${pubkey_full:90}-exit.json"
                else
                    new_filename="$OUT_DIR/${i}-${validator_index}-exit.json"
                fi
                mv "$output_file" "$new_filename"
                echo "✓ Created $(basename "$new_filename")"
                ((success++))
                echo "   Progress: $success of $TOTAL_COUNT messages created"
            else
                echo "✗ No validator found at index $i (validator doesn't exist)"
                rm -f "$output_file"
                ((failed++))
                echo "   Progress: $success successful, $failed failed, $((success + failed)) of $TOTAL_COUNT processed"
            fi
        else
            echo "✗ Failed to create exit message (exit code: $exit_code):"
            cat "$output_file"
            # Remove the failed file to avoid confusion
            rm -f "$output_file"
            ((failed++))
            echo "   Progress: $success successful, $failed failed, $((success + failed)) of $TOTAL_COUNT processed"
        fi
        echo
    done
fi

echo "Summary:"
echo "  ✓ Success: $success"
echo "  ✗ Failed:  $failed"
echo "  📁 Output: $OUT_DIR"