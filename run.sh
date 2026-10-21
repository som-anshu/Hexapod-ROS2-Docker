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
#      ./run.sh                 # launch the Gazebo simulation
#      ./run.sh shell           # plain interactive shell, no simulation
#      ./run.sh <command...>    # run a single command and exit
#
#  The simulation and the gait algorithms are two different programs, so they
#  need two terminals:
#      terminal 1:  ./run.sh
#      terminal 2:  ./run.sh shell   ->  ros2 run hex_gz tri_gate.py
# =============================================================================
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-hexapod-ros2:jazzy}"
BASE_NAME="${CONTAINER_NAME:-hexapod-ros2}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_SRC="${REPO_ROOT}/sim_and_real/ros2_ws_hex/src"

BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
info() { printf '%s[+]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s[!]%s %s\n' "$YELLOW" "$RESET" "$*"; }

# --- 0. mode ---------------------------------------------------------------
#   sim  - launch the Gazebo simulation (default)
#   shell - plain interactive shell, for driving the robot from a 2nd terminal
#   anything else is run as a command inside the container
#
# Each mode gets its own container name, otherwise starting the shell would
# remove the container that is running the simulation.
MODE="sim"
CONTAINER_NAME="${BASE_NAME}"
if [ "$#" -gt 0 ]; then
    if [ "$1" = "shell" ]; then
        MODE="shell"
        CONTAINER_NAME="${BASE_NAME}-shell"
        shift
    else
        MODE="command"
        CONTAINER_NAME="${BASE_NAME}-run"
    fi
fi

# --- 1. image present? ------------------------------------------------------
if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
    echo "Image '${IMAGE_NAME}' not found. Run ./install.sh first." >&2
    exit 1
fi

# --- 2. replace a stale container of the same name ---------------------------
if docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
    info "Removing the previous '${CONTAINER_NAME}' container"
    docker rm --force "${CONTAINER_NAME}" >/dev/null
fi

ARGS=(
    run --rm --interactive
    --name "${CONTAINER_NAME}"
    --network host
    --ipc host
    --shm-size 2g
    --cap-add SYS_NICE
    --ulimit rtprio=99
    --ulimit rttime=-1
    --ulimit memlock=-1
)

# Only request a TTY when we are actually running on one, otherwise
# "docker run" refuses to start.
[ -t 0 ] && ARGS+=(--tty)

# --- 2. GPU (optional, NVIDIA only) -----------------------------------------
if docker info 2>/dev/null | grep -qi nvidia; then
    info "NVIDIA GPU detected - enabling GPU passthrough"
    ARGS+=(--gpus all --env "NVIDIA_DRIVER_CAPABILITIES=graphics,compute,utility")
    ARGS+=(--env "NVIDIA_VISIBLE_DEVICES=all")

    # The NVIDIA runtime maps the host's device groups into the container.
    # Without the matching entries in the container's /etc/group it complains
    # "groups: cannot find name for group ID 990".
    for grp in video render; do
        gid="$(getent group "${grp}" 2>/dev/null | cut -d: -f3)"
        [ -n "${gid}" ] && ARGS+=(--group-add "${gid}")
    done
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

    # The X server needs the right access cookie. Under XWayland that cookie
    # lives in $XAUTHORITY, which has to be mounted *and* pointed at, or Qt
    # fails with "no Qt platform plugin could be initialized".
    if [ -n "${XAUTHORITY:-}" ] && [ -r "${XAUTHORITY}" ]; then
        ARGS+=(--volume "${XAUTHORITY}:${XAUTHORITY}:ro")
        ARGS+=(--env "XAUTHORITY=${XAUTHORITY}")
    else
        # No cookie available: let local clients (i.e. this container) in.
        if command -v xhost >/dev/null 2>&1; then
            xhost +local: >/dev/null 2>&1 \
                && info "X11: no XAUTHORITY found, allowed local connections with 'xhost +local:'"
        fi
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

# --- 7. command -------------------------------------------------------------
# The image name must come before the command, so it is appended last.
case "${MODE}" in
    sim)
        info "Starting '${CONTAINER_NAME}' with the Gazebo simulation"
        info "In a second terminal use './run.sh shell' to drive the robot"
        exec docker "${ARGS[@]}" "${IMAGE_NAME}" \
            ros2 launch hex_gz gazebo.launch.py
        ;;
    shell)
        if [ "$#" -eq 0 ]; then
            info "Starting '${CONTAINER_NAME}' with a plain shell"
            exec docker "${ARGS[@]}" "${IMAGE_NAME}" bash
        fi
        info "Starting '${CONTAINER_NAME}'"
        exec docker "${ARGS[@]}" "${IMAGE_NAME}" "$@"
        ;;
    *)
        info "Starting '${CONTAINER_NAME}'"
        exec docker "${ARGS[@]}" "${IMAGE_NAME}" "$@"
        ;;
esac
