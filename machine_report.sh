#!/bin/bash
# TR-100 Machine Report
# Copyright © 2024, U.S. Graphics, LLC. BSD-3-Clause License.

# Basic configuration, change as needed
report_title="UNITED STATES GRAPHICS COMPANY"

# Utilities
bar_graph() {
    local percent
    local num_blocks
    local width=29
    local graph=""
    local used=$1
    local total=$2

    percent=$(printf "%.2f" "$(echo "$used / $total * 100" | bc -l)")
    num_blocks=$(echo "scale=2; ${percent}/100*${width}" | bc -l | numfmt --from=iec --format %.0f)
    for (( i = 0; i < num_blocks; i++ )); do
        graph+="█"
    done
    for (( i=0; i < width - num_blocks; i++ )); do
        graph+="░"
    done
    printf "%s" "${graph}"
}

# Detect OS Type
detect_os() {
    source /etc/os-release
    if [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "arch"
    fi
}
os_type=$(detect_os)

pad_report_title() {
    local title="$1"
    local max_length=42
    local title_length=${#title}
    local padding_length=$((max_length - title_length))
    local left_padding=$((padding_length / 2))
    local right_padding=$((padding_length - left_padding))
    local padded_title=""

    for (( i=0; i<left_padding; i++ )); do
        padded_title+=" "
    done
    padded_title+="$title"
    for (( i=0; i<right_padding; i++ )); do
        padded_title+=" "
    done

    printf "%s" "$padded_title"
}

# Parse command-line arguments
while getopts ":t:" opt; do
    case $opt in
        t)
            report_title="$OPTARG"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Common Functions
cpu_info() {
    cpu_model="$(lscpu | grep 'Model name' | grep -v 'BIOS' | cut -f 2 -d ':' | awk '{print $1 " "  $2 " " $3}')"
    cpu_hypervisor="$(lscpu | grep 'Hypervisor vendor' | cut -f 2 -d ':' | awk '{$1=$1}1')"
    if [ -z "$cpu_hypervisor" ]; then
        cpu_hypervisor="Bare Metal"
    fi
    cpu_cores="$(nproc --all)"
    cpu_cores_per_socket="$(lscpu | grep 'Core(s) per socket' | cut -f 2 -d ':'| awk '{$1=$1}1')"
    cpu_sockets="$(lscpu | grep 'Socket(s)' | cut -f 2 -d ':' | awk '{$1=$1}1')"
    cpu_freq="$(grep 'cpu MHz' /proc/cpuinfo | cut -f 2 -d ':' | awk 'NR==1' | awk '{$1=$1}1' | numfmt --from-unit=M --to-unit=G --format %.2f)"

    load_avg_1min=$(uptime | awk -F'load average: ' '{print $2}' | cut -d ',' -f1 | tr -d ' ')
    load_avg_5min=$(uptime | awk -F'load average: ' '{print $2}' | cut -d ',' -f2 | tr -d ' ')
    load_avg_15min=$(uptime| awk -F'load average: ' '{print $2}' | cut -d ',' -f3 | tr -d ' ')

    cpu_1min_bar_graph=$(bar_graph "$load_avg_1min" "$cpu_cores")
    cpu_5min_bar_graph=$(bar_graph "$load_avg_5min" "$cpu_cores")
    cpu_15min_bar_graph=$(bar_graph "$load_avg_15min" "$cpu_cores")
}

memory_info() {
    mem_total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    mem_free_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    mem_used_kb=$((mem_total_kb - mem_free_kb))
    mem_total_gb=$(echo "scale=2; $mem_total_kb / 1024 / 1024" | bc)
    mem_used_gb=$(echo "scale=2; $mem_used_kb / 1024 / 1024" | bc)
    mem_percent=$(echo "scale=2; $mem_used_kb / $mem_total_kb * 100" | bc)
    mem_bar_graph=$(bar_graph "$mem_used_kb" "$mem_total_kb")
}

# OS-Specific Functions
debian_disk_info() {
    zfs_filesystem="zroot/ROOT/os"
    zfs_available=$( zfs get -o value -Hp available "$zfs_filesystem")
    zfs_used=$( zfs get -o value -Hp used "$zfs_filesystem")
    zfs_available_gb=$(echo "$zfs_available" | numfmt --to-unit=G --format %.2f)
    zfs_used_gb=$(echo "$zfs_used" | numfmt --to-unit=G --format %.2f)
    disk_percent=$(printf "%.2f" "$(echo "$zfs_used / $zfs_available * 100" | bc -l)")
    disk_bar_graph=$(bar_graph "$zfs_used" "$zfs_available")
}

arch_disk_info() {
    root_partition="/"
    root_used=$(df -m "$root_partition" | awk 'NR==2 {print $3}')
    root_total=$(df -m "$root_partition" | awk 'NR==2 {print $2}')
    root_total_gb=$(echo "scale=2; $root_total / 1024" | bc)
    root_used_gb=$(echo "scale=2; $root_used / 1024" | bc)
    disk_percent=$(printf "%.2f" "$(echo "$root_used / $root_total * 100" | bc -l)")
    disk_bar_graph=$(bar_graph "$root_used" "$root_total")
}

debian_last_login() {
    last_login=$(lastlog -u root)
    last_login_ip=$(echo "$last_login" | awk 'NR==2 {print $3}')
    last_login_time=$(echo "$last_login" | awk 'NR==2 {print $5, $6, $7, $8, $9}')
    last_login_formatted_time=$(date -d "$last_login_time" "+%b %-d %Y %T")
}

arch_last_login() {
    last_login=$(last -F | grep -v 'wtmp' | grep -m 1 -v reboot | head -n 1)
    last_login_time=$(echo "$last_login" | awk '{printf "%s %s %s %s", $5, $6, $8, $7}')
    last_login_ip=$(echo "$last_login" | awk '{print $3}')

    if [[ "$last_login_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # It's a valid IP address
        true
    elif [[ "$last_login_ip" =~ ^:[0-9]+$ ]]; then
        # It's a local display name like :1 or :0
        last_login_ip="Local"
    else
        # Handle unexpected cases
        last_login_ip="unknown"
    fi
}

# Set OS-Specific Variables
case "$os_type" in
    debian)
        os_name=$(source /etc/os-release; printf "%s %s %s" "${ID^}" "$(cat /etc/debian_version)" "${VERSION_CODENAME^}")
        os_kernel=$(uname -s -r)
        zfs_health=$(zpool status -x zroot | grep -q "is healthy" && echo "HEALTH O.K.")
        ;;
    arch)
        os_name=$(source /etc/os-release; printf "%s %s" "${ID^}" "${VERSION_CODENAME^}")
        os_kernel=$(uname -s -r)
        ;;
esac

# Network Information
net_current_user=$(whoami)
net_hostname=$(hostname -f)
# Network Information (continued)
net_machine_ip=$(ip addr show | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | head -n 1)
net_client_ip=$(who am i | awk '{print $5}' | tr -d '()')
# Check if the extracted IP is a valid IP address
if [[ "$net_client_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    # It's a valid IP address
    true
elif [[ "$net_client_ip" =~ ^:[0-9]+$ ]]; then
    # It's a local display name like :1 or :0
    net_client_ip="Local"
else
    # Handle unexpected cases
    net_client_ip="unknown"
fi

net_dns_ip=$(grep 'nameserver' /etc/resolv.conf | awk '{print $2}' | head -n 1)

# CPU Information
cpu_info

# Memory Information
memory_info

# Disk Information
case "$os_type" in
    debian) debian_disk_info ;;
    arch) arch_disk_info ;;
esac

# Last Login Information
case "$os_type" in
    debian) debian_last_login ;;
    arch) arch_last_login ;;
