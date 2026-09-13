#!/bin/bash
set -Eeuo pipefail

cd /home/container

startup_command="${STARTUP:-/usr/local/bin/pterodactyl-haproxy}"
haproxy -v
printf '\033[1;36m[HAProxy]\033[0m Startup: %s\n' "${startup_command}"

exec /bin/bash -c "${startup_command}"
