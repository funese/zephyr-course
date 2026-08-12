#!/usr/bin/env bash
#
# flash_xiao.sh — Flash a Seeed XIAO nRF52840 (Sense) over UF2 from WSL.
#
# Prereqs (one-time, on Windows PowerShell as Admin):
#   winget install usbipd
#
# Each session, BEFORE running this script:
#   1. Double-tap the board's reset button to enter UF2 bootloader mode.
#   2. In Windows PowerShell (Admin):
#        usbipd list
#        usbipd bind --busid <BUSID>      # only needed once per device
#        usbipd attach --wsl --busid <BUSID>
#
# Usage (from your Zephyr project's zephyr/ dir, or pass the path):
#   ./flash_xiao.sh [path/to/zephyr/west/workspace]

set -euo pipefail

ZEPHYR_DIR="${1:-$PWD}"
MOUNT_NAME="XIAO-SENSE"
MOUNT_POINT="/media/${USER}/${MOUNT_NAME}"
EXPECTED_SIZE_MB=32   # approx size of the UF2 bootloader "drive"

echo "==> Looking for the XIAO UF2 device..."

# Find an unmounted disk close to the expected UF2 drive size.
DEVICE=""
while read -r name size mountpoint; do
    # size like "32.1M" -> strip trailing letter, compare loosely
    size_num="${size%[MG]}"
    if [[ -z "$mountpoint" ]] && [[ "$size" == *M ]]; then
        # accept anything within ~10MB of expected size
        diff=$(awk -v a="$size_num" -v b="$EXPECTED_SIZE_MB" 'BEGIN{d=a-b; if (d<0) d=-d; print d}')
        if awk -v d="$diff" 'BEGIN{exit !(d<10)}'; then
            DEVICE="/dev/${name}"
            break
        fi
    fi
done < <(lsblk -rno NAME,SIZE,MOUNTPOINT,TYPE | awk '$4=="disk"{print $1, $2, $3}')

if [[ -z "$DEVICE" ]]; then
    echo "!! Could not auto-detect the UF2 device."
    echo "   Run 'lsblk' yourself, find the ~${EXPECTED_SIZE_MB}M unmounted disk,"
    echo "   and mount it manually:"
    echo "     sudo mkdir -p ${MOUNT_POINT}"
    echo "     sudo mount -o uid=\$(id -u),gid=\$(id -g) /dev/sdX ${MOUNT_POINT}"
    exit 1
fi

echo "==> Found device: ${DEVICE}"

# Some boards expose a partition (sdX1) rather than the raw disk.
if [[ -b "${DEVICE}1" ]]; then
    DEVICE="${DEVICE}1"
    echo "==> Using partition: ${DEVICE}"
fi

echo "==> Mounting ${DEVICE} at ${MOUNT_POINT} with your user permissions..."
sudo mkdir -p "${MOUNT_POINT}"
sudo mount -o "uid=$(id -u),gid=$(id -g)" "${DEVICE}" "${MOUNT_POINT}"

if [[ ! -f "${MOUNT_POINT}/INFO_UF2.TXT" ]]; then
    echo "!! ${MOUNT_POINT} doesn't look like a UF2 bootloader drive (no INFO_UF2.TXT)."
    echo "   Contents:"
    ls -la "${MOUNT_POINT}"
    sudo umount "${MOUNT_POINT}"
    exit 1
fi

echo "==> Mounted successfully:"
cat "${MOUNT_POINT}/INFO_UF2.TXT"

echo "==> Flashing from ${ZEPHYR_DIR}..."
cd "${ZEPHYR_DIR}"
west flash --runner uf2

echo "==> Flash complete. Cleaning up mount (board should reboot on its own)..."
sleep 1
if mountpoint -q "${MOUNT_POINT}"; then
    sudo umount "${MOUNT_POINT}" 2>/dev/null || true
fi

echo "==> Done."
