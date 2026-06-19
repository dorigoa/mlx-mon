#!/usr/bin/env bash
set -euo pipefail

interval=1
metric="xmit"
while getopts "i:m:" opt; do
  case $opt in
    i) interval=$OPTARG ;;
    m) metric=$OPTARG ;;
    *) echo "Uso: $0 [-i seconds] [-m xmit|rcv] dev[:port] [dev[:port] ...]" >&2
       echo "  -m xmit  transmission (default)" >&2
       echo "  -m rcv  receive" >&2; exit 1 ;;
  esac
done
shift $((OPTIND-1))

[[ $# -ge 1 ]] || {
  echo "Specify at least one device. E.g.: $0 -i 2 -m rcv mlx5_1 mlx5_3:1" >&2; exit 1
}

case "$metric" in
  xmit|rcv) ;;
  *) echo "Unknown metrics: $metric (use xmit|rcv)" >&2; exit 1 ;;
esac

# Costruzione percorsi e label
declare -a paths labels
for t in "$@"; do
  dev=${t%%:*}
  port=${t#*:}; [[ "$port" == "$t" ]] && port=1   # default port 1
  p="/sys/class/infiniband/$dev/ports/$port/counters/port_${metric}_data"
  [[ -r "$p" ]] || { echo "Unreadable counter: $p" >&2; exit 1; }
  paths+=("$p"); labels+=("$dev:$port")
done

declare -a prev
for i in "${!paths[@]}"; do prev[$i]=$(<"${paths[$i]}"); done

printf '%-10s' "time"
for l in "${labels[@]}"; do printf ' %14s' "$l"; done; printf '\n'
printf '%-10s' ""
for _ in "${labels[@]}"; do printf ' %14s' "(Gb/s)"; done; printf '\n'

# Loop
while sleep "$interval"; do
  printf '%-10s' "$(date +%T)"
  for i in "${!paths[@]}"; do
    cur=$(<"${paths[$i]}")
    awk -v p="${prev[$i]}" -v c="$cur" -v dt="$interval" \
        'BEGIN{ printf " %14.3f", (c-p)*4*8/dt/1e9 }'
    prev[$i]=$cur
  done
  printf '\n'
done
