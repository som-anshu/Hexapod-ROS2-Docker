# Hexapod ROS 2 System — Docker Edition

ROS 2 **Jazzy Jalisco** + **Gazebo Harmonic** simulation environment for an
18-DOF hexapod robot, packaged so that it runs with **one command** on any
machine with Docker.

Everything (Gazebo, RViz, MoveIt 2, `ros2_control`, the ESP32 serial
interface) lives inside the container. Your host only needs Docker — no ROS
installation, no Gazebo, no Python packages.

---

## Quick start

Copy and paste these four lines into a terminal:

```bash
git clone https://github.com/som-anshu/Hexapod-ROS2-Docker.git
cd Hexapod-ROS2-Docker
chmod +x install.sh run.sh
./install.sh
```

`install.sh` builds the image (≈ 5 GB download the first time, ~15 min).
When it finishes, start the container:

```bash
./run.sh
```

You are now inside a shell with the hexapod workspace sourced. Launch the
simulation:

```bash
ros2 launch hex_gz gazebo.launch.py
```

A Gazebo window opens with the hexapod standing on a slope. Make it walk:

```bash
ros2 run hex_gz tri_gate.py
```

> **One-liner alternative** (clone + build in one go):
> ```bash
> git clone https://github.com/som-anshu/Hexapod-ROS2-Docker.git && cd Hexapod-ROS2-Docker && chmod +x install.sh run.sh && ./install.sh
> ```

---

## Requirements

| Requirement | Notes |
| --- | --- |
| **Docker Engine** 24+ | with the `compose` plugin if you want the compose files |
| **4 GB RAM** free | Gazebo is hungry; 8 GB+ recommended |
| **~10 GB disk** | for the image and the build context |
| **GPU** | optional. Without an NVIDIA GPU Gazebo uses software rendering (slow but works) |
| **X11 / XWayland** | for the Gazebo and RViz windows. On a headless box use the Xvfb profile below |

Check your setup:

```bash
docker --version
docker info | grep -i runtime
```

---

## What you get

| Component | Version |
| --- | --- |
| ROS 2 | Jazzy Jalisco |
| Gazebo | Harmonic (gz-sim 8) |
| MoveIt 2 | 2.12 |
| ros2_control | 4.x |
| RMW | Fast DDS |

The image is built from `osrf/ros:jazzy-desktop` and the hexapod workspace is
**already compiled** at image build time, so the container starts instantly.

---

## Everyday use

### Simulation (Gazebo)

```bash
ros2 launch hex_gz gazebo.launch.py
```

### Gait algorithms

```bash
# Basic movement
ros2 run hex_gz wave_gate_square.py     # wave gait, square path
ros2 run hex_gz bi_gate.py               # bipod gait
ros2 run hex_gz tri_gate.py              # tripod gait
ros2 run hex_gz ripple_gate.py           # ripple gait
ros2 run hex_gz rotation.py              # turn in place

# Gait algorithms that use the foot contact sensors
ros2 run hex_gz wave_gate_contact_sensors.py
ros2 run hex_gz bi_gate_contact_sensors.py
ros2 run hex_gz tri_gate_contact_sensor.py

# Miscellaneous
ros2 run hex_gz hi.py                    # greeting wave
ros2 run hex_gz dance.py                 # dance routine
ros2 run hex_gz dance1.py                # second dance routine
ros2 run hex_gz move_body_based_on_imu.py  # level the body using the IMU
```

### RViz

```bash
ros2 launch hex_gz rviz.launch.py
```

### Collision model only

```bash
ros2 launch hex_gz collision_view.launch.py
```

### MoveIt 2 motion planning

```bash
ros2 launch hexapod_moveit_config demo.launch.py
```

### Real hardware (ESP32)

Find the serial port of the ESP32 on the host:

```bash
ls /dev/tty{USB,ACM}*
```

`run.sh` automatically passes any `/dev/ttyUSB*` or `/dev/ttyACM*` device into
the container, so inside the container you can just run:

```bash
ros2 launch hex_gz robot.launch.py port_name:=/dev/ttyUSB0
```

### Mobile app control (WebSocket)

The ROS host and the phone must be on the same Wi-Fi. Find the host IP:

```bash
hostname -I
```

Enter that address in the mobile app, then start the bridge inside the
container:

```bash
ros2 run hex_gz ws_run.py
```

---

## Development

