---
sidebar_label: Docker
---

# Serious Sam: The First Encounter Docker Container

This Docker container runs a Serious Sam: The First Encounter dedicated server. It is built on the WINE image and runs the retail game's `Bin/DedicatedServer.exe` (v1.05). The container doesn't download the game, so you provide the files.

## Quick Start

```yaml
services:
  serioussam:
    image: lancommander/serioussamthefirstencounter:latest
    container_name: serioussam

    ports:
      - 25600:25600/udp
      - 25601:25601/udp

    volumes:
      - "/data/Servers/Serious Sam - The First Encounter/Cooperative:/config"

    environment:
      SSAM_SESSION_NAME: "My Serious Sam Server"
      SSAM_GAME_MODE: "coop"
      SSAM_LEVELS: "01_Hatshepsut"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

Copy a Serious Sam: The First Encounter install patched to **1.05** (the folder with `Bin/DedicatedServer.exe`, `Levels/` and the `.gro` files) into `Server/` before the first start. You can instead set `SSAM_ARCHIVE_URL` to a zip of that folder.

A fragmatch on a rotation of campaign levels:

```yaml
    environment:
      SSAM_GAME_MODE: "fragmatch"
      SSAM_LEVELS: "08_Suburbs, 06_Oasis, 11_AlleyOfSphinxes"
      SSAM_FRAG_LIMIT: "20"
      SSAM_TIME_LIMIT: "15"
      SSAM_WEAPONS_STAY: "false"
      SSAM_CREDITS: ""
```

## How It Starts

1. `PostInitialization/10-InitializeWinePrefix.ps1` (from the WINE image) creates the Wine prefix in `/config/wineprefix`.
2. `PostInitialization/20-InstallSeriousSam.ps1` checks for `Server/Bin/DedicatedServer.exe`. If it's missing and `SSAM_ARCHIVE_URL` is set, the hook downloads and extracts the archive and remounts the overlay.
3. `PostInitialization/30-ConfigureSeriousSam.ps1` writes `Scripts/Dedicated/<SSAM_CONFIG>/` (default `LANCommander`): `init.ini` with the non-empty `SSAM_*` settings, and a `<n>_begin.ini` / `<n>_end.ini` pair for each `SSAM_LEVELS` entry. It writes through `Merged/`, so the files land in `Overlay/Scripts/Dedicated/`.
4. `START_EXE` (`/usr/local/bin/ssam-server`) runs `DedicatedServer.exe <SSAM_CONFIG> [<SSAM_MOD>]` from `Bin/` under Wine.

`DedicatedServer.exe` executes `Scripts/Dedicated_startup.ini`, then the config's `init.ini`, then `1_begin.ini`, and starts the level in `ded_strLevel`. When the round ends it runs `1_end.ini`, waits `ded_tmTimeout` seconds and goes on to `2_begin.ini`. After the last round it starts over at 1.

A successful start ends with:

```
Executing: 'Scripts\Dedicated\LANCommander\1_begin.ini'
...
  port: 25600
Starting session: 'Serious Sam Server'
  level: 'Levels\01_Hatshepsut.wld'
  ...
  network is on
```

The engine also logs to `Dedicated_<SSAM_CONFIG>.log` in the game root (in `Overlay/`).

## Configuration Options

### Ports

- **25600/udp**: Game and RCon (`SSAM_PORT`)
- **25601/udp**: GameSpy query (game port + 1). It answers `\status\` and `\info\`. It is only open while `ser_bHeartbeatGameSpy` is on (`SSAM_GAMESPY_HEARTBEAT`).

### Environment Variables

See the [README](../README.md#environment-variables) for the full table.

### Server config

The `Scripts/Dedicated/<SSAM_CONFIG>/` folder holds a `.lancommander` marker and is regenerated on every start. To maintain the config by hand, delete `.lancommander` from `Overlay/Scripts/Dedicated/<SSAM_CONFIG>/` (or point `SSAM_CONFIG` at a folder of your own, or one of the stock configs such as `DefaultCoop`); a folder without the marker is never touched.

For one-off settings, `SSAM_EXTRA_SETTINGS` appends raw console script to `init.ini`. Useful variables include `gam_bInfiniteAmmo`, `gam_bAmmoStays`, `gam_bHealthArmorStays`, `gam_bAllowHealth`, `gam_bAllowArmor`, `gam_bRespawnInPlace`, `gam_fExtraEnemyStrength`, `gam_fExtraEnemyStrengthPerPlayer`, `gam_tmSpawnInvulnerability`, `net_strObserverPassword`, `net_strVIPPassword`, `ser_strIPMask` and `ser_strNameMask`. `Help/ShellSymbols.txt` and `Help/notes.txt` in the game folder document them.

`Scripts/Dedicated_startup.ini` (the stock file, editable via `Overlay/`) runs before every config and sets low texture quality and `gam_strGameSpyExtras`.

### Remote administration

With `SSAM_ADMIN_PASSWORD` set, the game's `Bin/RCon.exe <server> 25600 "<password>"` administers the server over UDP. Clients connected to the server can also use the console's `Admin()` command. Dedicated-only commands: `Restart()` (back to round 1), `NextMap()`, `ListPlayers()`, `KickByName()`.

### Hooks

| Hook | When |
|------|------|
| `PreInstallSeriousSam` / `PostInstallSeriousSam` | Around the game file check/download |
| `PreInitializeWinePrefix` / `PostInitializeWinePrefix` | Around Wine prefix creation (WINE image) |

Put `.ps1` scripts in `config/Scripts/Hooks/<HookName>/`.

## Troubleshooting

- **Server not in the LAN browser**: the browser finds servers by UDP broadcast, so the container needs its own LAN address (macvlan/ipvlan) or host networking. Joining by IP works through port mapping. Also keep `SSAM_GAMESPY_HEARTBEAT` on: with `ser_bHeartbeatGameSpy=0` the server doesn't open the query port (25601) at all. Leaving it on is harmless offline; the master server heartbeats just go nowhere.
- **Settings ignored**: check `Overlay/Scripts/Dedicated/<SSAM_CONFIG>/init.ini`. If the folder has no `.lancommander` marker, the image doesn't write to it.
- **`Bin/DedicatedServer.exe not found`**: `Server/` must contain the game folder itself (`Server/Bin/DedicatedServer.exe`), not a folder that contains it.
- **Harmless startup messages**: `Cannot load game settings ... DedicatedServer.gms`, the joystick errors, ALSA errors, `Detected devices: 0` (sound) and the `127.12.34.56` local address.
