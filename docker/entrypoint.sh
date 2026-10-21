#!/usr/bin/env bash
# =============================================================================
#  Container entrypoint for the Hexapod ROS 2 workspace.
#
#  Sources ROS 2 and the hexapod overlay workspace, then hands control to the
#  command passed on the docker run / compose "command:" line.
# =============================================================================
set -eo pipefail

# NOTE: "set -u" is deliberately NOT used. The ROS 2 setup scripts reference
# unset variables (AMENT_TRACE_SETUP_FILES, COLCON_TRACE, ...) and abort under
# "nounset".

ROS_DISTRO="${ROS_DISTRO:-jazzy}"
WORKSPACE="${WORKSPACE:-/opt/hexapod_ws}"

# --- ROS 2 ------------------------------------------------------------------
source "/opt/ros/${ROS_DISTRO}/setup.bash"

# --- hexapod workspace overlay ----------------------------------------------
if [ -f "${WORKSPACE}/install/setup.bash" ]; then
    source "${WORKSPACE}/install/setup.bash"
elif [ -f "${WORKSPACE}/install/local_setup.bash" ]; then
    source "${WORKSPACE}/install/local_setup.bash"
fi

# --- Gazebo / GPU friendly defaults -----------------------------------------
# Gazebo Harmonic (gz sim) reads these; harmless when they are already set.
export GZ_SIM_RESOURCE_PATH="${GZ_SIM_RESOURCE_PATH:-/opt/ros/${ROS_DISTRO}/share/}"
export GZ_SIM_SYSTEM_PLUGIN_PATH="${GZ_SIM_SYSTEM_PLUGIN_PATH:-/opt/ros/${ROS_DISTRO}/lib}"
export GZ_CONFIG_PATH="${GZ_CONFIG_PATH:-/opt/ros/${ROS_DISTRO}/opt/gz_sim_vendor/share/gz:/opt/ros/${ROS_DISTRO}/opt/gz_gui_vendor/share/gz:/opt/ros/${ROS_DISTRO}/opt/gz_transport_vendor/share/gz:/opt/ros/${ROS_DISTRO}/opt/sdformat_vendor/share/gz:/opt/ros/${ROS_DISTRO}/opt/gz_rendering_vendor/share/gz:/opt/ros/${ROS_DISTRO}/opt/gz_plugin_vendor/share/gz:/opt/ros/${ROS_DISTRO}/opt/gz_fuel_tools_vendor/share/gz:/opt/ros/${ROS_DISTRO}/opt/gz_msgs_vendor/share/gz:/opt/ros/${ROS_DISTRO}/opt/gz_common_vendor/share/gz:/opt/ros/${ROS_DISTRO}/opt/gz_math_vendor/share/gz:/opt/ros/${ROS_DISTRO}/opt/gz_utils_vendor/share/gz:/opt/ros/${ROS_DISTRO}/opt/gz_tools_vendor/share/gz:/opt/ros/${ROS_DISTRO}/opt/gz_ogre_next_vendor/share/gz}"
export GZ_PYTHON_PATH="${GZ_PYTHON_PATH:-/opt/ros/${ROS_DISTRO}/opt/gz_sim_vendor/lib/python:/opt/ros/${ROS_DISTRO}/opt/gz_transport_vendor/lib/python:/opt/ros/${ROS_DISTRO}/opt/sdformat_vendor/lib/python:/opt/ros/${ROS_DISTRO}/opt/gz_msgs_vendor/lib/python:/opt/ros/${ROS_DISTRO}/opt/gz_math_vendor/lib/python}"

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

# Make the display visible to interactive shells started later.
echo "export DISPLAY='${DISPLAY}'" >> /root/.bashrc

# DDS discovery uses multicast; host networking (compose) keeps it working.
export ROS_AUTOMATIC_DISCOVERY_RANGE="${ROS_AUTOMATIC_DISCOVERY_RANGE:-SUBNET}"
export RMW_IMPLEMENTATION="${RMW_IMPLEMENTATION:-rmw_fastrtps_cpp}"

# Convenience: the workspace is the current directory.
cd "${WORKSPACE}"

if [ "$#" -eq 0 ]; then
    exec bash
fi

exec "$@"
