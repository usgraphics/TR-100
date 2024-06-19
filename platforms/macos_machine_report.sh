#!/bin/bash
# TR-100 Machine Report
# Copyright © 2024, U.S. Graphics, LLC. BSD-3-Clause License.

# Basic configuration, change as needed
report_title="UNITED STATES GRAPHICS COMPANY"
zfs_filesystem="zroot/ROOT/os"

# Utilities
bar_graph() {
    local percent
    local num_blocks
    local width=29
    local graph=""
    local used=$1
    local total=$2
    
    percent=$(printf "%.2f" "$(echo "$used / $total * 100" | bc -l)")
    num_blocks=$(echo "scale=2; ${percent}/100*${width}" | bc -l | awk '{printf "%d\n", $1}')
    for (( i = 0; i < num_blocks; i++ )); do
        graph+="█"
    done
    for (( i=0; i < width - num_blocks; i++ )); do
        graph+="░"
    done
    printf "%s" "${graph}"
}

# Operating System Information
os_name="$(sw_vers -productName) $(sw_vers -productVersion)"
os_kernel="$(uname -s) $(uname -r)"

# Network Information
net_current_user=$(whoami)
net_hostname=$(scutil --get LocalHostName)
net_machine_ip=$(ipconfig getifaddr en0)
net_client_ip=$(who -m | awk '{print $5}' | sed 's/[()]//g')
net_dns_ips=($(scutil --dns | grep 'nameserver\[[0-9]*\]' | awk '{print $3}'))

# CPU Information
cpu_model=$(sysctl -n machdep.cpu.brand_string)
cpu_cores=$(sysctl -n hw.ncpu)
cpu_cores_per_socket=$(sysctl -n machdep.cpu.cores_per_package)
cpu_sockets=$(sysctl -n machdep.cpu.packages 2>/dev/null || echo "N/A")
cpu_freq=$(sysctl -n hw.cpufrequency_max | awk '{print $1/1000000000}')
cpu_hypervisor="Not Available"

load_avg_1min=$(sysctl -n vm.loadavg | awk '{print $2}')
load_avg_5min=$(sysctl -n vm.loadavg | awk '{print $3}')
load_avg_15min=$(sysctl -n vm.loadavg | awk '{print $4}')

cpu_1min_bar_graph=$(bar_graph "$load_avg_1min" "$cpu_cores")
cpu_5min_bar_graph=$(bar_graph "$load_avg_5min" "$cpu_cores")
cpu_15min_bar_graph=$(bar_graph "$load_avg_15min" "$cpu_cores")

# Memory Information
mem_total=$(sysctl -n hw.memsize)
mem_used=$(vm_stat | grep 'Pages active' | awk '{print $3}' | sed 's/\.//') # in 4096-byte pages
mem_used=$((mem_used * 4096))
mem_available=$((mem_total - mem_used))
mem_percent=$(echo "$mem_used / $mem_total * 100" | bc -l)
mem_percent=$(printf "%.2f" "$mem_percent")
mem_total_gb=$(echo "$mem_total" | awk '{print $1/1024/1024/1024}')
mem_available_gb=$(echo "$mem_available" | awk '{print $1/1024/1024/1024}')
mem_used_gb=$(echo "$mem_used" | awk '{print $1/1024/1024/1024}')
mem_bar_graph=$(bar_graph "$mem_used" "$mem_total")

# Disk Information
disk_usage=$(df -H / | tail -1 | awk '{print $3 " " $2 " " $5}')
disk_used=$(echo $disk_usage | awk '{print $1}')
disk_total=$(echo $disk_usage | awk '{print $2}')
disk_percent=$(echo $disk_usage | awk '{print $3}' | tr -d '%')
disk_bar_graph=$(bar_graph "$disk_used" "$disk_total")

# Last login and Uptime
last_login=$(last -1 $net_current_user)
last_login_ip=$(echo "$last_login" | awk '{print $3}')
last_login_time=$(echo "$last_login" | awk '{print $4, $5, $6, $7}')
last_login_formatted_time=$(date -j -f "%a %b %d %T" "$last_login_time" "+%b %-d %Y %T" 2>/dev/null || echo "$last_login_time")
sys_uptime=$(uptime | awk -F'( |,|:)+' '{if ($6 ~ /day/) {print $5"d "$7"h "$8"m"} else {if ($5 ~ /min/) {print $5"m"} else {print $5"h "$6"m"}}}')

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
dns_ip_count=${#net_dns_ips[@]}
if [ "$dns_ip_count" -eq 1 ]; then
    printf "│ %-10s │ %-29s │\n" "DNS     IP" "${net_dns_ips[0]}"
else
    for ((i=0; i<$dns_ip_count; i++)); do
        if [ "$i" -eq 0 ]; then
            printf "│ %-10s │ %-29s │\n" "DNS IP/s 1" "${net_dns_ips[$i]}"
        else
            printf "│ %-10s │ %-29s │\n" "         $((i+1))" "${net_dns_ips[$i]}"
        fi
    done
fi
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
printf "│ %-10s │ %-29s │\n" "VOLUME" "$disk_used/$disk_total [$disk_percent%]"
printf "│ %-10s │ %-29s │\n" "DISK USAGE" "$disk_bar_graph"
printf "│ %-10s │ %-29s │\n" "ZFS HEALTH" "$zfs_health"
printf "├────────────┼───────────────────────────────┤\n"
printf "│ %-10s │ %-29s │\n" "MEMORY" "${mem_used_gb}/${mem_total_gb} GiB [${mem_percent}%]"
printf "│ %-10s │ %-29s │\n" "USAGE" "${mem_bar_graph}"
printf "├────────────┼───────────────────────────────┤\n"
printf "│ %-10s │ %-29s │\n" "LAST LOGIN" "$last_login_formatted_time"
printf "│ %-10s │ %-29s │\n" "" "$last_login_ip"
printf "│ %-10s │ %-29s │\n" "UPTIME" "$sys_uptime"
printf "└────────────┴───────────────────────────────┘\n"
