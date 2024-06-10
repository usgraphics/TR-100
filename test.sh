#!/bin/bash

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
# mem_bar_graph=$(bar_graph "$mem_used" "$mem_total")


total=$(echo "scale=2; $mem_total / 1024 / 1024 / 1024" | bc)
echo "total memory: $total GB"

total=$(echo "scale=2; $mem_available / 1024 / 1024 / 1024" | bc)
echo "Memory avail: $total GB"

echo "Memory percentage $mem_percent"
mem_percent=$(printf "%.2f" "$mem_percent")
echo "Memory percentage $mem_percent"