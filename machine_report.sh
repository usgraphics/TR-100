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
    num_blocks=$(echo "scale=2; ${percent}/100*${width}" | bc -l | numfmt --from=iec --format %.0f)
    for (( i = 0; i < num_blocks; i++ )); do
        graph+="▒" # This medium shade works better for me and my font (MesloLGL nerd font mono)
    done
    for (( i=0; i < width - num_blocks; i++ )); do
        graph+="░"
    done
    printf "%s" "${graph}"
}

# Operating System Information
if [ "$(uname)" == "Linux" ]; then
    source /etc/os-release
    os_name="${ID^} $(cat /etc/debian_version) ${VERSION_CODENAME^}"
    os_kernel=$({ uname; uname -r; } | tr '\n' ' ')
elif [ "$(uname)" == "Darwin" ]; then # MACOS specific
    ID=$(sw_vers | grep 'ProductName' | cut -d: -f2 | xargs)
    VERSION_CODE=$(sw_vers | grep 'ProductVersion' | cut -d: -f2 | xargs)
    # Couldnt for the life of me find a plist file where sonoma is mentions so for now its hardcoded
    os_name="${ID} ${VERSION_CODE} Sonoma"
    os_kernel=$({ uname; uname -r; uname -m; } | tr '\n' ' ')
fi

# Network Information
if [ "$(uname)" == "Linux" ]; then
    net_current_user=$(whoami)
    net_hostname=$(hostname -f)
    net_machine_ip=$(hostname -I)
    net_client_ip=$(who am i --ips | awk '{print $5}')
    net_dns_ip=$(grep 'nameserver' /etc/resolv.conf | awk '{print $2}')
elif [ "$(uname)" == "Darwin" ]; then # MACOS specific
    net_current_user=$(whoami)
    net_hostname=$(hostname -f)
    net_machine_ip=$(ipconfig getifaddr en0)
    net_client_ip=$(who -m | awk '{print $5}')
    net_dns_ip=$(grep 'nameserver' /etc/resolv.conf | awk '{print $2}')
fi

# CPU Information
if [ "$(uname)" == "Linux" ]; then
    cpu_model="$(lscpu | grep 'Model name' | grep -v 'BIOS' | cut -f 2 -d ':' | awk '{print $1 " "  $2 " " $3}')"
    cpu_hypervisor="$(lscpu | grep 'Hypervisor vendor' | cut -f 2 -d ':' | awk '{$1=$1}1')"
    cpu_cores="$(nproc --all)"
    cpu_cores_per_socket="$(lscpu | grep 'Core(s) per socket' | cut -f 2 -d ':'| awk '{$1=$1}1')"
    cpu_sockets="$(lscpu | grep 'Socket(s)' | cut -f 2 -d ':' | awk '{$1=$1}1')"
    cpu_freq="$(grep 'cpu MHz' /proc/cpuinfo | cut -f 2 -d ':' | awk 'NR==1' | awk '{$1=$1}1' | numfmt --from-unit=M --to-unit=G --format %.2f)"
elif [ "$(uname)" == "Darwin" ]; then # MACOS specific
    cpu_model="$(sysctl -n machdep.cpu.brand_string)"
    cpu_cores="$(sysctl -n machdep.cpu.core_count)"
    cpu_preformance_cores="$(sysctl -n hw.perflevel0.physicalcpu)"
    cpu_efficientcy_cores="$(sysctl -n hw.perflevel1.physicalcpu)"
    # Finding the frequency is a pain in the ass
    # Apple stopped supporting the sysctl -n hw.cpufrequency command for their new apple silicon chips
    # you can get the metrics with the `powermetrics` command but that needs to be ran as sudo
    # And for a specific time interval...
    # cpu_freq="$(sysctl -n hw.cpufrequency | awk '{print $1/1000000000 }')"

    # I can check if a hypervisor is enabled but to get the specific vendor IDEK
    if [ "$(sysctl -n kern.hv_vmm_present)" -eq 1 ]; then
        cpu_hypervisor="Hypervisor support is enabled"
    else
        cpu_hypervisor="Hypervisor is not enabled."
    fi
fi


