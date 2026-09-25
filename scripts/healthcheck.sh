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
# Service Responsiveness
# ----------------------------------------

check_services() {
    echo "Service Responsiveness"
    echo "---------------------"

    check_http_service() {
        local name="$1"
        local port="$2"
        local expected="$3"

        local response

        response=$(curl \
            --silent \
            --output /dev/null \
            --write-out '%{http_code}' \
            --max-time 5 \
            "http://localhost:${port}/")

        if [ "$response" = "$expected" ]; then
            ok "$name is responding on port $port (HTTP $response)."
        else
            critical "$name returned HTTP $response on port $port (expected $expected)."
        fi
    }

    check_tcp_service() {
        local name="$1"
        local port="$2"

        if timeout 5 bash -c "</dev/tcp/127.0.0.1/$port" 2>/dev/null; then
            ok "$name is accepting TCP connections on port $port."
        else
            critical "$name is not accepting TCP connections on port $port."
        fi
    }

    check_http_service "Jellyfin" 8096 "302"
    check_http_service "Sonarr" 8989 "401"
    check_http_service "Bazarr" 6767 "200"

    check_tcp_service "Minecraft" 25565

    echo
}

# ----------------------------------------
# RAID
# ----------------------------------------

check_raid() {
    echo "RAID"
    echo "----"

    local arrays=(
        "md0"
        "md1"
    )

    for array in "${arrays[@]}"; do
        local line
        local status

        line=$(grep "^${array} :" /proc/mdstat)

        if [ -z "$line" ]; then
            critical "/dev/$array is not active."
            continue
        fi

        status=$(echo "$line" | awk '{print $3}')

        if [ "$status" != "active" ]; then
            critical "/dev/$array is not active (state: $status)."
            continue
        fi

        local detail
        detail=$(grep -A1 "^${array} :" /proc/mdstat | tail -n 1)

        if echo "$detail" | grep -q '\[2/2\] \[UU\]'; then
            ok "/dev/$array is healthy (2/2 devices active)."
        else
            critical "/dev/$array is degraded or rebuilding: $detail"
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
check_services
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
