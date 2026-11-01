# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a Serious Sam: The First Encounter 1.05 install in
#     /config/Server, or set SSAM_ARCHIVE_URL to a zip of one
#   - Scripts/Dedicated/<SSAM_CONFIG>/ is generated from the SSAM_* settings on every start
#     (empty settings are left out, so the game's defaults apply)
#   - DedicatedServer.exe is a console program, so no Xvfb is needed
# ----------------------------
ENV SSAM_ARCHIVE_URL="" \
    SSAM_CONFIG="LANCommander" \
    SSAM_MOD="" \
    SSAM_PORT="25600" \
    SSAM_SESSION_NAME="Serious Sam Server" \
    SSAM_GAME_MODE="coop" \
    SSAM_LEVELS="01_Hatshepsut" \
    SSAM_DIFFICULTY="normal" \
    SSAM_MAX_PLAYERS="8" \
    SSAM_WAIT_ALL_PLAYERS="false" \
    SSAM_CREDITS="-1" \
    SSAM_WEAPONS_STAY="true" \
    SSAM_FRIENDLY_FIRE="" \
    SSAM_TIME_LIMIT="" \
    SSAM_FRAG_LIMIT="" \
    SSAM_SCORE_LIMIT="" \
    SSAM_PASSWORD="" \
    SSAM_ADMIN_PASSWORD="" \
    SSAM_MOTD="" \
    SSAM_LEVEL_TIMEOUT="20" \
    SSAM_WAIT_FIRST_PLAYER="true" \
    SSAM_GAMESPY_HEARTBEAT="true" \
    SSAM_EXTRA_SETTINGS="" \
    WINE_XVFB="false" \
    START_EXE="/usr/local/bin/ssam-server" \
    START_ARGS=""

COPY Scripts/ssam-server /usr/local/bin/ssam-server
RUN chmod +x /usr/local/bin/ssam-server

COPY Hooks/ "${BASE_HOOKS}/"

# 25600/udp: game and RCon (SSAM_PORT). 25601/udp: GameSpy query and LAN browser (game port + 1).
EXPOSE 25600/udp 25601/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
