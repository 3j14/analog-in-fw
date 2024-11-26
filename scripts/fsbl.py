# First stage bootloader
import sys
import argparse
from pathlib import Path

try:
    import vitis
except ImportError as e:
    raise ImportError(
        f"Script needs to be run using Vitis: vitis -s {' '.join(sys.argv)}"
    ) from e

parser = argparse.ArgumentParser()
parser.add_argument("command", choices=["build", "create"], help="sub-command")
parser.add_argument("name", help="name of the project, e.g. 'blink'")
parser.add_argument(
    "processor",
    nargs="?",
    default="ps7_cortexa9_0",
    help="target processor. Defaults to 'ps7_cortexa9_0'",
)
args = parser.parse_args()
name = args.name
# component_name = f"{name}-fsbl"
component_name = "fsbl"
workspace = Path("build") / "projects" / name
hw_design = workspace / f"{name}.xsa"
processor = args.processor

if not hw_design.is_file():
    raise FileNotFoundError(
        f"'{hw_design}' could not be found. Run 'make xsa PROJECT={name}' first."
    )

client = vitis.create_client()
client.update_workspace(str(workspace.resolve()))
client.set_workspace(str(workspace.resolve()))

if args.command == "create":
    platform = client.create_platform_component(
        name=component_name,
        hw_design=str(hw_design.resolve()),
        os="standalone",
        cpu=processor,
    )
else:
    platform = client.get_component(component_name)

if args.command == "build":
    platform.build()
