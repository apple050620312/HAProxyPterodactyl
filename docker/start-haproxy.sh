#!/bin/bash
set -Eeuo pipefail

readonly config_file="/home/container/haproxy.cfg"

fail() {
    printf '[HAProxy] ERROR: %s\n' "$*" >&2
    exit 1
}

require_integer() {
    local name="$1"
    local value="$2"
    local minimum="$3"
    local maximum="$4"

    [[ "${value}" =~ ^[0-9]+$ ]] || fail "${name} must be an integer."
    (( 10#${value} >= minimum && 10#${value} <= maximum )) || fail "${name} must be between ${minimum} and ${maximum}."
}

readonly config_mode="${CONFIG_MODE:-generated}"

case "${config_mode}" in
    custom)
        [[ -s "${config_file}" ]] || fail "CONFIG_MODE is custom, but ${config_file} does not exist or is empty."
        ;;
    generated)
        readonly listen_port="${SERVER_PORT:-25565}"
        readonly backend_host="${BACKEND_HOST:-127.0.0.1}"
        readonly backend_port="${BACKEND_PORT:-25565}"
        readonly proxy_mode="${PROXY_MODE:-tcp}"
        readonly health_check="${HEALTH_CHECK:-true}"
        readonly backend_tls="${BACKEND_TLS:-false}"
        readonly proxy_protocol="${PROXY_PROTOCOL:-none}"
        readonly max_connections="${MAX_CONNECTIONS:-2000}"
        readonly connect_timeout="${CONNECT_TIMEOUT:-5000}"
        readonly client_timeout="${CLIENT_TIMEOUT:-60000}"
        readonly server_timeout="${SERVER_TIMEOUT:-60000}"
        readonly tunnel_timeout="${TUNNEL_TIMEOUT:-3600000}"

        require_integer SERVER_PORT "${listen_port}" 1 65535
        require_integer BACKEND_PORT "${backend_port}" 1 65535
        require_integer MAX_CONNECTIONS "${max_connections}" 1 1000000
        require_integer CONNECT_TIMEOUT "${connect_timeout}" 1 86400000
        require_integer CLIENT_TIMEOUT "${client_timeout}" 1 86400000
        require_integer SERVER_TIMEOUT "${server_timeout}" 1 86400000
        require_integer TUNNEL_TIMEOUT "${tunnel_timeout}" 1 86400000

        [[ "${backend_host}" =~ ^[A-Za-z0-9._:-]+$ ]] || fail "BACKEND_HOST contains unsupported characters."
        [[ "${proxy_mode}" == "tcp" || "${proxy_mode}" == "http" ]] || fail "PROXY_MODE must be tcp or http."
        [[ "${health_check}" == "true" || "${health_check}" == "false" ]] || fail "HEALTH_CHECK must be true or false."
        [[ "${backend_tls}" == "true" || "${backend_tls}" == "false" ]] || fail "BACKEND_TLS must be true or false."
        [[ "${proxy_protocol}" == "none" || "${proxy_protocol}" == "v1" || "${proxy_protocol}" == "v2" ]] || fail "PROXY_PROTOCOL must be none, v1, or v2."

        backend_address="${backend_host}"
        if [[ "${backend_host}" == *:* ]]; then
            backend_address="[${backend_host}]"
        fi

        log_option="option tcplog"
        http_options=""
        if [[ "${proxy_mode}" == "http" ]]; then
            log_option="option httplog"
            http_options=$'  option forwardfor\n'
        fi

        server_options="resolvers docker_dns resolve-prefer ipv4 init-addr libc,none"
        if [[ "${health_check}" == "true" ]]; then
            server_options+=" check"
        fi
        if [[ "${backend_tls}" == "true" ]]; then
            server_options+=" ssl verify none"
        fi
        case "${proxy_protocol}" in
            v1) server_options+=" send-proxy" ;;
            v2) server_options+=" send-proxy-v2" ;;
        esac

        temporary_config="${config_file}.tmp.$$"
        trap 'rm -f "${temporary_config:-}"' EXIT
        umask 077
        cat > "${temporary_config}" <<EOF
# Managed by /usr/local/bin/pterodactyl-haproxy.
# Set CONFIG_MODE=custom before editing this file manually.
global
  log stdout format raw local0
  maxconn ${max_connections}

defaults
  log global
  mode ${proxy_mode}
  ${log_option}
  option dontlognull
  timeout connect ${connect_timeout}ms
  timeout client ${client_timeout}ms
  timeout server ${server_timeout}ms
  timeout tunnel ${tunnel_timeout}ms

resolvers docker_dns
  nameserver docker 127.0.0.11:53
  resolve_retries 3
  timeout resolve 1s
  timeout retry 1s

frontend pterodactyl_frontend
  bind 0.0.0.0:${listen_port}
${http_options}  default_backend upstream

backend upstream
  server upstream_1 ${backend_address}:${backend_port} ${server_options}
EOF
        mv "${temporary_config}" "${config_file}"
        trap - EXIT
        ;;
    *)
        fail "CONFIG_MODE must be generated or custom."
        ;;
esac

haproxy -c -f "${config_file}" || fail "HAProxy rejected ${config_file}."
printf '[HAProxy] Proxy ready; configuration: %s\n' "${config_file}"

exec haproxy -W -db -f "${config_file}"
