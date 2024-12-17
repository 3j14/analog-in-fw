#!/usr/bin/env bash
docker pull verilator/verilator:latest > /dev/null
docker run \
    -v /usr/share/yosys:/usr/share/yosys \
    -v "${PWD}":/work \
    --entrypoint /usr/local/bin/verilator \
    verilator/verilator:latest "$@"
