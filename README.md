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
When it finishes, start the simulation:

```bash
./run.sh
```

That starts the container and launches Gazebo straight away. A window opens
with the hexapod standing on a slope, and the six leg controllers come up
active.

To make it walk, open a **second terminal** and use the shell mode:

```bash
cd Hexapod-ROS2-Docker
./run.sh shell
ros2 run hex_gz tri_gate.py
```

The two containers talk to each other over ROS 2, so the gait script in the
second terminal drives the robot in the first one.

> **One-liner alternative** (clone + build in one go):
> ```bash
> git clone https://github.com/som-anshu/Hexapod-ROS2-Docker.git && cd Hexapod-ROS2-Docker && chmod +x install.sh run.sh && ./install.sh
> ```

### `run.sh` modes

| Command | What it does |
| --- | --- |
| `./run.sh` | launch the Gazebo simulation (container `hexapod-ros2`) |
| `./run.sh shell` | plain shell in a second container (`hexapod-ros2-shell`) |
| `./run.sh <command...>` | run one command and exit (`hexapod-ros2-run`) |

Each mode uses its own container name, so starting the shell does **not**
stop the simulation.

---

## Verified

This container has been exercised end to end:

- `ros2 launch hex_gz gazebo.launch.py` starts Gazebo Harmonic with **zero
  launch errors**, and all six leg controllers plus the joint state
  broadcaster report `active`.
- `ros2 run hex_gz tri_gate.py` drives the joints and the foot contact
  sensors report `true` on touchdown.
- `ros2 launch hexapod_moveit_config demo.launch.py` starts `move_group` and
  RViz, and `/plan_kinematic_path`, `/get_planning_scene` and `/compute_ik`
  are all served.
- Everything above also works with **no display at all** (the entry point
  starts a virtual framebuffer).

---

## Requirements

| Requirement | Notes |
| --- | --- |
| **Docker Engine** 24+ | with the `compose` plugin if you want the compose files |
| **4 GB RAM** free | Gazebo is hungry; 8 GB+ recommended |
| **~10 GB disk** | for the image and the build context |
| **GPU** | optional. Without an NVIDIA GPU Gazebo uses software rendering (slow but works) |
| **X11 / XWayland** | optional. Needed only for Gazebo/RViz windows; without it the container starts its own virtual display |

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

## The environment inside the container

ROS 2 and the workspace are **already sourced** — you never have to source
anything yourself:

| How you open a shell | Where the environment comes from |
| --- | --- |
| `./run.sh` (the interactive shell) | the entry point, before `exec bash` |
| `docker exec -it <name> bash` | `/root/.bashrc` |
| `docker exec <name> bash -c "..."` | `$BASH_ENV` |
| `docker exec <name> sh -c "..."` | the image environment |
| `docker exec <name> ros2 topic list` | the image environment |

The image bakes in the variables that `setup.bash` produces, so even a direct
`docker exec` of a binary finds `ros2`, `gz` and `colcon` on the `PATH`.

`/etc/hexapod/ros2_env.sh` is the single place where that happens, and every
shell path above ends up running it. Sourcing it twice is harmless.

### The hexapod runs in the container, not on your host

The workspace targets **Jazzy + Gazebo Harmonic**. If your host has a
different ROS 2 distro installed, running `ros2 launch hex_gz gazebo.launch.py`
on the host will not work — the `hex_gz` package is only built inside the
container, and the Gazebo API differs between distro generations.

Use `./run.sh` on the host, and the `ros2` commands inside the container.

---

## Everyday use

### Simulation (Gazebo)

```bash
./run.sh                                  # from the host
```

or, from inside the container:

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

Nothing special is needed. When the container cannot reach the host's X
display, the entry point starts a virtual framebuffer (Xvfb) on `:99` and
exports `DISPLAY` accordingly, so Gazebo renders offscreen and the gait
scripts (which use `matplotlib`) still run. You can still drive the robot over
ROS 2 and capture images with the `ros_gz` image tooling.

To force software rendering and skip the host display entirely, use the
headless compose profile:

```bash
docker compose -f docker-compose.yml -f docker-compose.headless.yml up
```

> If you `docker exec` into a running container, `DISPLAY` is already set to
> the same value the entry point chose, so extra commands work unchanged.

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
echo $XAUTHORITY         # the X access cookie, must exist
```
On Wayland, the Gazebo window is forwarded through XWayland, so `DISPLAY` must
still be set. `run.sh` handles all of this automatically: it mounts
`/tmp/.X11-unix`, mounts and exports `XAUTHORITY`, and falls back to
`xhost +local:` when no cookie file is available.

**`no Qt platform plugin could be initialized`** — the container could not
authenticate against the X server. This is the `XAUTHORITY` problem above; run
`xhost +local:` manually as a quick check.

**`MESA: error: Failed to query drm device` in the Gazebo log** — harmless.
Mesa is probing for a DRM device that does not exist in a container and then
falls back to zink/Vulkan. Check what is actually rendering with:
```bash
docker exec -it <container> glxinfo -B | grep "OpenGL renderer"
```

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
