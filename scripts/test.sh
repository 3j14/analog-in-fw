#!/usr/bin/env bash
set -euo pipefail

TESTBENCHES=$(find library -path library/red-pitaya-notes -prune -false -o -name \*_tb.sv)
BUILD_DIR="./build/verilator"
mkdir -p -- "$BUILD_DIR"
declare -a otherfiles

case "$(uname -s)" in
    Darwin)
        YOSYS_SIM="/opt/homebrew/share/yosys/xilinx/cells_sim.v"
        ;;
    Linux)
        YOSYS_SIM="/usr/share/yosys/xilinx/cells_sim.v"
        ;;
    *)
        echo "Unsupported platform" >&2
        exit 1
        ;;
esac

HAS_ERROR=false

set +e
for test_bench in $TESTBENCHES; do
    module="$(basename "$test_bench" | sed 's|\.sv||')"
    local_build_dir="$BUILD_DIR/$module"
    mkdir -p -- "$local_build_dir"
    dir="$(dirname "$test_bench")"
    non_tb_file="$dir/${module/_tb/}.v"
    # Add other files like the module.v (without '_tb' extension)
    # and the yosys simulation sources.
    otherfiles=()
    if [[ -f "$non_tb_file" ]]; then
        otherfiles+=( "$non_tb_file" )
    fi
    if [[ -f "$YOSYS_SIM" ]]; then
        otherfiles+=( "$YOSYS_SIM" )
    fi
    echo "Compile '$test_bench'..."
    # Compile the SystemVerilog testbench
    verilator --binary \
        config.vlt \
        -Mdir "$local_build_dir" \
        -o "$module" \
        -I"$dir" \
        "${otherfiles[@]}" \
        "$test_bench" \
        --top "$module" > /dev/null
    if [[ $? -eq 0 ]]; then
        # Compilation succeeded, proceed to run
        # the compiled executable
        echo "Running '$module'..."
        "./$local_build_dir/$module"
        if [[ $? -ne 0 ]]; then
            HAS_ERROR=true
        fi
    else
        echo "Compilation failed for '$module'"
        HAS_ERROR=true
    fi
done

# Check if any of the previous compilation steps were
# successful.
if [[ "$HAS_ERROR" = true ]]; then
    exit 1;
fi
