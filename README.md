# Zephyr Training Environment

Welcome to the Zephyr RTOS training! This repository includes a ready-to-use
development environment based on Zephyr 4.3.0, which you can set up in one of
three ways:

---

## Manual Zephyr Setup

Follow the following guide:
- [Getting Started Guide](https://docs.zephyrproject.org/latest/develop/getting_started/index.html#).

Make sure to select appropriate OS and to perform all steps till
[Build the Blinky Sample](https://docs.zephyrproject.org/latest/develop/getting_started/index.html#build-the-blinky-sample).

## Flashing a XIAO BLE with ST-Link/V2

The XIAO BLE uses the `xiao_ble` board target. With an ST-Link/V2 connected to
the SWD pins and the board powered, run:

```sh
./flash_stlink.sh
```

The script uses OpenOCD at a conservative SWD speed and erases only the
application image sectors; it does not mass-erase the device or remove the
factory bootloader.

### Manual ST-Link flashing

Use this workflow when you want to inspect or change each build and flash
step. The ST-Link must be connected to the XIAO BLE's `SWDIO`, `SWCLK`,
`GND`, and `3V3` pins. The board must be powered while flashing.

First build the application:

```sh
./bin/west build -b xiao_ble app -d build/xiao_ble
```

Then flash it through the ST-Link:

```sh
./bin/west flash -d build/xiao_ble -r openocd \
  --config interface/stlink.cfg \
  --config target/nrf52.cfg \
  --cmd-pre-init 'transport select hla_swd' \
  --cmd-pre-init 'adapter speed 100' \
  --cmd-load 'flash write_image erase'
```

The options have these roles:

- `-b xiao_ble` selects the XIAO BLE board definition and nRF52840
  devicetree configuration.
- `-d build/xiao_ble` selects the build directory and its generated HEX file.
- `-r openocd` selects OpenOCD instead of the board's default Nordic runner.
- The two `--config` options select the ST-Link interface and nRF52 target
  configuration.
- `transport select hla_swd` selects SWD through the ST-Link's high-level
  adapter interface.
- `adapter speed 100` uses a conservative 100 kHz clock. This is slower than
  the usual setting but is more reliable with an ST-Link/V2 and short jumper
  wires.
- `flash write_image erase` erases the sectors needed by the application and
  writes the generated HEX file. It does not perform an nRF52 mass erase.

Do not use `west flash -r openocd` without the explicit configurations above:
the XIAO BLE board definition does not select the ST-Link interface by default.
Also do not use an nRF52 recover or mass-erase operation with this ST-Link.
ST-Link/V2 cannot access the nRF52 CTRL-AP recovery interface, and erasing the
whole device can remove the factory bootloader. If the target is protected or
the application sectors cannot be erased, use the XIAO BLE's UF2 bootloader or
a Nordic-compatible programmer for recovery.
