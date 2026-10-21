#!/usr/bin/env bash
# =============================================================================
#  Container entrypoint for the Hexapod ROS 2 workspace.
#
#  Sources ROS 2 and the hexapod overlay workspace, then hands control to the
#  command passed on the docker run / compose "command:" line.
# =============================================================================
set -euo pipefail

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

# DDS discovery uses multicast; host networking (compose) keeps it working.
export ROS_LOCALHOST_ONLY="${ROS_LOCALHOST_ONLY:-0}"
export RMW_IMPLEMENTATION="${RMW_IMPLEMENTATION:-rmw_fastrtps_cpp}"

# Convenience: the workspace is the current directory.
cd "${WORKSPACE}"

if [ "$#" -eq 0 ]; then
    exec bash
fi

exec "$@"