esac

# System Uptime
sys_uptime=$(uptime -p | sed 's/up\s*//; s/\s*day\(s*\)/d/; s/\s*hour\(s*\)/h/; s/\s*minute\(s*\)/m/')

# Print Machine Report
printf "┌┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┐\n"
printf "├┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┤\n"
printf "│ %s │\n" "$(pad_report_title "$report_title")"
printf "│            TR-100 MACHINE REPORT           │\n"
printf "├────────────┬───────────────────────────────┤\n"
printf "│ %-10s │ %-29s │\n" "OS" "$os_name"
printf "│ %-10s │ %-29s │\n" "KERNEL" "$os_kernel"
printf "├────────────┼───────────────────────────────┤\n"
printf "│ %-10s │ %-29s │\n" "HOSTNAME" "$net_hostname"
printf "│ %-10s │ %-29s │\n" "MACHINE IP" "$net_machine_ip"
printf "│ %-10s │ %-29s │\n" "CLIENT  IP" "$net_client_ip"
printf "│ %-10s │ %-29s │\n" "DNS     IP" "$net_dns_ip"
printf "│ %-10s │ %-29s │\n" "USER" "$net_current_user"
printf "├────────────┼───────────────────────────────┤\n"
printf "│ %-10s │ %-29s │\n" "PROCESSOR" "$cpu_model"
printf "│ %-10s │ %-29s │\n" "CORES" "$cpu_cores_per_socket vCPU(s) / $cpu_sockets Socket(s)"
printf "│ %-10s │ %-29s │\n" "HYPERVISOR" "$cpu_hypervisor"
printf "│ %-10s │ %-29s │\n" "CPU FREQ" "$cpu_freq GHz"
printf "│ %-10s │ %-29s │\n" "LOAD  1m" "$cpu_1min_bar_graph"
printf "│ %-10s │ %-29s │\n" "LOAD  5m" "$cpu_5min_bar_graph"
printf "│ %-10s │ %-29s │\n" "LOAD 15m" "$cpu_15min_bar_graph"
printf "├────────────┼───────────────────────────────┤\n"

if [ "$os_type" = "debian" ]; then
    printf "│ %-10s │ %-29s │\n" "VOLUME" "$zfs_used_gb/$zfs_available_gb GB [$disk_percent%]"
    printf "│ %-10s │ %-29s │\n" "DISK USAGE" "$disk_bar_graph"
    printf "│ %-10s │ %-29s │\n" "ZFS HEALTH" "$zfs_health"
else
    printf "│ %-10s │ %-29s │\n" "VOLUME" "$root_used_gb/$root_total_gb GB [$disk_percent%]"
    printf "│ %-10s │ %-29s │\n" "DISK USAGE" "$disk_bar_graph"
fi

printf "├────────────┼───────────────────────────────┤\n"
printf "│ %-10s │ %-29s │\n" "MEMORY" "${mem_used_gb}/${mem_total_gb} GiB [${mem_percent}%]"
printf "│ %-10s │ %-29s │\n" "USAGE" "${mem_bar_graph}"
printf "├────────────┼───────────────────────────────┤\n"

if [ "$os_type" = "debian" ]; then
    printf "│ %-10s │ %-29s │\n" "LAST LOGIN" "$last_login_formatted_time"
    printf "│ %-10s │ %-29s │\n" "" "$last_login_ip"
else
    printf "│ %-10s │ %-29s │\n" "LAST LOGIN" "$last_login_time"
    printf "│ %-10s │ %-29s │\n" "" "$last_login_ip"
fi

printf "│ %-10s │ %-29s │\n" "UPTIME" "$sys_uptime"
printf "└────────────┴───────────────────────────────┘\n"
