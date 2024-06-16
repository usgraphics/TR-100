#!/bin/bash
# TR-100 Machine Report
# Copyright © 2024, U.S. Graphics, LLC. BSD-3-Clause License.

# Basic configuration, change as needed
report_title="UNITED STATES GRAPHICS COMPANY"
zfs_filesystem="zroot/ROOT/os"

# Operating System Information
source /etc/os-release
os_name="${ID^} $(cat /etc/debian_version) ${VERSION_CODENAME^}"
os_kernel=$({ uname; uname -r; } | tr '\n' ' ')

# Network Information
net_current_user=$(whoami)
net_hostname=$(hostname -f)
net_machine_ip=$(hostname -I)
net_client_ip=$(who am i --ips | awk '{print $5}')
net_dns_ips=()
while read -r line; do
    ip=$(echo "$line" | awk '{print $2}')
    net_dns_ips+=("$ip")
done < <(grep 'nameserver' /etc/resolv.conf)

# CPU Information
cpu_model="$(lscpu | grep 'Model name' | grep -v 'BIOS' | cut -f 2 -d ':' | awk '{print $1 " "  $2 " " $3}')"
cpu_hypervisor="$(lscpu | grep 'Hypervisor vendor' | cut -f 2 -d ':' | awk '{$1=$1}1')"
cpu_cores="$(nproc --all)"
cpu_cores_per_socket="$(lscpu | grep 'Core(s) per socket' | cut -f 2 -d ':'| awk '{$1=$1}1')"
cpu_sockets="$(lscpu | grep 'Socket(s)' | cut -f 2 -d ':' | awk '{$1=$1}1')"
cpu_freq="$(grep 'cpu MHz' /proc/cpuinfo | cut -f 2 -d ':' | awk 'NR==1' | awk '{$1=$1}1' | numfmt --from-unit=M --to-unit=G --format %.2f)"

load_avg_1min=$(uptime | awk -F'load average: ' '{print $2}' | cut -d ',' -f1 | tr -d ' ')
load_avg_5min=$(uptime | awk -F'load average: ' '{print $2}' | cut -d ',' -f2 | tr -d ' ')
load_avg_15min=$(uptime| awk -F'load average: ' '{print $2}' | cut -d ',' -f3 | tr -d ' ')

# Memory Information
mem_total=$(grep 'MemTotal' /proc/meminfo | awk '{print $2}')
mem_available=$(grep 'MemAvailable' /proc/meminfo | awk '{print $2}')
mem_used=$((mem_total - mem_available))
mem_percent=$(echo "$mem_used / $mem_total * 100" | bc -l)
mem_percent=$(printf "%.2f" "$mem_percent")
mem_total_gb=$(echo "$mem_total" | numfmt --from-unit=Ki --to-unit=Gi --format %.2f)
mem_available_gb=$(echo "$mem_available" | numfmt --from-unit=Ki --to-unit=Gi --format %.2f) # Not used currently
mem_used_gb=$(echo "$mem_used" | numfmt  --from-unit=Ki --to-unit=Gi --format %.2f)

# Disk Information
# TODO: Add checks if zfs file system exists
# WARNING: This script assumes that the zfs file system is located at $zfs_filesystem
zfs_health=$(zpool status -x zroot | grep -q "is healthy" && echo  "HEALTH O.K.")
zfs_available=$( zfs get -o value -Hp available "$zfs_filesystem")
zfs_used=$( zfs get -o value -Hp used "$zfs_filesystem")
zfs_available_gb=$(echo "$zfs_available" | numfmt --to-unit=G --format %.2f)
zfs_used_gb=$(echo "$zfs_used" | numfmt --to-unit=G --format %.2f)
disk_percent=$(printf "%.2f" "$(echo "$zfs_used / $zfs_available * 100" | bc -l)")

# Last login and Uptime
last_login=$(lastlog -u root)
last_login_ip=$(echo "$last_login" | awk 'NR==2 {print $3}')
last_login_time=$(echo "$last_login" | awk 'NR==2 {print $5, $6, $7, $8, $9}')
last_login_formatted_time=$(date -d "$last_login_time" "+%b %-d %Y %T")
sys_uptime=$(uptime -p | sed 's/up\s*//; s/\s*day\(s*\)/d/; s/\s*hour\(s*\)/h/; s/\s*minute\(s*\)/m/')

# Report printing functions
function print_divider {
    local width="$1"
    local left_col="$2"
    local left_char="$3"
    local split_char="$4"
    local fill_char="$5"
    local right_char="$6"
    printf "%s%*s%s%*s\n" "$left_char" "$left_col" "" "$split_char" $((width - left_col)) "$right_char" | tr ' ' "$fill_char"
}

