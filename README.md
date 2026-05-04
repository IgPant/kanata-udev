# kanata-udev

Automatically start/stop [kanata](https://github.com/jtroo/kanata) when a USB keyboard is connected or disconnected, using udev rules.

## How it works

- **Keyboard disconnected** → kanata starts, remapping the built-in laptop keyboard
- **Keyboard connected** → kanata stops, since the external keyboard has its own layout

This uses udev rules to detect USB add/remove events and `systemd-run` to launch kanata in its own systemd unit so it survives udev's process cleanup.

## Setup

1. Place your `kanata` binary and `kanata.kbd` config in this directory (or note their paths)
2. Run the installer:

```bash
./install.sh
```

The installer will:
- Ask for each keyboard's USB vendor/product ID (you can add multiple)
- Ask for the kanata binary and config paths
- Generate `udev-kanata-start.sh` and `udev-kanata-stop.sh` in `~/.local/bin/`
- Install a udev rule to `/etc/udev/rules.d/90-kanata-keyboard.rules`

## Finding your keyboard's USB ID

```bash
lsusb
```

Look for your keyboard in the list. The ID is in the format `vendor:product` (e.g. `5262:4e4b`).

## Files

| File | Description |
|------|-------------|
| `install.sh` | Interactive installer — generates scripts and udev rules |
| `udev-kanata-start.sh` | Reference copy of the start script |
| `udev-kanata-stop.sh` | Reference copy of the stop script |

## Requirements

- Linux with udev
- [kanata](https://github.com/jtroo/kanata)
- `pkexec` (polkit) for installing the udev rule
- `systemd-run` for process management
