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
    LC_ALL=C.UTF-8

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# -----------------------------------------------------------------------------
# 1. ROS 2 and system dependencies
#
#    Everything is installed by explicit package name instead of rosdep: it is
#    deterministic, needs no rosdep index download, and it lets us skip the
#    three stale "om_*" open_manipulator dependencies that the `hexapod`
#    package still lists in its package.xml (those packages are not used).
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      # -- ros_gz: Gazebo Harmonic <-> ROS 2 bridge, used by hex_gz ----------
      ros-${ROS_DISTRO}-ros-gz-bridge \
      ros-${ROS_DISTRO}-ros-gz-sim \
      ros-${ROS_DISTRO}-ros-gz-image \
      ros-${ROS_DISTRO}-ros-gz-interfaces \
      ros-${ROS_DISTRO}-gz-ros2-control \
      ros-${ROS_DISTRO}-gz-sim-plugins \
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
      ros-${ROS_DISTRO}-warehouse-ros-mongo \
      # -- description / tooling --------------------------------------------
      ros-${ROS_DISTRO}-robot-state-publisher \
      ros-${ROS_DISTRO}-joint-state-publisher \
      ros-${ROS_DISTRO}-joint-state-publisher-gui \
      ros-${ROS_DISTRO}-xacro \
      ros-${ROS_DISTRO}-rviz2 \
      ros-${ROS_DISTRO}-rospy \
      # -- python helpers used by the hex_gz scripts -------------------------
      python3-numpy \
      python3-matplotlib \
      python3-serial \
      python3-websockets \
      python3-websocket \
      python3-transforms3d \
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
      && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 2. Workspace source
# -----------------------------------------------------------------------------
WORKDIR ${WORKSPACE}
COPY sim_and_real/ros2_ws_hex/src/ ${WORKSPACE}/src/

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
# 4. Entry point
# -----------------------------------------------------------------------------
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR ${WORKSPACE}
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
