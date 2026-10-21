# syntax=docker/dockerfile:1
# =============================================================================
#  Hexapod ROS 2 System - container image
#
#  ROS 2 Jazzy Jalisco + Gazebo Harmonic + MoveIt 2 + ros2_control, with the
#  hexapod workspace already compiled so the container starts instantly.
#
#  Build from the repository root:
#      docker build -f docker/Dockerfile -t hexapod-ros2:jazzy .
# =============================================================================
ARG ROS_DISTRO=jazzy
FROM osrf/ros:${ROS_DISTRO}-desktop

ARG ROS_DISTRO=jazzy
ARG WORKSPACE=/opt/hexapod_ws

ENV DEBIAN_FRONTEND=noninteractive \
    ROS_DISTRO=${ROS_DISTRO} \
    WORKSPACE=${WORKSPACE} \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    DISPLAY=:99

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# -----------------------------------------------------------------------------
# 1. ROS 2 and system dependencies
#
#    Everything is installed by explicit package name instead of rosdep: it is
#    deterministic, needs no rosdep index download, and it lets us skip the
#    three stale "om_*" open_manipulator dependencies that the `hexapod`
#    package still lists in its package.xml (those packages are not used).
# -----------------------------------------------------------------------------
RUN apt-get update
RUN apt-get install -y --no-install-recommends \
      # -- Gazebo Harmonic itself (gz-sim 8) and the "gz" command line ------
      ros-${ROS_DISTRO}-gz-sim-vendor \
      ros-${ROS_DISTRO}-gz-tools-vendor \
      # -- ros_gz: Gazebo Harmonic <-> ROS 2 bridge, used by hex_gz ----------
      ros-${ROS_DISTRO}-ros-gz-bridge \
      ros-${ROS_DISTRO}-ros-gz-sim \
      ros-${ROS_DISTRO}-ros-gz-image \
      ros-${ROS_DISTRO}-ros-gz-interfaces \
      ros-${ROS_DISTRO}-gz-ros2-control \
      # -- ros2_control: joint trajectory + state broadcast controllers ------
      ros-${ROS_DISTRO}-ros2-control \
      ros-${ROS_DISTRO}-ros2-controllers \
      ros-${ROS_DISTRO}-controller-manager \
      ros-${ROS_DISTRO}-hardware-interface \
      ros-${ROS_DISTRO}-joint-trajectory-controller \
      ros-${ROS_DISTRO}-joint-state-broadcaster \
      ros-${ROS_DISTRO}-transmission-interface \
      # -- MoveIt 2: motion planning, RViz MotionPlanning panel --------------
      ros-${ROS_DISTRO}-moveit \
      ros-${ROS_DISTRO}-moveit-ros-move-group \
      ros-${ROS_DISTRO}-moveit-ros-visualization \
      ros-${ROS_DISTRO}-moveit-ros-perception \
      ros-${ROS_DISTRO}-moveit-configs-utils \
      ros-${ROS_DISTRO}-moveit-setup-assistant \
      ros-${ROS_DISTRO}-moveit-ros-warehouse \
      # -- description / tooling --------------------------------------------
      ros-${ROS_DISTRO}-robot-state-publisher \
      ros-${ROS_DISTRO}-joint-state-publisher \
      ros-${ROS_DISTRO}-joint-state-publisher-gui \
      ros-${ROS_DISTRO}-xacro \
      ros-${ROS_DISTRO}-rviz2 \
      # -- python helpers used by the hex_gz scripts -------------------------
      python3-numpy \
      python3-matplotlib \
      python3-serial \
      python3-websockets \
      python3-websocket \
      python3-transforms3d \
      python3-tk \
      python3-colcon-common-extensions \
      # -- build tooling ----------------------------------------------------
      build-essential \
      cmake \
      git \
      curl \
      # -- graphics: OpenGL/EGL for Gazebo and RViz --------------------------
      libgl1 \
      libegl1 \
      libgles2 \
      libgl1-mesa-dri \
      libglx-mesa0 \
      mesa-utils \
      # -- X11 client bits for the Gazebo / RViz windows ---------------------
      libx11-6 \
      libxext6 \
      libxrender1 \
      libxtst6 \
      x11-utils \
      xvfb \
      # -- serial port access for the ESP32 hardware interface --------------
      usbutils \
      && apt-get clean