The workspace source is bind-mounted from the host into the container, so you
edit the code in your normal editor and rebuild inside the container:

```bash
# inside the container
colcon build --symlink-install --packages-select hex_gz
source install/setup.bash
```

Because the image is built with `--symlink-install`, the `install/` tree
points back at `src/`, so a rebuild is fast and only recompiles what changed.

Useful aliases are already set in the container's shell:

| Alias | Expands to |
| --- | --- |
| `cb` | `colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release` |
| `cs` | `source /opt/hexapod_ws/install/setup.bash` |

---

## Headless machines (no display)

Run Gazebo inside a virtual framebuffer. Add this profile:

```yaml
# docker-compose.headless.yml
services:
  hexapod:
    environment:
      DISPLAY: ":99"
    entrypoint: ["/usr/bin/xvfb-run", "-a", "--server-args=-screen 0 1280x1024x24"]
```

```bash
docker compose -f docker-compose.yml -f docker-compose.headless.yml up
```

Gazebo then renders offscreen — you can still talk to the robot over ROS 2 and
capture images with `ros2 run ros_gz image ...`.

---

## Troubleshooting

**`docker: command not found`** — install Docker:
<https://docs.docker.com/engine/install/>

**`Cannot connect to the Docker daemon`** — start it:
```bash
sudo systemctl start docker
```

**Gazebo window does not appear** — the container needs your X server:
```bash
echo $DISPLAY            # e.g. :0
ls /tmp/.X11-unix/       # must contain X0
xhost +local:            # allow the container to connect
```
On Wayland, the Gazebo window is forwarded through XWayland, so `DISPLAY` must
still be set. `run.sh` handles this automatically when `/tmp/.X11-unix` exists.

**Gazebo is very slow / black window** — you are on software rendering.
Check with `nvidia-smi` inside the container; if there is no GPU, keep
`LIBGL_ALWAYS_SOFTWARE=1` and accept the lower frame rate, or install the
NVIDIA container toolkit so `run.sh` can enable the GPU.

**`Package 'ros_gz_bridge' not found`** — the image is out of date, rebuild:
```bash
./install.sh
```

**Nodes in the container do not see nodes on the host** — the container must
use host networking. `run.sh` and the compose file already do this; if you
started the container by hand, add `--network host`.

**Serial port not found inside the container** — the device was not passed in.
Check `ls /dev/tty*` inside the container, and confirm the ESP32 is not claimed
by `brltty`/`ModemManager` on the host.

---

## Project layout

```
Hexapod-ROS2-Docker/
├── install.sh                 # builds the Docker image
├── run.sh                     # starts the container (GUI, GPU, serial, live source)
├── docker-compose.yml         # compose equivalent of run.sh
├── docker-compose.hardware.yml# ESP32 serial device passthrough
├── docker/
│   ├── Dockerfile              # ROS 2 Jazzy + Gazebo Harmonic + MoveIt
│   └── entrypoint.sh          # sources ROS 2 and the workspace
├── Sim Models/                # CAD source of the robot (SolidWorks)
└── sim_and_real/
    ├── Projects/              # ESP32 firmware + PC<->ESP helper projects
    └── ros2_ws_hex/src/       # the ROS 2 workspace
        ├── hex_gz/            # Gazebo launch files, worlds, gait scripts
        ├── hexapod/           # umbrella package
        ├── hexapod_description/  # URDF/xacro, meshes, ros2_control config
        ├── hexapod_hardware/  # ESP32 serial hardware interface
        └── hexapod_moveit_config/  # MoveIt 2 configuration
```

---

## Credits

This repository is the **Docker packaging** of
[Hexapod-ROS2-System](https://github.com/Siedmiu/Hexapod-ROS2-System) by
**Bebo457 (Siedmiu)**. All robot models, URDF/xacro descriptions, gait
algorithms and MoveIt configuration are the original work and remain
copyright of their author — see `NOTICE`.

The initial setup and configuration patterns were inspired by the
[ROBOTIS open_manipulator](https://github.com/ROBOTIS-GIT/open_manipulator)
project, although the implementation was completely redesigned for hexapod
robotics, with original kinematics, hardware interfaces and control
algorithms.

Built on: [ROS 2](https://docs.ros.org/en/jazzy/),
[Gazebo](https://gazebosim.org/),
[MoveIt 2](https://moveit.ai/),
[ros2_control](https://control.ros.org/),
[ros_gz](https://github.com/ros2-gz/ros_gz).
