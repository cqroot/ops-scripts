#!/usr/bin/env bash
set -euo pipefail

# 生成可控的 CPU 高负载
# 用法: cpu-load.sh [-c CORES] [-p PERCENT] [-d DURATION]
#   -c CORES     worker 进程数（默认 1）
#   -p PERCENT   单核目标负载百分比 1-100（默认 100）
#   -d DURATION  持续秒数，0 表示直到收到信号（默认 0）
#   -h           显示帮助
# 收到 SIGINT/SIGTERM 时会先 kill 全部 worker 再退出，实现快速恢复

PIDS=()

cleanup() {
    local sig=$1
    echo "cpu-load: caught ${sig}, killing ${#PIDS[@]} worker(s)..." 1>&2
    local pid
    for pid in "${PIDS[@]:-}"; do
        [[ -z ${pid} ]] && continue
        kill "${pid}" 2>/dev/null || true
    done
    wait 2>/dev/null || true
    exit 0
}

trap 'cleanup INT' INT
trap 'cleanup TERM' TERM

print_usage() {
    cat <<EOF
Usage: $(basename "$0") [-c CORES] [-p PERCENT] [-d DURATION]

Generate CPU load by spawning worker processes.

Options:
  -c CORES     Number of worker processes (default: 1)
  -p PERCENT   Per-core load percentage, 1-100 (default: 100)
  -d DURATION  Duration in seconds, 0 = until signaled (default: 0)
  -h           Show this help

When PERCENT < 100, each worker alternates between a CPU-burning
busy loop and a sleep period to achieve the target load.
EOF
}

CORES=1
PERCENT=100
DURATION=0

while getopts ":c:p:d:h" opt; do
    case "${opt}" in
    c) CORES=${OPTARG} ;;
    p) PERCENT=${OPTARG} ;;
    d) DURATION=${OPTARG} ;;
    h) print_usage; exit 0 ;;
    \?) echo "Error: invalid option -${OPTARG}" 1>&2; exit 1 ;;
    :) echo "Error: option -${OPTARG} requires an argument" 1>&2; exit 1 ;;
    esac
done

if ! [[ ${CORES} =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: cores must be a positive integer" 1>&2
    exit 1
fi
if ! [[ ${PERCENT} =~ ^[1-9][0-9]*$ ]] || [[ ${PERCENT} -gt 100 ]]; then
    echo "Error: percent must be 1-100" 1>&2
    exit 1
fi
if ! [[ ${DURATION} =~ ^[0-9]+$ ]]; then
    echo "Error: duration must be a non-negative integer" 1>&2
    exit 1
fi

WORK_MS=$((PERCENT * 10))
SLEEP_MS=$(( (100 - PERCENT) * 10 ))

echo "cpu-load: ${CORES} worker(s) at ${PERCENT}% for ${DURATION}s (0=infinite)" 1>&2
echo "cpu-load: send SIGINT/SIGTERM for quick recovery" 1>&2

worker() {
    local work_ms=$1
    local sleep_ms=$2
    while true; do
        local end_ns=$(($(date +%s%N) + work_ms * 1000000))
        while [[ $(date +%s%N) -lt ${end_ns} ]]; do :; done
        if [[ ${sleep_ms} -gt 0 ]]; then
            sleep "$(awk -v ms=${sleep_ms} 'BEGIN { printf "%.3f", ms/1000 }')"
        fi
    done
}

for _ in $(seq 1 "${CORES}"); do
    worker "${WORK_MS}" "${SLEEP_MS}" &
    PIDS+=("$!")
done

if [[ ${DURATION} -gt 0 ]]; then
    sleep "${DURATION}"
    cleanup "EXIT"
else
    wait
fi

# vim: set filetype=bash :