# -----------------------------------------------------------------------------
# 2. Workspace source
# -----------------------------------------------------------------------------
WORKDIR ${WORKSPACE}
COPY sim_and_real/ros2_ws_hex/src/ ${WORKSPACE}/src/

# The workspace is built with --symlink-install, so the executables in
# install/ are symlinks to these files and keep their source permissions.
# Make sure the scripts that are installed as programs are executable, even if
# the files arrived without the execute bit.
RUN chmod +x ${WORKSPACE}/src/hex_gz/scripts/*.py \
             ${WORKSPACE}/src/hex_gz/scripts_m/*.py \
             ${WORKSPACE}/src/hexapod_description/contact/*.py

# -----------------------------------------------------------------------------
# 3. Build the workspace
#
#    --symlink-install keeps the install/ tree pointing at src/, so mounting
#    the host source over /opt/hexapod_ws/src at run time makes edits visible
#    to the already-installed packages without a rebuild.
# -----------------------------------------------------------------------------
RUN source "/opt/ros/${ROS_DISTRO}/setup.bash" && \
    colcon build \
        --symlink-install \
        --cmake-args -DCMAKE_BUILD_TYPE=Release \
        --event-handlers console_direct+ && \
    echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /root/.bashrc && \
    echo "source ${WORKSPACE}/install/setup.bash" >> /root/.bashrc && \
    echo "alias cb='colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release'" >> /root/.bashrc && \
    echo "alias cs='source ${WORKSPACE}/install/setup.bash'" >> /root/.bashrc

# -----------------------------------------------------------------------------
# 4. Environment
#
#    The values below are what "source setup.bash" produces for this image.
#    Baking them in means "docker exec <container> ros2 topic list" works
#    without going through a shell first. The shell hooks below source the
#    same setup again, which is idempotent.
# -----------------------------------------------------------------------------
ENV AMENT_PREFIX_PATH="/opt/hexapod_ws/install/hexapod_moveit_config:/opt/hexapod_ws/install/hexapod_hardware:/opt/hexapod_ws/install/hexapod:/opt/hexapod_ws/install/hex_gz:/opt/hexapod_ws/install/hexapod_description:/opt/ros/jazzy" \
    CMAKE_PREFIX_PATH="/opt/hexapod_ws/install/hexapod_moveit_config:/opt/hexapod_ws/install/hexapod_hardware:/opt/hexapod_ws/install/hexapod:/opt/hexapod_ws/install/hex_gz:/opt/hexapod_ws/install/hexapod_description:/opt/ros/jazzy/opt/gz_sim_vendor:/opt/ros/jazzy/opt/gz_sensors_vendor:/opt/ros/jazzy/opt/gz_physics_vendor:/opt/ros/jazzy/opt/sdformat_vendor:/opt/ros/jazzy/opt/gz_gui_vendor:/opt/ros/jazzy/opt/gz_transport_vendor:/opt/ros/jazzy/opt/gz_rendering_vendor:/opt/ros/jazzy/opt/gz_plugin_vendor:/opt/ros/jazzy/opt/gz_fuel_tools_vendor:/opt/ros/jazzy/opt/gz_msgs_vendor:/opt/ros/jazzy/opt/gz_common_vendor:/opt/ros/jazzy/opt/gz_math_vendor:/opt/ros/jazzy/opt/gz_utils_vendor:/opt/ros/jazzy/opt/gz_tools_vendor:/opt/ros/jazzy/opt/gz_ogre_next_vendor:/opt/ros/jazzy/opt/gz_dartsim_vendor:/opt/ros/jazzy/opt/gz_cmake_vendor" \
    COLCON_PREFIX_PATH="/opt/hexapod_ws/install" \
    GZ_CONFIG_PATH="/opt/ros/jazzy/opt/gz_sim_vendor/share/gz:/opt/ros/jazzy/opt/sdformat_vendor/share/gz:/opt/ros/jazzy/opt/gz_gui_vendor/share/gz:/opt/ros/jazzy/opt/gz_transport_vendor/share/gz:/opt/ros/jazzy/opt/gz_rendering_vendor/share/gz:/opt/ros/jazzy/opt/gz_plugin_vendor/share/gz:/opt/ros/jazzy/opt/gz_fuel_tools_vendor/share/gz:/opt/ros/jazzy/opt/gz_msgs_vendor/share/gz:/opt/ros/jazzy/opt/gz_common_vendor/share/gz" \
    GZ_SIM_SYSTEM_PLUGIN_PATH="/opt/ros/jazzy/lib" \
    LD_LIBRARY_PATH="/opt/hexapod_ws/install/hexapod_hardware/lib:/opt/ros/jazzy/opt/gz_sim_vendor/lib:/opt/ros/jazzy/opt/gz_sensors_vendor/lib:/opt/ros/jazzy/opt/gz_physics_vendor/lib:/opt/ros/jazzy/opt/sdformat_vendor/lib:/opt/ros/jazzy/opt/rviz_ogre_vendor/lib:/opt/ros/jazzy/lib/x86_64-linux-gnu:/opt/ros/jazzy/opt/gz_gui_vendor/lib:/opt/ros/jazzy/opt/gz_transport_vendor/lib:/opt/ros/jazzy/opt/gz_rendering_vendor/lib:/opt/ros/jazzy/opt/gz_plugin_vendor/lib:/opt/ros/jazzy/opt/gz_fuel_tools_vendor/lib:/opt/ros/jazzy/opt/gz_msgs_vendor/lib:/opt/ros/jazzy/opt/gz_common_vendor/lib:/opt/ros/jazzy/opt/gz_math_vendor/lib:/opt/ros/jazzy/opt/gz_utils_vendor/lib:/opt/ros/jazzy/opt/gz_tools_vendor/lib:/opt/ros/jazzy/opt/gz_ogre_next_vendor/lib:/opt/ros/jazzy/opt/gz_dartsim_vendor/lib:/opt/ros/jazzy/opt/gz_cmake_vendor/lib:/opt/ros/jazzy/lib" \
    PATH="/opt/ros/jazzy/opt/gz_msgs_vendor/bin:/opt/ros/jazzy/opt/gz_tools_vendor/bin:/opt/ros/jazzy/opt/gz_ogre_next_vendor/bin:/opt/ros/jazzy/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    PYTHONPATH="/opt/ros/jazzy/opt/gz_sim_vendor/lib/python:/opt/ros/jazzy/opt/sdformat_vendor/lib/python:/opt/ros/jazzy/opt/gz_transport_vendor/lib/python:/opt/ros/jazzy/opt/gz_msgs_vendor/lib/python:/opt/ros/jazzy/lib/python3.12/site-packages" \
    ROS_PYTHON_VERSION="3" \
    ROS_VERSION="2" \
    ROS_AUTOMATIC_DISCOVERY_RANGE="SUBNET" \
    BASH_ENV="/etc/hexapod/ros2_env.sh"

# -----------------------------------------------------------------------------
# 5. Shell hooks
#
#    Ubuntu's default .bashrc returns early for non-interactive shells
#    ("[ -z "$PS1" ] && return"), so the sourcing has to be put in front of
#    it. $BASH_ENV covers "bash -c ...", /etc/profile.d covers login shells.
# -----------------------------------------------------------------------------
COPY docker/ros2_env.sh /etc/hexapod/ros2_env.sh
RUN set -eu; \
    { \
        echo '# --- ROS 2 + hexapod workspace (added by the container image) ---'; \
        echo '[ -f /etc/hexapod/ros2_env.sh ] && . /etc/hexapod/ros2_env.sh'; \
        echo ''; \
        cat /root/.bashrc; \
    } > /root/.bashrc.new; \
    mv /root/.bashrc.new /root/.bashrc; \
    { \
        echo '# ROS 2 + hexapod workspace (added by the container image)'; \
        echo '[ -f /etc/hexapod/ros2_env.sh ] && . /etc/hexapod/ros2_env.sh'; \
    } > /etc/profile.d/ros2.sh; \
    chmod +x /etc/hexapod/ros2_env.sh

# -----------------------------------------------------------------------------
# 6. Entry point
# -----------------------------------------------------------------------------
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR ${WORKSPACE}
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
