#!/usr/bin/env bash
# =============================================================================
#  Hexapod ROS 2 System - installer
#
#  Builds the ROS 2 Jazzy + Gazebo Harmonic container image that contains the
#  hexapod workspace, already compiled.
#
#  Usage:
#      ./install.sh
#
#  Afterwards start the robot with:
#      ./run.sh
# =============================================================================
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-hexapod-ros2:jazzy}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BOLD=$'\033[1m'; GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'

info() { printf '%s[+]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s[!]%s %s\n' "$YELLOW" "$RESET" "$*"; }
die()  { printf '%s[x]%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

printf '\n%sHexapod ROS 2 System - container setup%s\n' "$BOLD" "$RESET"
printf '%sROS 2 Jazzy + Gazebo Harmonic%s\n\n' "$BOLD" "$RESET"

# --- 1. sanity checks -------------------------------------------------------
command -v docker >/dev/null 2>&1 \
    || die "Docker is not installed. Install it from https://docs.docker.com/engine/install/ and re-run."

if ! docker info >/dev/null 2>&1; then
    die "The Docker daemon is not running. Start it (e.g. 'sudo systemctl start docker') and re-run."
fi

info "Docker is available: $(docker --version)"

# --- 2. build the image -----------------------------------------------------
info "Building image '$IMAGE_NAME' (this takes a while the first time)..."
if ! docker build \
        --file "${REPO_ROOT}/docker/Dockerfile" \
        --tag "${IMAGE_NAME}" \
        "${REPO_ROOT}"; then
    die "Image build failed. Scroll up for the first error message."
fi

info "Image '$IMAGE_NAME' is ready."

# --- 3. next steps ----------------------------------------------------------
cat <<EOF

${GREEN}${BOLD}Setup complete.${RESET}

Start the container with the Gazebo GUI:

    ${BOLD}./run.sh${RESET}

Then, inside the container, launch the simulation:

    ${BOLD}ros2 launch hex_gz gazebo.launch.py${RESET}

${YELLOW}Tip:${RESET} the workspace source is mounted from
'${REPO_ROOT}/sim_and_real/ros2_ws_hex/src', so you can edit the code on
your host and rebuild inside the container with:

    ${BOLD}colcon build --symlink-install --packages-select <package>${RESET}

EOF
