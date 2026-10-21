#!/usr/bin/env bash
# =============================================================================
#  Container entrypoint for the Hexapod ROS 2 workspace.
#
#  Sources the ROS 2 + workspace environment, picks a display, then hands
#  control to the command passed on the docker run / compose "command:" line.
# =============================================================================
set -eo pipefail

# NOTE: "set -u" is deliberately NOT used. The ROS 2 setup scripts reference
# unset variables (AMENT_TRACE_SETUP_FILES, COLCON_TRACE, ...) and abort under
# "nounset". /etc/hexapod/ros2_env.sh handles that case for its own callers.

WORKSPACE="${WORKSPACE:-/opt/hexapod_ws}"
export WORKSPACE

# --- ROS 2 + workspace ------------------------------------------------------
# Shared with .bashrc, /etc/profile.d/ros2.sh and $BASH_ENV, so every kind of
# shell in the container ends up with the same environment.
if [ -f /etc/hexapod/ros2_env.sh ]; then
    . /etc/hexapod/ros2_env.sh
else
    source "/opt/ros/${ROS_DISTRO:-jazzy}/setup.bash"
    [ -f "${WORKSPACE}/install/setup.bash" ] && source "${WORKSPACE}/install/setup.bash"
fi

# Qt/Gazebo GUI inside a container: X11 through XWayland, no MIT-SHM.
export QT_X11_NO_MITSHM=1
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"

# --- virtual framebuffer ----------------------------------------------------
# Several hex_gz scripts call matplotlib.use('TkAgg'), and Gazebo needs a
# display to render at all. If the host display is not reachable from inside
# the container, start a virtual one so the scripts still run.
#
# The image sets DISPLAY=:99 by default, and run.sh overrides it with the
# host's display, so "docker exec" sessions find the same one.
VIRTUAL_DISPLAY=":99"

display_reachable() {
    [ -n "${DISPLAY:-}" ] || return 1
    local spec="${DISPLAY##*:}"   # drop "host:" prefix
    local num="${spec%%.*}"       # drop ".0" screen suffix
    [ -e "/tmp/.X11-unix/X${num}" ]
}

if ! display_reachable; then
    if [ ! -e "/tmp/.X${VIRTUAL_DISPLAY#:}-lock" ]; then
        Xvfb "${VIRTUAL_DISPLAY}" -screen 0 1280x1024x24 >/tmp/xvfb.log 2>&1 &
        sleep 1
    fi
    export DISPLAY="${VIRTUAL_DISPLAY}"
    echo "entrypoint: no host display reachable, using virtual display ${DISPLAY}"
fi

# Record the display for shells started later in the container.
mkdir -p /etc/hexapod
printf "export DISPLAY='%s'\n" "${DISPLAY}" > /etc/hexapod/display.sh

# The workspace is the current directory.
cd "${WORKSPACE}"

if [ "$#" -eq 0 ]; then
    exec bash
fi

exec "$@"
