#!/usr/bin/env bash

# Homelab health check
#
# Exit codes:
#   0 - Healthy
#   1 - Warning
#   2 - Critical

set -u

WARNING=1
CRITICAL=2
STATUS=0

# ----------------------------------------
# Output helpers
# ----------------------------------------

ok() {
    echo "[OK]       $1"
}

warning() {
    echo "[WARNING]  $1"

    if [ "$STATUS" -lt "$WARNING" ]; then
        STATUS=$WARNING
    fi
}

critical() {
    echo "[CRITICAL] $1"
    STATUS=$CRITICAL
}

# ----------------------------------------
# Docker
# ----------------------------------------

check_docker() {
    echo "Docker"
    echo "------"

    if systemctl is-active --quiet docker; then
        ok "Docker service is running."
    else
        critical "Docker service is not running."
        return
    fi

    local containers=(
        "jellyfin"
        "sonarr"
        "bazarr"
        "minecraft"
    )

    for container in "${containers[@]}"; do
        local state

        state=$(docker inspect \
            --format '{{.State.Status}}' \
            "$container" 2>/dev/null || true)

        if [ "$state" = "running" ]; then
            ok "$container is running."
        elif [ -z "$state" ]; then
            critical "$container does not exist."
        else
            critical "$container is not running (state: $state)."
        fi
    done

    echo
}

# ----------------------------------------
# RAID
# ----------------------------------------

check_raid() {
    echo "RAID"
    echo "----"

    local arrays=(
        "/dev/md0"
        "/dev/md1"
    )

    for array in "${arrays[@]}"; do
        if [ ! -e "$array" ]; then
            critical "$array does not exist."
            continue
        fi

        local state
        local active
        local total

        state=$(mdadm --detail "$array" 2>/dev/null |
            awk -F': ' '/State :/ {print $2}')

        active=$(mdadm --detail "$array" 2>/dev/null |
            awk '/Active Devices/ {print $NF}')

        total=$(mdadm --detail "$array" 2>/dev/null |
            awk '/Raid Devices/ {print $NF}')

        if [ "$active" = "$total" ] &&
           echo "$state" | grep -q "clean"; then
            ok "$array is healthy ($active/$total devices active)."
        else
            critical "$array is degraded or unhealthy ($state, $active/$total devices active)."
        fi
    done

    echo
}

# ----------------------------------------
# Filesystem usage
# ----------------------------------------

check_filesystems() {
    echo "Filesystem Usage"
    echo "----------------"

    check_filesystem "/" 80 90
    check_filesystem "/srv" 80 90

    echo
}

check_filesystem() {
    local mountpoint="$1"
    local warning_threshold="$2"
    local critical_threshold="$3"

    if ! mountpoint -q "$mountpoint"; then
        critical "$mountpoint is not mounted."
        return
    fi

    local usage

    usage=$(df --output=pcent "$mountpoint" |
        tail -n 1 |
        tr -dc '0-9')

    if [ "$usage" -ge "$critical_threshold" ]; then
        critical "$mountpoint is ${usage}% full."
    elif [ "$usage" -ge "$warning_threshold" ]; then
        warning "$mountpoint is ${usage}% full."
    else
        ok "$mountpoint is ${usage}% full."
    fi
}

# ----------------------------------------
# System load
# ----------------------------------------

check_load() {
    echo "System Load"
    echo "-----------"

    local load
    local cpu_count
    local threshold

    load=$(awk '{print $1}' /proc/loadavg)
    cpu_count=$(nproc)

    # Warn when the 1-minute load exceeds the number
    # of available logical CPUs.
    threshold="$cpu_count"

    if awk "BEGIN {exit !($load >= $threshold)}"; then
        warning "1-minute load is $load across $cpu_count logical CPUs."
    else
        ok "1-minute load is $load across $cpu_count logical CPUs."
    fi

    echo
}

# ----------------------------------------
# Memory
# ----------------------------------------

check_memory() {
    echo "Memory"
    echo "------"

    local total
    local available
    local used_percent

    total=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
    available=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)

    used_percent=$(
        awk -v total="$total" -v available="$available" \
            'BEGIN {
                printf "%.0f", ((total - available) / total) * 100
            }'
    )

    if [ "$used_percent" -ge 90 ]; then
        critical "Memory usage is approximately ${used_percent}%."
    elif [ "$used_percent" -ge 80 ]; then
        warning "Memory usage is approximately ${used_percent}%."
    else
        ok "Memory usage is approximately ${used_percent}%."
    fi

    echo
}

# ----------------------------------------
# Main
# ----------------------------------------

echo "========================================"
echo " Homelab Health Check"
echo "========================================"
echo

check_docker
check_raid
check_filesystems
check_load
check_memory

echo "========================================"

case "$STATUS" in
    0)
        echo "Overall status: HEALTHY"
        ;;
    1)
        echo "Overall status: WARNING"
        ;;
    2)
        echo "Overall status: CRITICAL"
        ;;
esac

echo "========================================"

exit "$STATUS"
