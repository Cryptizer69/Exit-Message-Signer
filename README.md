# Exit Message Signer for Tails

Create validator exit messages securely on Tails Live USB using keystores or mnemonic phrases.

## What You Need

- 2 USB drives (8GB+ each): Tails Live USB + transfer drive
- Validator keystores OR mnemonic phrase
- Computer that can boot from USB

```
╔═══════════════════════════════════════════════════════════════╗
║                           STEP 1                              ║
║                   Offline Preparation Files                   ║
╚═══════════════════════════════════════════════════════════════╝
```

Choose one option for validator state data:

### Option A: Download from EthStaker
1. Visit https://files.ethstaker.cc/
2. Download the appropriate network file:
   - `offline-preparation-mainnet.json` for mainnet
   - `offline-preparation-hoodi.json` for hoodi testnet
3. Place the file in your Exit-Message-Signer folder

### Option B: Create Your Own
On a machine with internet connection:
1. Navigate to Exit-Message-Signer folder
2. Run: `./create-offline-prep.sh`
3. Enter beacon node URL (e.g., `https://mainnet.beacon-api.nimbus.team` or `localhost:5052`)
4. For local nodes, select your network when prompted
5. File will be created as `offline-preparation-{network}.json`

```
╔═══════════════════════════════════════════════════════════════╗
║                           STEP 2                              ║
║                     Prepare Transfer USB                      ║
╚═══════════════════════════════════════════════════════════════╝
```

1. Download tool from: https://github.com/Cryptizer69/Exit-Message-Signer
2. Format USB as FAT32
3. Copy Exit-Message-Signer folder to USB

```
╔═══════════════════════════════════════════════════════════════╗
║                           STEP 3                              ║
║               Create Exit Messages on Tails                   ║
╚═══════════════════════════════════════════════════════════════╝
```

1. Boot Tails Live USB
2. Insert transfer USB and copy Exit-Message-Signer folder to `/home/amnesia/`
3. Open terminal in the folder
4. If using keystores: Copy your keystore-*.json files to `keystores/` folder
5. Run the script:

```bash
chmod +x ethdo exit-message-maker.sh
./exit-message-maker.sh
```

6. Choose method (keystores or mnemonic) and network
7. Exit messages will be created in `exit-messages/` folder

```
╔═══════════════════════════════════════════════════════════════╗
║                           STEP 4                              ║
║                     Store Exit Messages                       ║
╚═══════════════════════════════════════════════════════════════╝
```

1. Copy `exit-messages/` folder to secure storage:
   - Tails persistent volume (encrypted, survives reboots)
   - Separate encrypted USB drive

2. After copying, wipe the transfer USB to prevent data recovery:
```bash
sudo dd if=/dev/zero of=/dev/sdX bs=1M status=progress
```

```
╔═══════════════════════════════════════════════════════════════╗
║                           STEP 5                              ║
║                   Broadcast Exit Messages                     ║
╚═══════════════════════════════════════════════════════════════╝
```

Upload your exit messages to:
- **Mainnet**: https://beaconcha.in/tools/broadcast
- **Hoodi Testnet**: https://hoodi.beaconcha.in/tools/broadcast

After broadcasting, validators will exit through the queue (see progress at https://www.validatorqueue.com/). When your validators have been launched using a protocol such as Rocket Pool, additional actions may be necessary before you can access your funds.

## Advanced Options

### USB Formatting Commands

**Linux/macOS:**
```bash
sudo fdisk /dev/sdX  # o → n → p → 1 → Enter → Enter → t → c → w
sudo mkfs.fat -F32 /dev/sdX1
sudo mount /dev/sdX1 /mnt/usb
sudo cp -r Exit-Message-Signer /mnt/usb/
sudo umount /mnt/usb
```

**Windows:** Format USB to FAT32 in Disk Management, copy folder, eject

### Multiple Keystore Passwords
If keystores have different passwords, process in batches:
1. Add first batch → run script → `rm keystores/*.json`
2. Add second batch → run script → repeat

