#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build/xiao_ble"
WEST="${PROJECT_DIR}/bin/west"

if [[ ! -x "${WEST}" ]]; then
    echo "west was not found at ${WEST}" >&2
    exit 1
fi

echo "==> Building XIAO BLE application..."
"${WEST}" build -b xiao_ble "${PROJECT_DIR}/app" -d "${BUILD_DIR}"

echo "==> Flashing through ST-Link/V2..."
"${WEST}" flash -d "${BUILD_DIR}" -r openocd \
    --config interface/stlink.cfg \
    --config target/nrf52.cfg \
    --cmd-pre-init 'transport select hla_swd' \
    --cmd-pre-init 'adapter speed 100' \
    --cmd-load 'flash write_image erase'

echo "==> Flash complete."