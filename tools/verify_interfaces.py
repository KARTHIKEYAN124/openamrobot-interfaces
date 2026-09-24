"""Check each source definition against the active installed ROS interfaces."""

from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

from rosidl_generator_py import import_type_support
from rosidl_runtime_py.utilities import get_action, get_message, get_service


def main():
    loaders = {"msg": get_message, "srv": get_service, "action": get_action}
    count = 0
    for manifest in sorted(Path(sys.argv[1]).rglob("package.xml")):
        package = ET.parse(manifest).getroot().findtext("name")
        for kind, load in loaders.items():
            for definition in sorted((manifest.parent / kind).glob(f"*.{kind}")):
                interface = f"{package}/{kind}/{definition.stem}"
                subprocess.run(["ros2", "interface", "show", interface], check=True)
                load(interface)
                import_type_support(package)
                print(f"PASS: {interface}", flush=True)
                count += 1
    if count == 0:
        raise SystemExit("FAIL: no interface definitions discovered")
    print(f"PASS: {count} generated interfaces available", flush=True)


if __name__ == "__main__":
    main()
