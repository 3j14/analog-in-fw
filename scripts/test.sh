#!/usr/bin/env bash
set -euo pipefail

TESTBENCHES=$(find library \( -path library/red-pitaya-notes -o -path library/adi-hdl \) -prune -false -o -name \*_tb.sv)
BUILD_DIR="./build"

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

HAS_ERROR=0

set +e
for test_bench in $TESTBENCHES; do
    echo "Compile '$test_bench'..."
    module="$(basename "$test_bench" | sed 's|\.sv||')"
    verilator --binary \
        config.vlt \
        -Mdir "$BUILD_DIR" \
        -o "$module" \
        -I"$(dirname "$test_bench")" \
        "$YOSYS_SIM" \
        "$test_bench" \
        --top "$module" &> /dev/null
    if [[ "$?" == "0" ]]; then
        echo "Running '$module'..."
        ./"$BUILD_DIR"/"$module"
        if [[ "$?" != "0" ]]; then
            HAS_ERROR=1
        fi
    else
        echo "Compilation failed for '$module'"
        HAS_ERROR=1
    fi
done

if [[ "$HAS_ERROR" == "1" ]]; then
    exit 1;
fi
