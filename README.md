# Serious Sam: The First Encounter Server (Docker)

This repository provides a Dockerized **Serious Sam: The First Encounter** dedicated server. The game (Croteam, 2001) only ships a Windows dedicated server, so the image runs the retail `Bin/DedicatedServer.exe` (v1.05) under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers.WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs the retail game's `DedicatedServer.exe` (a console program; no display or Xvfb needed)
- The dedicated server config (`Scripts/Dedicated/LANCommander/`) is generated from environment variables, including a level rotation
- Cooperative, scorematch and fragmatch
- The server console goes to `docker logs`
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  serioussam:
    image: lancommander/serioussamthefirstencounter:latest
    container_name: serioussam

    ports:
      - "25600:25600/udp"
      - "25601:25601/udp"

    volumes:
      - ./config:/config

    environment:
      SSAM_SESSION_NAME: "My Serious Sam Server"
      SSAM_GAME_MODE: "coop"
      SSAM_LEVELS: "01_Hatshepsut"
      SSAM_DIFFICULTY: "normal"
      SSAM_MAX_PLAYERS: "8"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The in-game LAN browser finds servers by broadcast. That needs the container on the LAN itself (macvlan/ipvlan, or `network_mode: host`); with port mapping, clients join by IP.

---

## Game Files

Serious Sam: The First Encounter is retail software with no public download. You must provide an install patched to **1.05**, such as the GOG release (the 2009 HD remake is a different game). Clients must run the same version:

- copy the game folder (the one containing `Bin/`, `Levels/` and the `.gro` files) to `config/Server/`, **or**
- set `SSAM_ARCHIVE_URL` to a zip of that folder, e.g. a LANCommander archive. It is downloaded and extracted on first start, if `Server/Bin/DedicatedServer.exe` doesn't exist yet.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Serious Sam install (Bin/, Levels/, *.gro ...)
    ├── Overlay/           # Your files, layered on top of Server/ (the generated config and logs land here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers.WINE#environment).
The settings are written to `Scripts/Dedicated/<SSAM_CONFIG>/init.ini` on every start. Settings left empty are left out, so the game's defaults apply.

| Variable | Description | Default |
|----------|-------------|---------|
| `SSAM_CONFIG` | Dedicated server config folder in `Scripts/Dedicated/`, passed to `DedicatedServer.exe` | `LANCommander` |
| `SSAM_MOD` | Mod folder in `Mods/`, passed as the second argument | |
| `SSAM_PORT` | Game port, `net_iPort`. The GameSpy query port is this + 1 | `25600` |
| `SSAM_SESSION_NAME` | Server name, `gam_strSessionName` | `Serious Sam Server` |
| `SSAM_GAME_MODE` | `coop`, `scorematch` or `fragmatch` (`gam_iStartMode`) | `coop` |
| `SSAM_LEVELS` | Comma-separated level rotation, one round per level (see below) | `01_Hatshepsut` |
| `SSAM_DIFFICULTY` | `tourist`, `easy`, `normal`, `hard` or `serious` (`gam_iStartDifficulty`) | `normal` |
| `SSAM_MAX_PLAYERS` | `gam_ctMaxPlayers` | `8` |
| `SSAM_WAIT_ALL_PLAYERS` | Wait for all players before starting, `gam_bWaitAllPlayers` | `false` |
| `SSAM_CREDITS` | Respawn credits in coop, `-1` = infinite (`gam_iCredits`) | `-1` |
| `SSAM_WEAPONS_STAY` | `gam_bWeaponsStay` | `true` |
| `SSAM_FRIENDLY_FIRE` | `gam_bFriendlyFire` | |
| `SSAM_TIME_LIMIT` | Minutes, `0` = none (`gam_iTimeLimit`) | |
| `SSAM_FRAG_LIMIT` | Fragmatch frag limit (`gam_iFragLimit`) | |
| `SSAM_SCORE_LIMIT` | Scorematch score limit (`gam_iScoreLimit`) | |
| `SSAM_PASSWORD` | Join password, `net_strConnectPassword` | |
| `SSAM_ADMIN_PASSWORD` | Remote admin / RCon password, `net_strAdminPassword` | |
| `SSAM_MOTD` | Message of the day, `ser_strMOTD` | |
| `SSAM_LEVEL_TIMEOUT` | Seconds between the end of a round and the next level, `ded_tmTimeout` | `20` |
| `SSAM_WAIT_FIRST_PLAYER` | Keep the game paused until the first player joins, `ser_bWaitFirstPlayer` | `true` |
| `SSAM_GAMESPY_HEARTBEAT` | `ser_bHeartbeatGameSpy`. Also opens the query port, so leave it on (see Troubleshooting) | `true` |
| `SSAM_EXTRA_SETTINGS` | Raw console script lines appended to `init.ini`, e.g. `gam_bInfiniteAmmo = 1; gam_fExtraEnemyStrength = 0.5;` | |
| `SSAM_ARCHIVE_URL` | Zip of the game folder, used if `Server/Bin/DedicatedServer.exe` is missing | |
| `WINE_XVFB` | The server is a console program and needs no display | `false` |
| `START_EXE` | Launcher | `/usr/local/bin/ssam-server` |
| `START_ARGS` | Appended to the `DedicatedServer.exe` command line | |

### Levels

`SSAM_LEVELS` entries are level names in `Levels/` (`01_Hatshepsut`) or paths relative to the game root (`Levels/08_Suburbs.wld`). The retail levels are `01_Hatshepsut`, `02_SandCanyon`, `03_TombOfRamses`, `04_ValleyOfTheKings`, `05_MoonMountains`, `06_Oasis`, `07_Dunes`, `08_Suburbs`, `09_Sewers`, `10_Metropolis`, `11_AlleyOfSphinxes`, `12_Karnak`, `13_Luxor`, `14_SacredYards`, `15_TheGreatPyramid` and `KarnakDemo`. The First Encounter 1.05 has no dedicated deathmatch maps, so scorematch and fragmatch run on campaign levels.

In coop, the game moves on to the next campaign level by itself, so one start level is usually enough. When the round ends (the last level is finished, or a limit is hit in versus modes), the server goes on to the next `SSAM_LEVELS` entry, and after the last one it starts over.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/serioussamthefirstencounter:local .
```

---

## License

Serious Sam: The First Encounter and Wine are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
