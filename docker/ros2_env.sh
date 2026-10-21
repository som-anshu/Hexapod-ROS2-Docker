# =============================================================================
#  ROS 2 + hexapod workspace environment
#
#  Single source of truth for the container environment. It is sourced by:
#    * /root/.bashrc           - interactive shells
#    * /etc/profile.d/ros2.sh  - login shells (bash -l, sh -l)
#    * $BASH_ENV               - non-interactive bash ("bash -c ...")
#    * the container entry point
#
#  Sourcing it repeatedly is harmless: the ROS 2 setup scripts are idempotent
#  for PATH, AMENT_PREFIX_PATH, PYTHONPATH and LD_LIBRARY_PATH.
# =============================================================================

# The ROS 2 setup scripts read variables that may be unset (AMENT_TRACE_SETUP_FILES,
# COLCON_TRACE, ...), so they abort under "set -u". Lifting it around the
# sourcing keeps "set -u" working for the caller.
_ros2_env_nounset=0
case $- in
    *u*) _ros2_env_nounset=1 ;;
esac
set +u

_ros2_env_distro="${ROS_DISTRO:-jazzy}"
_ros2_env_ws="${WORKSPACE:-/opt/hexapod_ws}"

# setup.bash is a bash script and breaks under dash/sh. The POSIX flavour is
# setup.sh, and colcon generates one for the workspace as well.
if [ -n "${BASH_VERSION:-}" ]; then
    _ros2_env_ext="bash"
else
    _ros2_env_ext="sh"
fi

if [ -f "/opt/ros/${_ros2_env_distro}/setup.${_ros2_env_ext}" ]; then
    . "/opt/ros/${_ros2_env_distro}/setup.${_ros2_env_ext}"
fi

if [ -f "${_ros2_env_ws}/install/setup.${_ros2_env_ext}" ]; then
    . "${_ros2_env_ws}/install/setup.${_ros2_env_ext}"
fi

# The display picked at container start, see the entry point.
if [ -f /etc/hexapod/display.sh ]; then
    . /etc/hexapod/display.sh
fi

if [ "$_ros2_env_nounset" = "1" ]; then
    set -u
fi
unset _ros2_env_nounset _ros2_env_distro _ros2_env_ws _ros2_env_ext