if [ "$(uname)" == "Linux" ]; then
    load_avg_1min=$(uptime | awk -F'load average: ' '{print $2}' | cut -d ',' -f1 | tr -d ' ')
    load_avg_5min=$(uptime | awk -F'load average: ' '{print $2}' | cut -d ',' -f2 | tr -d ' ')
    load_avg_15min=$(uptime| awk -F'load average: ' '{print $2}' | cut -d ',' -f3 | tr -d ' ')
elif [ "$(uname)" == "Darwin" ]; then # MACOS specific
    load_avg_1min=$(uptime | grep -o 'load averages: .*' | awk '{print $3}')
    load_avg_5min=$(uptime | grep -o 'load averages: .*' | awk '{print $4}')
    load_avg_15min=$(uptime | grep -o 'load averages: .*' | awk '{print $5}')
fi

cpu_1min_bar_graph=$(bar_graph "$load_avg_1min" "$cpu_cores")
cpu_5min_bar_graph=$(bar_graph "$load_avg_5min" "$cpu_cores")
cpu_15min_bar_graph=$(bar_graph "$load_avg_15min" "$cpu_cores")

# Memory Information
if [ "$(uname)" == "Linux" ]; then
    mem_total=$(grep 'MemTotal' /proc/meminfo | awk '{print $2}')
    mem_available=$(grep 'MemAvailable' /proc/meminfo | awk '{print $2}')
    mem_used=$((mem_total - mem_available))
    mem_percent=$(echo "$mem_used / $mem_total * 100" | bc -l)
    mem_percent=$(printf "%.2f" "$mem_percent")
    mem_total_gb=$(echo "$mem_total" | numfmt --from-unit=Ki --to-unit=Gi --format %.2f)
    mem_available_gb=$(echo "$mem_available" | numfmt --from-unit=Ki --to-unit=Gi --format %.2f) # Not used currently
    mem_used_gb=$(echo "$mem_used" | numfmt  --from-unit=Ki --to-unit=Gi --format %.2f)
    mem_bar_graph=$(bar_graph "$mem_used" "$mem_total")
