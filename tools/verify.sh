#!/usr/bin/env bash
# Run from any directory. Requires ROS 2 Jazzy and dependencies (see docs).
set -eo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$root/.verification"
run=$(mktemp -d "$root/.verification/run.XXXXXX")
exec > >(tee "$run/verification.log") 2>&1
stage=prerequisites
finish() {
  result=$?
  if [ "$result" -eq 0 ]; then
    echo "PASS: build, generated interfaces, and clean-workspace consumer" | tee "$run/result.txt"
  else
    echo "FAIL: $stage (exit $result)" | tee "$run/result.txt"
  fi
  echo "Evidence: $run"
  exit "$result"
}
trap finish EXIT

# Never inherit ROS overlays, Python paths or CMake prefixes from the caller.
mkdir -p "$run/home/.ros"
# rosdep's downloaded index is prerequisite data, not a developer overlay.
if [ -d "${ROS_HOME:-$HOME/.ros}/rosdep" ]; then
  cp -a "${ROS_HOME:-$HOME/.ros}/rosdep" "$run/home/.ros/"
fi
clean_bash() {
  env -i HOME="$run/home" PATH=/usr/bin:/bin LANG=C.UTF-8 PYTHONNOUSERSITE=1 \
    bash --noprofile --norc -eo pipefail "$@"
}
clean_bash -c '
  test -f /opt/ros/jazzy/setup.bash
  source /opt/ros/jazzy/setup.bash
  command -v colcon
  command -v rosdep
  rosdep check --from-paths "$1/ros2" --ignore-src --rosdistro jazzy
' verify "$root"

stage=interface-build
mkdir -p "$run/producer/src"
cp -a "$root/ros2/." "$run/producer/src/"
clean_bash -c '
  source /opt/ros/jazzy/setup.bash
  cd "$1/producer"
  colcon build --base-paths src --event-handlers console_direct+
' verify "$run"

# Relocate an ordinary (not symlink) install and retire the original workspace.
# Absolute source/build/install references now point to paths that do not exist.
cp -a "$run/producer/install" "$run/underlay"
mv "$run/producer" "$run/producer-retired"

stage=generated-interfaces
clean_bash -c '
  source /opt/ros/jazzy/setup.bash
  source "$1/underlay/local_setup.bash"
  python3 "$2/tools/verify_interfaces.py" "$1/producer-retired/src"
' verify "$run" "$root" | tee "$run/generated-interfaces.log"

stage=clean-consumer-build
mkdir -p "$run/consumer/src"
cp -a "$root/tests/install_consumer" "$run/consumer/src/"
clean_bash -c '
  source /opt/ros/jazzy/setup.bash
  source "$1/underlay/local_setup.bash"
  cd "$1/consumer"
  colcon build --base-paths src --event-handlers console_direct+
  source install/local_setup.bash
  ros2 run interface_install_consumer verify_installed_interfaces
' verify "$run"
