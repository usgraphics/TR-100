#!/bin/bash
# TR-100 Machine Report
# Copyright © 2024, U.S. Graphics, LLC. BSD-3-Clause License.

# Basic configuration, change as needed
report_title="UNITED STATES GRAPHICS COMPANY"
last_login_ip_present=0
zfs_present=0
zfs_filesystem="zroot/ROOT/os"

# Utilities
bar_graph() {
    local percent
    local num_blocks
    local width=29
    local graph=""
    local used=$1
    local total=$2

    if (( total == 0 )); then
        percent=0
    else
        percent=$(awk -v used="$used" -v total="$total" 'BEGIN { printf "%.2f", (used / total) * 100 }')
    fi

    num_blocks=$(awk -v percent="$percent" -v width="$width" 'BEGIN { printf "%d", (percent / 100) * width }')

    for (( i = 0; i < num_blocks; i++ )); do
        graph+="█"
    done
    for (( i = num_blocks; i < width; i++ )); do
        graph+="░"
    done
    printf "%s" "${graph}"
}

get_ip_addr() {
    # Initialize variables
    ipv4_address=""
    ipv6_address=""

    # Check if ifconfig command exists
    if command -v ifconfig &> /dev/null; then
        # Try to get IPv4 address using ifconfig
        ipv4_address=$(ifconfig | awk '
            /^[a-z]/ {iface=$1}
            iface != "lo:" && iface !~ /^docker/ && /inet / && !found_ipv4 {found_ipv4=1; print $2}')

        # If IPv4 address not available, try IPv6 using ifconfig
        if [ -z "$ipv4_address" ]; then
            ipv6_address=$(ifconfig | awk '
                /^[a-z]/ {iface=$1}
                iface != "lo:" && iface !~ /^docker/ && /inet6 / && !found_ipv6 {found_ipv6=1; print $2}')
        fi
    elif command -v ip &> /dev/null; then
        # Try to get IPv4 address using ip addr
        ipv4_address=$(ip -o -4 addr show | awk '
            $2 != "lo" && $2 !~ /^docker/ {split($4, a, "/"); if (!found_ipv4++) print a[1]}')

        # If IPv4 address not available, try IPv6 using ip addr
        if [ -z "$ipv4_address" ]; then
            ipv6_address=$(ip -o -6 addr show | awk '
                $2 != "lo" && $2 !~ /^docker/ {split($4, a, "/"); if (!found_ipv6++) print a[1]}')
        fi
    fi

    # If neither IPv4 nor IPv6 address is available, assign "No IP found"
    if [ -z "$ipv4_address" ] && [ -z "$ipv6_address" ]; then
        ip_address="No IP found"
    else
        # Prioritize IPv4 if available, otherwise use IPv6
        ip_address="${ipv4_address:-$ipv6_address}"
    fi

    printf '%s' "$ip_address"
}

# Operating System Information
source /etc/os-release
os_name="${ID^} ${VERSION} ${VERSION_CODENAME^}"
os_kernel=$({ uname; uname -r; } | tr '\n' ' ')

# Network Information
net_current_user=$(whoami)
if ! [ "$(command -v hostname)" ]; then
    net_hostname=$(grep -w "$(uname -n)" /etc/hosts | awk '{print $2}' | head -n 1)
else
    net_hostname=$(hostname -f)
fi

if [ -z "$net_hostname" ]; then net_hostname="Not Defined"; fi

net_machine_ip=$(get_ip_addr)
net_client_ip=$(who am i | awk '{print $5}' | tr -d '()')
net_dns_ip=($(grep '^nameserver [0-9.]' /etc/resolv.conf | awk '{print $2}'))

# CPU Information
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

# Memory Information
mem_total=$(grep 'MemTotal' /proc/meminfo | awk '{print $2}')
mem_available=$(grep 'MemAvailable' /proc/meminfo | awk '{print $2}')
mem_used=$((mem_total - mem_available))
mem_percent=$(awk -v used="$mem_used" -v total="$mem_total" 'BEGIN { printf "%.2f", (used / total) * 100 }')
mem_percent=$(printf "%.2f" "$mem_percent")
mem_total_gb=$(echo "$mem_total" | numfmt --from-unit=Ki --to-unit=Gi --format %.2f)
mem_available_gb=$(echo "$mem_available" | numfmt --from-unit=Ki --to-unit=Gi --format %.2f) # Not used currently
mem_used_gb=$(echo "$mem_used" | numfmt  --from-unit=Ki --to-unit=Gi --format %.2f)
mem_bar_graph=$(bar_graph "$mem_used" "$mem_total")

# Disk Information
if [ "$(command -v zfs)" ] && [ "$(grep -q "zfs" /proc/mounts)" ]; then
    zfs_present=1
    zfs_health=$(zpool status -x zroot | grep -q "is healthy" && echo  "HEALTH O.K.")
    zfs_available=$(zfs get -o value -Hp available "$zfs_filesystem")
    zfs_used=$(zfs get -o value -Hp used "$zfs_filesystem")
    zfs_available_gb=$(echo "$zfs_available" | numfmt --to-unit=G --format %.2f)
    zfs_used_gb=$(echo "$zfs_used" | numfmt --to-unit=G --format %.2f)
    disk_percent=$(awk -v used="$zfs_used" -v available="$zfs_available" 'BEGIN { printf "%.2f", (used / available) * 100 }')
    disk_bar_graph=$(bar_graph "$zfs_used" "$zfs_available")
else
    # Thanks https://github.com/AnarchistHoneybun
    root_partition="/"
    root_used=$(df -m "$root_partition" | awk 'NR==2 {print $3}')
    root_total=$(df -m "$root_partition" | awk 'NR==2 {print $2}')
    root_total_gb=$(awk -v total="$root_total" 'BEGIN { printf "%.2f", total / 1024 }')
    root_used_gb=$(awk -v used="$root_used" 'BEGIN { printf "%.2f", used / 1024 }')
    disk_percent=$(awk -v used="$root_used" -v total="$root_total" 'BEGIN { printf "%.2f", (used / total) * 100 }')
    disk_bar_graph=$(bar_graph "$root_used" "$root_total")
fi

# Last login and Uptime
last_login=$(lastlog -u "$USER")
last_login_ip=$(echo "$last_login" | awk 'NR==2 {print $3}')

# Check if last_login_ip is an IP address
if [[ "$last_login_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    last_login_ip_present=1
    last_login_time=$(echo "$last_login" | awk 'NR==2 {print $5, $6, $7, $8, $9}')
else
    last_login_time=$(echo "$last_login" | awk 'NR==2 {print $3, $4, $5, $6, $7}')
fi

last_login_formatted_time=$(date -d "$last_login_time" "+%b %-d %Y %T")
sys_uptime=$(uptime -p | sed 's/up\s*//; s/\s*day\(s*\)/d/; s/\s*hour\(s*\)/h/; s/\s*minute\(s*\)/m/')

# Machine Report
printf "┌┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┐\n"
printf "├┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┤\n"
printf "│       %s       │\n" "$report_title"
printf "│            TR-100 MACHINE REPORT           │\n"
printf "├────────────┬───────────────────────────────┤\n"
printf "│ %-10s │ %-29s │\n" "OS" "$os_name"
printf "│ %-10s │ %-29s │\n" "KERNEL" "$os_kernel"
printf "├────────────┼───────────────────────────────┤\n"
printf "│ %-10s │ %-29s │\n" "HOSTNAME" "$net_hostname"
printf "│ %-10s │ %-29s │\n" "MACHINE IP" "$net_machine_ip"
printf "│ %-10s │ %-29s │\n" "CLIENT  IP" "$net_client_ip"

# Sometimes we have multiple dns IPs
for dns_num in "${!net_dns_ip[@]}"; do
    printf "│ %-10s │ %-29s │\n" "DNS  IP $(($dns_num + 1))" "${net_dns_ip[dns_num]}"
done

printf "│ %-10s │ %-29s │\n" "USER" "$net_current_user"
printf "├────────────┼───────────────────────────────┤\n"
printf "│ %-10s │ %-29s │\n" "PROCESSOR" "$cpu_model"
printf "│ %-10s │ %-29s │\n" "CORES" "$cpu_cores_per_socket vCPU(s) / $cpu_sockets Socket(s)"
printf "│ %-10s │ %-29s │\n" "HYPERVISOR" "$cpu_hypervisor"
printf "│ %-10s │ %-29s │\n" "CPU FREQ" "$cpu_freq GHz"
printf "│ %-10s │ %-29s │\n" "LOAD  1m" "$cpu_1min_bar_graph"
printf "│ %-10s │ %-29s │\n" "LOAD  5m" "$cpu_5min_bar_graph"
printf "│ %-10s │ %-29s │\n" "LOAD 15m" "$cpu_15min_bar_graph"

if [ $zfs_present -eq 1 ]; then
    printf "├────────────┼───────────────────────────────┤\n"
    printf "│ %-10s │ %-29s │\n" "VOLUME" "$zfs_used_gb/$zfs_available_gb GB [$disk_percent%]"
    printf "│ %-10s │ %-29s │\n" "DISK USAGE" "$disk_bar_graph"
    printf "│ %-10s │ %-29s │\n" "ZFS HEALTH" "$zfs_health"
else
    printf "├────────────┼───────────────────────────────┤\n"
    printf "│ %-10s │ %-29s │\n" "VOLUME" "$root_used_gb/$root_total_gb GB [$disk_percent%]"
    printf "│ %-10s │ %-29s │\n" "DISK USAGE" "$disk_bar_graph"
fi

printf "├────────────┼───────────────────────────────┤\n"
printf "│ %-10s │ %-29s │\n" "MEMORY" "${mem_used_gb}/${mem_total_gb} GiB [${mem_percent}%]"
printf "│ %-10s │ %-29s │\n" "USAGE" "${mem_bar_graph}"
printf "├────────────┼───────────────────────────────┤\n"
printf "│ %-10s │ %-29s │\n" "LAST LOGIN" "$last_login_formatted_time"

if [ $last_login_ip_present -eq 1 ]; then
    printf "│ %-10s │ %-29s │\n" "" "$last_login_ip"
fi

printf "│ %-10s │ %-29s │\n" "UPTIME" "$sys_uptime"
printf "└────────────┴───────────────────────────────┘\n"