elif [ "$(uname)" == "Darwin" ]; then # MACOS specific
    mem_total=$(sysctl -n hw.memsize) # in bytes
    pages_free=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    pages_inactive=$(vm_stat | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')
    page_size=$(vm_stat | grep "page size of" | awk '{print $8}') # in bytes

    mem_available=$(( (pages_free + pages_inactive) * page_size)) # in bytes
    mem_used=$((mem_total - mem_available)) # in bytes


    mem_percent=$(echo "$mem_used / $mem_total * 100" | bc -l) 
    mem_percent=$(printf "%.2f" "$mem_percent")

    mem_total_gb=$(echo "scale=2; $mem_total / 1024 / 1024 / 1024" | bc)
    mem_available_gb=$(echo "scale=2; $mem_available / 1024 / 1024 / 1024" | bc) # Not used currently
    mem_used_gb=$(echo "scale=2; $mem_used / 1024 / 1024 / 1024" | bc)
    mem_bar_graph=$(bar_graph "$mem_used" "$mem_total")
fi

# Disk Information
# TODO: Add checks if zfs file system exists
# WARNING: This script assumes that the zfs file system is located at $zfs_filesystem
if [ "$(uname)" == "Linux" ]; then
    zfs_health=$(zpool status -x zroot | grep -q "is healthy" && echo  "HEALTH O.K.")
    zfs_available=$( zfs get -o value -Hp available "$zfs_filesystem")
    zfs_used=$( zfs get -o value -Hp used "$zfs_filesystem")
    zfs_available_gb=$(echo "$zfs_available" | numfmt --to-unit=G --format %.2f)
    zfs_used_gb=$(echo "$zfs_used" | numfmt --to-unit=G --format %.2f)
    disk_percent=$(printf "%.2f" "$(echo "$zfs_used / $zfs_available * 100" | bc -l)")
    disk_bar_graph=$(bar_graph "$zfs_used" "$zfs_available")
elif [ "$(uname)" == "Darwin" ]; then # MACOS specific
    apfs_available=$( diskutil apfs list | grep "Size (Capacity Ceiling): .*" | sed -n 's/.*(\(.*\)).*/\1/p')
    apfs_used=$( diskutil apfs list | grep "Capacity In Use By Volumes: .*" | sed -n 's/.*(\(.* GB\)).*/\1/p')
    disk_percent=$(diskutil apfs list | grep "Capacity In Use By Volumes: .*" | sed -n 's/.*(\(.*\))/\1/p' | awk '{print $1}')

    apfs_available_num=$( echo $apfs_available | awk '{print $1 * 1024}')
    apfs_used_num=$( echo $apfs_used | awk '{print $1}')
    disk_bar_graph=$(bar_graph "$apfs_used_num" "$apfs_available_num")
fi

# Last login and Uptime
if [ "$(uname)" == "Linux" ]; then
    last_login=$(lastlog -u root)
    last_login_ip=$(echo "$last_login" | awk 'NR==2 {print $3}')
    last_login_time=$(echo "$last_login" | awk 'NR==2 {print $5, $6, $7, $8, $9}')
    last_login_formatted_time=$(date -d "$last_login_time" "+%b %-d %Y %T")
    sys_uptime=$(uptime -p | sed 's/up\s*//; s/\s*day\(s*\)/d/; s/\s*hour\(s*\)/h/; s/\s*minute\(s*\)/m/')
elif [ "$(uname)" == "Darwin" ]; then # MACOS specific
    last_login=$(last $USER | head -n 1) 
    last_login_ip=$(echo "$last_login" | awk '{print $3}')
    last_login_time=$(echo "$last_login" | awk '{print $4, $5, $6, $7}')
    last_login_formatted_time=$(date -j -f "%a %b %d %H:%M" "$last_login_time" "+%b %-d %Y %T")
    sys_uptime=$(system_profiler SPSoftwareDataType -detailLevel mini | grep "Time since boot" | awk -F': ' '{print $2}')
fi

# Machine Report
if [ "$(uname)" == "Linux" ]; then
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
    printf "│ %-10s │ %-29s │\n" "VOLUME" "$zfs_used_gb/$zfs_available_gb GB [$disk_percent%]"
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

elif [ "$(uname)" == "Darwin" ]; then # MACOS specific
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
    printf "│ %-10s │ %-29s │\n" "DNS     IP" "$net_dns_ip"
    printf "│ %-10s │ %-29s │\n" "USER" "$net_current_user"
    printf "├────────────┼───────────────────────────────┤\n"
    printf "│ %-10s │ %-29s │\n" "PROCESSOR" "$cpu_model"
    printf "│ %-10s │ %-29s │\n" "HYPERVISOR" "$cpu_hypervisor"
    printf "│ %-10s │ %-29s │\n" "CORES" "$cpu_cores CPU(s)"
    printf "│ %-10s │ %-29s │\n" "PERF" "$cpu_preformance_cores CPU(s)"
    printf "│ %-10s │ %-29s │\n" "EFF" "$cpu_efficientcy_cores  CPU(s)"
    printf "│ %-10s │ %-29s │\n" "LOAD  1m" "$cpu_1min_bar_graph"
    printf "│ %-10s │ %-29s │\n" "LOAD  5m" "$cpu_5min_bar_graph"
    printf "│ %-10s │ %-29s │\n" "LOAD 15m" "$cpu_15min_bar_graph"
    printf "├────────────┼───────────────────────────────┤\n"
    printf "│ %-10s │ %-29s │\n" "VOLUME" "$apfs_used/$apfs_available GB [$disk_percent]"
    printf "│ %-10s │ %-29s │\n" "DISK USAGE" "$disk_bar_graph"
    printf "├────────────┼───────────────────────────────┤\n"
    printf "│ %-10s │ %-29s │\n" "MEMORY" "${mem_used_gb}/${mem_total_gb} GiB [${mem_percent}%]"
    printf "│ %-10s │ %-29s │\n" "USAGE" "${mem_bar_graph}"
    printf "├────────────┼───────────────────────────────┤\n"
    printf "│ %-10s │ %-29s │\n" "LAST LOGIN" "$last_login_formatted_time"
    printf "│ %-10s │ %-29s │\n" "" "$last_login_ip"
    printf "│ %-10s │ %-29s │\n" "UPTIME" "$sys_uptime"
    printf "└────────────┴───────────────────────────────┘\n"
fi
