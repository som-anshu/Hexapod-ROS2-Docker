#!/usr/bin/env bash
# =============================================================================
#  Hexapod ROS 2 System - container launcher
#
#  Starts the prebuilt container with:
#    * host networking   -> ROS 2 DDS discovery works between nodes
#    * X11 / XWayland   -> Gazebo and RViz windows appear on your desktop
#    * serial devices    -> ESP32 hardware interface (/dev/ttyUSB*, /dev/ttyACM*)
#    * the workspace src -> live editing from your host
#
#  Usage:
#      ./run.sh                 # interactive shell
#      ./run.sh <command...>    # run a single command and exit
# =============================================================================
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-hexapod-ros2:jazzy}"
CONTAINER_NAME="${CONTAINER_NAME:-hexapod-ros2}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SRC="${REPO_ROOT}/sim_and_real/ros2_ws_hex/src"

BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
info() { printf '%s[+]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%[!]%s %s\n' "$YELLOW" "$RESET" "$*"; }

# --- 0. image present? ------------------------------------------------------
if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
    echo "Image '${IMAGE_NAME}' not found. Run ./install.sh first." >&2
    exit 1
fi

# --- 1. replace a stale container -------------------------------------------
if docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
    info "Removing the previous '${CONTAINER_NAME}' container"
    docker rm --force "${CONTAINER_NAME}" >/dev/null
fi

ARGS=(
    run --rm --interactive --tty
    --name "${CONTAINER_NAME}"
    --network host
    --ipc host
    --shm-size 2g
    --cap-add SYS_NICE
    --ulimit rtprio=99
    --ulimit rttime=-1
    --ulimit memlock=-1
)

# --- 2. GPU (optional, NVIDIA only) -----------------------------------------
if docker info 2>/dev/null | grep -qi nvidia; then
    info "NVIDIA GPU detected - enabling GPU passthrough"
    ARGS+=(--gpus all --env "NVIDIA_DRIVER_CAPABILITIES=graphics,compute,utility")
    ARGS+=(--env "NVIDIA_VISIBLE_DEVICES=all")
else
    warn "No NVIDIA GPU detected - Gazebo will use software rendering (slower)"
    ARGS+=(--env "LIBGL_ALWAYS_SOFTWARE=1")
fi

# --- 3. GUI: X11 through XWayland, or XWayland fallback ------------------------
GUI_OK=0
if [ -n "${DISPLAY:-}" ] && [ -d /tmp/.X11-unix ]; then
    ARGS+=(--env "DISPLAY=${DISPLAY}")
    ARGS+=(--volume "/tmp/.X11-unix:/tmp/.X11-unix:rw")
    ARGS+=(--env "QT_X11_NO_MITSHM=1")
    ARGS+=(--env "QT_QPA_PLATFORM=xcb")
    if [ -n "${XAUTHORITY:-}" ] && [ -f "${XAUTHORITY}" ]; then
        ARGS+=(--volume "${XAUTHORITY}:${XAUTHORITY}:rw")
    fi
    GUI_OK=1
fi

if [ "${GUI_OK}" -eq 0 ]; then
    warn "No X display found - running headless (Gazebo will not show a window)."
    warn "On a headless machine, forward X11 with: ssh -X user@host, or use"
    warn "the docker-compose.yml file, which can start Xvfb for you."
    ARGS+=(--env "LIBGL_ALWAYS_SOFTWARE=1")
fi

# --- 4. ESP32 serial device (optional) --------------------------------------
PORT_FOUND=""
for dev in /dev/ttyUSB* /dev/ttyACM*; do
    if [ -e "${dev}" ]; then
        PORT_FOUND="${dev}"
        break
    fi
done
if [ -n "${PORT_FOUND}" ]; then
    info "ESP32 serial device found: ${PORT_FOUND}"
    ARGS+=(--device "${PORT_FOUND}:${PORT_FOUND}")
else
    warn "No ESP32 serial device (/dev/ttyUSB* or /dev/ttyACM*) found."
    warn "Simulation still works; hardware mode needs the device passed in."
fi

# --- 5. live-editable workspace ---------------------------------------------
ARGS+=(--volume "${WS_SRC}:/opt/hexapod_ws/src")
ARGS+=(--workdir /opt/hexapod_ws)

# --- 6. command -------------------------------------------------------------
if [ "$#" -gt 0 ]; then
    ARGS+=("$@")
else
    ARGS+=(bash)
fi

info "Starting '${CONTAINER_NAME}'"
exec docker "${ARGS[@]}" "${IMAGE_NAME}"
