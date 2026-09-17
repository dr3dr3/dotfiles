# Logitech MX mice — button remaps on Linux

The MX Ergo S and MX Vertical are paired to the Omarchy host over Bluetooth.
Their Forward button (the front small button beside left-click on the Ergo S,
the upper thumb-rest button on the Vertical) sends **Enter**.

- Applied by: [`scripts/setup-logitech-mice-linux.sh`](../scripts/setup-logitech-mice-linux.sh)
- Fragments: [`config/keyd/mx-ergo-s.conf`](../config/keyd/mx-ergo-s.conf),
  [`config/keyd/mx-vertical.conf`](../config/keyd/mx-vertical.conf)
- Installed to `/etc/keyd/`, one file per mouse, next to the Herdr Caps Lock
  fragment. keyd requires each device id to appear in exactly one file.

> **Host-native on purpose.** keyd rewrites the button at the evdev layer, so
> Kitty, `devsh` and anything in the devcontainer just receive an ordinary Enter.
> Nothing to install container-side — the same shape as the Caps Lock remap in
> [HERDR.md](HERDR.md).

```bash
bash scripts/setup-logitech-mice-linux.sh
```

---

## Why keyd and not Solaar / logiops

Logitech has no Linux software; the usual replacements are Solaar (in
`extra/`, actively maintained) and logiops (AUR, last release 2024). Both work
by asking the mouse to *divert* a button — stop acting on it and instead send a
HID++ notification the daemon turns into a key.

Measured 2026-09-17 on both mice over Bluetooth: the divert command is accepted
(the button goes dead) but **no HID++ notification is ever sent**. Verified at
three layers — raw `/dev/hidrawN`, a subscription to the Logitech vendor GATT
characteristic, and `btmon`. So diversion-based tools cannot see these buttons
over BLE. They do over the Bolt receiver; this repo does not use one.

Solaar stays installed (`omarchy pkg add solaar`, autostarted from
`~/.config/hypr/autostart.lua`) for battery and DPI. Keep every button at
**Regular** in its Key/Button Diversion setting.

## Gotchas found the hard way

- **keyd key names.** Linux delivers HID mouse buttons 4/5 as
  `BTN_SIDE`/`BTN_EXTRA`, which keyd calls `mouse1`/`mouse2`. keyd's
  `mouseback`/`mouseforward` are `BTN_BACK`/`BTN_FORWARD`, which these mice never
  emit. Bind `mouse2`.
- **The precision/DPI button** is handled inside the mouse and never reaches
  the host; it cannot be remapped from Linux.
- **Solaar re-pushes saved diversions** when a mouse reconnects. If a button
  goes dead, check `solaar config "MX Vertical" divert-keys`; to clear it, stop
  Solaar, set the button to Regular, confirm `86: 0` in
  `~/.config/solaar/config.yaml`, then start Solaar again.
- **Use `systemctl restart keyd`, not `keyd reload`**, and confirm in
  `journalctl -u keyd` that the fragment was parsed and the mouse matched
  (`DEVICE: match 046d:b03e … mx-ergo-s.conf`). `sudo keyd monitor` shows what
  keyd receives and emits per press.
- keyd's man page marks mouse support experimental. If the trackball or
  scrolling misbehaves, remove the fragment from `/etc/keyd/` and restart keyd.