function print_header {
    local width="$1"
    local left_col="$2"
    local title="$3"
    local padding=$((width - ${#title} - 4))
    local left_padding=$((padding / 2))
    local right_padding=$((padding - left_padding))
    printf "│%*s%s%*s│\n" $((left_padding + 1)) "" "$title" $((right_padding + 1)) ""
    printf "│%*s%s%*s│\n" $((width/2 - 11)) "" "TR-100 MACHINE REPORT" $((width/2 - $([ $((width % 2)) -ne 0 ] && echo 11 || echo 12))) ""
}

function print_entry {
    local width="$1"
    local left_col=$((${2} - 2))
    printf "│ %-${left_col}s │ %-$((width - left_col - 7))s │" "$3" "$4" | tr '\n' '    '
    printf "\n"
}

# Determine the correct width
left_column_width=12

function max_length {
    local max_len=0
    for entry in "$@"; do
        local len=${#entry}
        if (( len > max_len )); then
            max_len=$len
        fi
    done
    echo "$max_len"
}

entries=(
    "$os_name" "$os_kernel"
    "$net_hostname" "$net_machine_ip" "$net_client_ip" "$net_dns_ip" "$net_current_user"
    "$cpu_model" "$cpu_cores_per_socket vCPU(s) / $cpu_sockets Socket(s)" "$cpu_hypervisor" "$cpu_freq GHz"
    "$zfs_used_gb/$zfs_available_gb GB [$disk_percent%]" "$zfs_health"
    "${mem_used_gb}/${mem_total_gb} GiB [${mem_percent}%]"
    "$last_login_formatted_time" "$last_login_ip" "$sys_uptime"
)
max_entry_length=$(max_length "${entries[@]}")
width=$((max_entry_length+left_column_width+5))

# Bar graphs
function bar_graph {
    local percent
    local num_blocks
    local left_col=$2
    local width=$((${1}-left_col-5))
    local graph=""
    local used=$3
    local total=$4
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
cpu_1min_bar_graph=$(bar_graph "$width" "$left_column_width" "$load_avg_1min" "$cpu_cores")
cpu_5min_bar_graph=$(bar_graph "$width" "$left_column_width" "$load_avg_5min" "$cpu_cores")
cpu_15min_bar_graph=$(bar_graph "$width" "$left_column_width" "$load_avg_15min" "$cpu_cores")
disk_bar_graph=$(bar_graph "$width" "$left_column_width" "$zfs_used" "$zfs_available")
mem_bar_graph=$(bar_graph "$width" "$left_column_width" "$mem_used" "$mem_total")

# Machine Report
print_divider   "$width" "$left_column_width" "┌" "┬" "┬" "┐"
print_divider   "$width" "$left_column_width" "├" "┴" "┴" "┤"
print_header    "$width" "$left_column_width" "$report_title"
print_divider   "$width" "$left_column_width" "├" "┬" "─" "┤"
print_entry     "$width" "$left_column_width" "OS" "$os_name"
print_entry     "$width" "$left_column_width" "KERNEL" "$os_kernel"
print_divider   "$width" "$left_column_width" "├" "┼" "─" "┤"
print_entry     "$width" "$left_column_width" "HOSTNAME" "$net_hostname"
print_entry     "$width" "$left_column_width" "MACHINE IP" "$net_machine_ip"
print_entry     "$width" "$left_column_width" "CLIENT  IP" "$net_client_ip"
print_entry     "$width" "$left_column_width" "DNS     IP" "$net_dns_ip"
print_entry     "$width" "$left_column_width" "USER" "$net_current_user"
print_divider   "$width" "$left_column_width" "├" "┼" "─" "┤"
print_entry     "$width" "$left_column_width" "PROCESSOR" "$cpu_model"
print_entry     "$width" "$left_column_width" "CORES" "$cpu_cores_per_socket vCPU(s) / $cpu_sockets Socket(s)"
print_entry     "$width" "$left_column_width" "HYPERVISOR" "$cpu_hypervisor"
print_entry     "$width" "$left_column_width" "CPU FREQ" "$cpu_freq GHz"
print_entry     "$width" "$left_column_width" "LOAD  1m" "$cpu_1min_bar_graph"
print_entry     "$width" "$left_column_width" "LOAD  5m" "$cpu_5min_bar_graph"
print_entry     "$width" "$left_column_width" "LOAD 15m" "$cpu_15min_bar_graph"
print_divider   "$width" "$left_column_width" "├" "┼" "─" "┤"
print_entry     "$width" "$left_column_width" "VOLUME" "$zfs_used_gb/$zfs_available_gb GB [$disk_percent%]"
print_entry     "$width" "$left_column_width" "DISK USAGE" "$disk_bar_graph"
print_entry     "$width" "$left_column_width" "ZFS HEALTH" "$zfs_health"
print_divider   "$width" "$left_column_width" "├" "┼" "─" "┤"
print_entry     "$width" "$left_column_width" "MEMORY" "${mem_used_gb}/${mem_total_gb} GiB [${mem_percent}%]"
print_entry     "$width" "$left_column_width" "USAGE" "$mem_bar_graph"
print_divider   "$width" "$left_column_width" "├" "┼" "─" "┤"
print_entry     "$width" "$left_column_width" "LAST LOGIN" "$last_login_formatted_time"
print_entry     "$width" "$left_column_width" "" "$last_login_ip"
print_entry     "$width" "$left_column_width" "UPTIME" "$sys_uptime"
print_divider   "$width" "$left_column_width" "└" "┴" "─" "┘"
