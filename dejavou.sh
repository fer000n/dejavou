#!/usr/bin/env bash
# ==============================================================================
#  🔮 DEJAVOU - Multi-Tunnel Stealth In-Memory Management Wizard
#  Designed for Ubuntu / Debian Linux
# ==============================================================================

set -e

# Directories and paths
INSTALL_DIR="/opt/dejavou"
TUNNELS_DIR="${INSTALL_DIR}/tunnels"
LAUNCHER_BIN="${INSTALL_DIR}/DejavouLauncher"
REVTUN_BIN="${INSTALL_DIR}/revtun"
SERVICE_TEMPLATE="/etc/systemd/system/dejavou@.service"

# Terminal ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Check Root Privileges
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}[ERROR] This wizard must be executed as root (run: sudo -i).${NC}"
        exit 1
    fi
}

# Install Essential Dependencies
install_deps() {
    local missing=()
    command -v jq >/dev/null 2>&1 || missing+=("jq")
    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v openssl >/dev/null 2>&1 || missing+=("openssl")
    command -v nano >/dev/null 2>&1 || missing+=("nano")
    command -v ss >/dev/null 2>&1 || missing+=("iproute2")

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${CYAN}[*] Installing required packages (${missing[*]})...${NC}"
        apt-get update -qq >/dev/null 2>&1 || true
        apt-get install -y -qq "${missing[@]}" >/dev/null 2>&1 || true
    fi
}

# Header Banner
show_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  =============================================================="
    echo "             🔮  DEJAVOU - Multi-Tunnel Stealth Manager  🔮     "
    echo "              In-Memory Linux Anonymous Reverse Tunnel          "
    echo "  =============================================================="
    echo -e "${NC}"
}

# Setup Systemd Template Unit
setup_systemd_template() {
    mkdir -p "$TUNNELS_DIR"
    cat <<EOF > "$SERVICE_TEMPLATE"
[Unit]
Description=Dejavou Stealth Tunnel (%i)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${LAUNCHER_BIN} -c ${TUNNELS_DIR}/%i.json
Restart=always
RestartSec=3
LimitNOFILE=1048576
StandardOutput=journal
StandardError=journal
SyslogIdentifier=dejavou-%i

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
}

# Deploy Binaries to Installation Directory
deploy_binaries() {
    mkdir -p "$INSTALL_DIR" "$TUNNELS_DIR"

    # Search for launcher binary
    if [ -f "./DejavouLauncher_linux" ]; then
        cp "./DejavouLauncher_linux" "$LAUNCHER_BIN"
    elif [ -f "./DaggerLauncher_linux" ]; then
        cp "./DaggerLauncher_linux" "$LAUNCHER_BIN"
    elif [ -f "./DaggerLauncher" ]; then
        cp "./DaggerLauncher" "$LAUNCHER_BIN"
    fi

    # Search for tunnel core binary
    if [ -f "./revtun-linux-amd64" ]; then
        cp "./revtun-linux-amd64" "$REVTUN_BIN"
    elif [ -f "./revtun" ]; then
        cp "./revtun" "$REVTUN_BIN"
    elif [ -f "../dist/revtun-linux-amd64" ]; then
        cp "../dist/revtun-linux-amd64" "$REVTUN_BIN"
    fi

    if [ -f "$LAUNCHER_BIN" ]; then
        chmod +x "$LAUNCHER_BIN"
    fi
    if [ -f "$REVTUN_BIN" ]; then
        chmod +x "$REVTUN_BIN"
    fi

    setup_systemd_template
}

# Get list of configured tunnel names
get_tunnel_list() {
    if [ -d "$TUNNELS_DIR" ]; then
        find "$TUNNELS_DIR" -maxdepth 1 -name "*.json" -exec basename {} .json \; 2>/dev/null | sort
    fi
}

# List all tunnels with live status
list_all_tunnels() {
    show_header
    echo -e "${BOLD}=== [ Configured Tunnels Overview ] ===${NC}\n"

    local tunnels=()
    while IFS= read -r line; do
        [ -n "$line" ] && tunnels+=("$line")
    done < <(get_tunnel_list)

    if [ ${#tunnels[@]} -eq 0 ]; then
        echo -e "${YELLOW}No tunnels configured yet. Use Option [2] to create your first tunnel.${NC}\n"
        read -rp "Press Enter to return to menu..."
        return
    fi

    printf "%-4s %-18s %-8s %-9s %-20s %-12s %-12s\n" "No." "Tunnel Name" "Role" "Transport" "Endpoint / Port" "Service" "Autostart"
    echo "---------------------------------------------------------------------------------------------------"

    local idx=1
    for t in "${tunnels[@]}"; do
        local cfg="${TUNNELS_DIR}/${t}.json"
        local mode transport endpoint socks
        mode=$(jq -r '.mode // "N/A"' "$cfg" 2>/dev/null)
        transport=$(jq -r '.transport // "N/A"' "$cfg" 2>/dev/null)

        if [ "$mode" == "server" ]; then
            endpoint=$(jq -r '.listeners[0].addr // "N/A"' "$cfg" 2>/dev/null)
        else
            endpoint=$(jq -r '.paths[0].addr // "N/A"' "$cfg" 2>/dev/null)
        fi

        # Check Service Status
        local status_str autostart_str
        if systemctl is-active --quiet "dejavou@${t}" 2>/dev/null; then
            status_str="${GREEN}RUNNING${NC}"
        else
            status_str="${RED}STOPPED${NC}"
        fi

        if systemctl is-enabled --quiet "dejavou@${t}" 2>/dev/null; then
            autostart_str="${GREEN}ENABLED${NC}"
        else
            autostart_str="${YELLOW}DISABLED${NC}"
        fi

        printf "%-4d %-18s %-8s %-9s %-20s " "$idx" "$t" "$mode" "$transport" "$endpoint"
        echo -e "${status_str}     ${autostart_str}"
        idx=$((idx + 1))
    done

    echo "---------------------------------------------------------------------------------------------------"
    echo ""
    read -rp "Press Enter to return to menu..."
}

# Create New Tunnel (Wizard)
create_tunnel_wizard() {
    show_header
    echo -e "${BOLD}=== [ Create New Tunnel Wizard ] ===${NC}\n"

    mkdir -p "$TUNNELS_DIR"

    # 1. Tunnel Name
    read -rp "Enter unique tunnel name (e.g. kharej-1, iran-cdn): " t_name
    t_name=$(echo "$t_name" | tr -dc 'a-zA-Z0-9_-')
    if [ -z "$t_name" ]; then
        echo -e "${RED}[ERROR] Invalid tunnel name.${NC}"
        sleep 1.5
        return
    fi

    local target_cfg="${TUNNELS_DIR}/${t_name}.json"
    if [ -f "$target_cfg" ]; then
        echo -e "${RED}[ERROR] Tunnel '${t_name}' already exists! Choose a different name.${NC}"
        read -rp "Press Enter to return..."
        return
    fi

    # 2. Select Role
    echo -e "\nSelect role for this tunnel node:"
    echo "  1) Server (Egress / Destination node - Listens for incoming carrier)"
    echo "  2) Client (Ingress / Source node - Dials outward to Server)"
    read -rp "Choice [1 or 2]: " role_opt

    local mode="client"
    if [ "$role_opt" == "1" ]; then
        mode="server"
    fi

    # 3. Select Transport
    echo -e "\nSelect Transport Carrier Protocol:"
    echo "  1) TCP    - Direct raw TCP connection (Fastest, lowest latency)"
    echo "  2) WS     - Plain WebSocket"
    echo "  3) WSS    - WebSocket with TLS encryption"
    echo "  4) XHTTP  - Split-HTTP (Specialized for CDN buffering like Arvan/Cloudflare)"
    echo "  5) XHTTPS - Encrypted Split-HTTP over TLS"
    read -rp "Choice [Default: 1]: " tr_opt

    local transport="tcp"
    case "$tr_opt" in
        2) transport="ws" ;;
        3) transport="wss" ;;
        4) transport="xhttp" ;;
        5) transport="xhttps" ;;
        *) transport="tcp" ;;
    esac

    # 4. Shared PSK Key
    local def_psk
    def_psk=$(openssl rand -hex 16)
    echo -e "\nPre-Shared Encryption Key (PSK):"
    echo -e "  Generated Key: ${YELLOW}${def_psk}${NC}"
    read -rp "Enter custom PSK or press Enter to accept generated: " user_psk
    local psk="${user_psk:-$def_psk}"

    # Server Configuration
    if [ "$mode" == "server" ]; then
        read -rp "Server listen port [Default: 7000]: " s_port
        s_port="${s_port:-7000}"

        read -rp "Enable local SOCKS5 proxy on Server? (y/n) [Default: y]: " s_socks
        s_socks="${s_socks:-y}"
        local socks_enabled="false"
        local socks_bind="127.0.0.1:10808"
        if [[ "$s_socks" =~ ^[Yy]$ ]]; then
            socks_enabled="true"
            read -rp "SOCKS5 bind port [Default: 10808]: " sk_port
            sk_port="${sk_port:-10808}"
            socks_bind="127.0.0.1:${sk_port}"
        fi

        cat <<EOF > "$target_cfg"
{
  "mode": "server",
  "transport": "${transport}",
  "psk": "${psk}",
  "log_level": "info",
  "listeners": [
    {
      "addr": "0.0.0.0:${s_port}",
      "transport": "${transport}"
    }
  ],
  "socks5": {
    "enabled": ${socks_enabled},
    "bind": "${socks_bind}"
  },
  "advanced": {
    "auto_tune": true,
    "keepalive_sec": 5,
    "dead_timeout_sec": 25
  }
}
EOF

    # Client Configuration
    else
        read -rp "Remote Server IP or Domain: " remote_ip
        while [ -z "$remote_ip" ]; do
            echo -e "${RED}[ERROR] Remote server address cannot be empty.${NC}"
            read -rp "Remote Server IP or Domain: " remote_ip
        done

        read -rp "Remote Server port [Default: 7000]: " remote_port
        remote_port="${remote_port:-7000}"

        read -rp "Connection pool size (Concurrent carriers) [Default: 2]: " pool_size
        pool_size="${pool_size:-2}"

        read -rp "Enable local SOCKS5 proxy in Client node? (y/n) [Default: y]: " c_socks
        c_socks="${c_socks:-y}"
        local socks_json=""
        if [[ "$c_socks" =~ ^[Yy]$ ]]; then
            read -rp "Local SOCKS5 port [Default: 10810]: " cs_port
            cs_port="${cs_port:-10810}"
            socks_json="\"socks5\": { \"enabled\": true, \"bind\": \"127.0.0.1:${cs_port}\" },"
        fi

        local extra_fields=""
        if [ "$transport" == "xhttp" ] || [ "$transport" == "xhttps" ]; then
            read -rp "HTTP path for XHTTP [Default: /api]: " x_path
            x_path="${x_path:-/api}"
            read -rp "CDN SNI/Host header (Optional): " x_host
            extra_fields="\"path\": \"${x_path}\", \"mode\": \"packet-up\","
            if [ -n "$x_host" ]; then
                extra_fields="${extra_fields} \"host\": \"${x_host}\","
            fi
        fi

        cat <<EOF > "$target_cfg"
{
  "mode": "client",
  "transport": "${transport}",
  "psk": "${psk}",
  "log_level": "info",
  "paths": [
    {
      "addr": "${remote_ip}:${remote_port}",
      "transport": "${transport}",
      ${extra_fields}
      "connection_pool": ${pool_size},
      "retry_interval": 3,
      "dial_timeout": 10
    }
  ],
  ${socks_json}
  "advanced": {
    "auto_tune": true,
    "keepalive_sec": 5,
    "dead_timeout_sec": 25
  }
}
EOF
    fi

    setup_systemd_template
    # Automatically enable service on boot
    systemctl enable "dejavou@${t_name}" >/dev/null 2>&1

    echo -e "\n${GREEN}[SUCCESS] Tunnel '${t_name}' created and set to auto-start on boot!${NC}"

    read -rp "Start '${t_name}' service now? (y/n) [Default: y]: " start_now
    start_now="${start_now:-y}"
    if [[ "$start_now" =~ ^[Yy]$ ]]; then
        systemctl start "dejavou@${t_name}"
        echo -e "${GREEN}[✓] Service dejavou@${t_name} started successfully.${NC}"
    fi

    read -rp "Press Enter to continue..."
}

# Manage Tunnel Services (Start/Stop/Restart)
manage_tunnels_menu() {
    show_header
    echo -e "${BOLD}=== [ Service Control & Management ] ===${NC}\n"

    local tunnels=()
    while IFS= read -r line; do
        [ -n "$line" ] && tunnels+=("$line")
    done < <(get_tunnel_list)

    if [ ${#tunnels[@]} -eq 0 ]; then
        echo -e "${YELLOW}No tunnels available.${NC}"
        sleep 1.5
        return
    fi

    echo "Available Tunnels:"
    local idx=1
    for t in "${tunnels[@]}"; do
        local status_str
        if systemctl is-active --quiet "dejavou@${t}" 2>/dev/null; then
            status_str="${GREEN}[RUNNING]${NC}"
        else
            status_str="${RED}[STOPPED]${NC}"
        fi
        echo -e "  ${idx}) ${t} ${status_str}"
        idx=$((idx + 1))
    done

    echo -e "\nActions:"
    echo "  1) Restart Tunnel"
    echo "  2) Start Tunnel"
    echo "  3) Stop Tunnel"
    echo "  4) Restart ALL Tunnels"
    echo "  5) Start ALL Tunnels"
    echo "  6) Stop ALL Tunnels"
    echo "  0) Back to Main Menu"
    read -rp "Choose action: " action_opt

    case "$action_opt" in
        1|2|3)
            read -rp "Select tunnel number (1-${#tunnels[@]}): " sel_idx
            if [[ "$sel_idx" -ge 1 && "$sel_idx" -le "${#tunnels[@]}" ]]; then
                local chosen_t="${tunnels[$((sel_idx - 1))]}"
                if [ "$action_opt" == "1" ]; then
                    systemctl restart "dejavou@${chosen_t}"
                    echo -e "${GREEN}[✓] Restarted dejavou@${chosen_t}.${NC}"
                elif [ "$action_opt" == "2" ]; then
                    systemctl start "dejavou@${chosen_t}"
                    echo -e "${GREEN}[✓] Started dejavou@${chosen_t}.${NC}"
                elif [ "$action_opt" == "3" ]; then
                    systemctl stop "dejavou@${chosen_t}"
                    echo -e "${YELLOW}[!] Stopped dejavou@${chosen_t}.${NC}"
                fi
            else
                echo -e "${RED}Invalid selection.${NC}"
            fi
            sleep 1.5
            ;;
        4)
            for t in "${tunnels[@]}"; do
                systemctl restart "dejavou@${t}"
            done
            echo -e "${GREEN}[✓] All tunnels restarted.${NC}"
            sleep 1.5
            ;;
        5)
            for t in "${tunnels[@]}"; do
                systemctl start "dejavou@${t}"
            done
            echo -e "${GREEN}[✓] All tunnels started.${NC}"
            sleep 1.5
            ;;
        6)
            for t in "${tunnels[@]}"; do
                systemctl stop "dejavou@${t}"
            done
            echo -e "${YELLOW}[!] All tunnels stopped.${NC}"
            sleep 1.5
            ;;
        0) return ;;
    esac
}

# View Live Logs for a Specific Tunnel
view_tunnel_logs() {
    show_header
    echo -e "${BOLD}=== [ Live Journal Logs ] ===${NC}\n"

    local tunnels=()
    while IFS= read -r line; do
        [ -n "$line" ] && tunnels+=("$line")
    done < <(get_tunnel_list)

    if [ ${#tunnels[@]} -eq 0 ]; then
        echo -e "${YELLOW}No tunnels configured.${NC}"
        sleep 1.5
        return
    fi

    echo "Select Tunnel to Stream Logs:"
    local idx=1
    for t in "${tunnels[@]}"; do
        echo "  ${idx}) ${t}"
        idx=$((idx + 1))
    done
    read -rp "Tunnel number (1-${#tunnels[@]}): " sel_idx

    if [[ "$sel_idx" -ge 1 && "$sel_idx" -le "${#tunnels[@]}" ]]; then
        local chosen_t="${tunnels[$((sel_idx - 1))]}"
        echo -e "\n${CYAN}[*] Streaming logs for dejavou@${chosen_t} (Press Ctrl+C to exit)...${NC}\n"
        journalctl -u "dejavou@${chosen_t}" -f -n 50
    else
        echo -e "${RED}Invalid choice.${NC}"
        sleep 1.5
    fi
}

# Edit Tunnel Config
edit_tunnel_config() {
    show_header
    echo -e "${BOLD}=== [ Edit Tunnel JSON Configuration ] ===${NC}\n"

    local tunnels=()
    while IFS= read -r line; do
        [ -n "$line" ] && tunnels+=("$line")
    done < <(get_tunnel_list)

    if [ ${#tunnels[@]} -eq 0 ]; then
        echo -e "${YELLOW}No tunnels found.${NC}"
        sleep 1.5
        return
    fi

    echo "Select Tunnel to Edit:"
    local idx=1
    for t in "${tunnels[@]}"; do
        echo "  ${idx}) ${t}"
        idx=$((idx + 1))
    done
    read -rp "Tunnel number: " sel_idx

    if [[ "$sel_idx" -ge 1 && "$sel_idx" -le "${#tunnels[@]}" ]]; then
        local chosen_t="${tunnels[$((sel_idx - 1))]}"
        local cfg_path="${TUNNELS_DIR}/${chosen_t}.json"

        cp "$cfg_path" "${cfg_path}.bak"
        nano "$cfg_path"

        if jq . "$cfg_path" >/dev/null 2>&1; then
            echo -e "${GREEN}[✓] JSON syntax valid.${NC}"
            read -rp "Restart dejavou@${chosen_t} now? (y/n) [Default: y]: " r_opt
            r_opt="${r_opt:-y}"
            if [[ "$r_opt" =~ ^[Yy]$ ]]; then
                systemctl restart "dejavou@${chosen_t}"
                echo -e "${GREEN}[✓] Service restarted.${NC}"
            fi
        else
            echo -e "${RED}[ERROR] Invalid JSON syntax! Restoring previous backup.${NC}"
            cp "${cfg_path}.bak" "$cfg_path"
        fi
    fi
    read -rp "Press Enter to continue..."
}

# Test Connection (Curl SOCKS5)
test_tunnel_socks() {
    show_header
    echo -e "${BOLD}=== [ Test SOCKS5 Egress & Exit IP ] ===${NC}\n"

    local tunnels=()
    while IFS= read -r line; do
        [ -n "$line" ] && tunnels+=("$line")
    done < <(get_tunnel_list)

    if [ ${#tunnels[@]} -eq 0 ]; then
        echo -e "${YELLOW}No tunnels configured.${NC}"
        sleep 1.5
        return
    fi

    echo "Select Tunnel to Test:"
    local idx=1
    for t in "${tunnels[@]}"; do
        local sp
        sp=$(jq -r '.socks5.bind // empty' "${TUNNELS_DIR}/${t}.json" 2>/dev/null | awk -F: '{print $NF}')
        echo "  ${idx}) ${t} (SOCKS5 Port: ${sp:-Disabled})"
        idx=$((idx + 1))
    done
    read -rp "Tunnel number: " sel_idx

    if [[ "$sel_idx" -ge 1 && "$sel_idx" -le "${#tunnels[@]}" ]]; then
        local chosen_t="${tunnels[$((sel_idx - 1))]}"
        local sp
        sp=$(jq -r '.socks5.bind // empty' "${TUNNELS_DIR}/${chosen_t}.json" 2>/dev/null | awk -F: '{print $NF}')

        if [ -n "$sp" ]; then
            echo -e "Testing outbound connection through 127.0.0.1:${sp}..."
            local ip_res
            ip_res=$(curl -s -m 7 -x "socks5h://127.0.0.1:${sp}" https://api.ipify.org 2>/dev/null || echo "")

            if [ -n "$ip_res" ]; then
                echo -e "${GREEN}[SUCCESS] Connection active! Tunnel Exit IP: ${BOLD}${ip_res}${NC}"
            else
                echo -e "${RED}[FAILED] No response through SOCKS5 port ${sp}.${NC}"
                echo "Check if the remote server is online and matching PSK key."
            fi
        else
            echo -e "${YELLOW}[!] SOCKS5 proxy is disabled in ${chosen_t}.json.${NC}"
        fi
    fi
    read -rp "Press Enter to continue..."
}

# Delete a Tunnel
delete_tunnel() {
    show_header
    echo -e "${BOLD}=== [ Remove / Delete Tunnel ] ===${NC}\n"

    local tunnels=()
    while IFS= read -r line; do
        [ -n "$line" ] && tunnels+=("$line")
    done < <(get_tunnel_list)

    if [ ${#tunnels[@]} -eq 0 ]; then
        echo -e "${YELLOW}No tunnels found to delete.${NC}"
        sleep 1.5
        return
    fi

    echo "Select Tunnel to Delete:"
    local idx=1
    for t in "${tunnels[@]}"; do
        echo "  ${idx}) ${t}"
        idx=$((idx + 1))
    done
    read -rp "Tunnel number: " sel_idx

    if [[ "$sel_idx" -ge 1 && "$sel_idx" -le "${#tunnels[@]}" ]]; then
        local chosen_t="${tunnels[$((sel_idx - 1))]}"
        read -rp "Are you sure you want to completely remove '${chosen_t}'? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            systemctl stop "dejavou@${chosen_t}" 2>/dev/null || true
            systemctl disable "dejavou@${chosen_t}" 2>/dev/null || true
            rm -f "${TUNNELS_DIR}/${chosen_t}.json" "${TUNNELS_DIR}/${chosen_t}.json.bak"
            echo -e "${YELLOW}[✓] Tunnel '${chosen_t}' removed.${NC}"
        fi
    fi
    sleep 1.5
}

# Main Application Menu
main_menu() {
    check_root
    install_deps
    deploy_binaries

    while true; do
        show_header

        # Count active tunnels
        local active_count=0
        local total_count=0
        for t in $(get_tunnel_list); do
            total_count=$((total_count + 1))
            if systemctl is-active --quiet "dejavou@${t}" 2>/dev/null; then
                active_count=$((active_count + 1))
            fi
        done

        echo -e " System Status: [ ${GREEN}${active_count} Active / Running${NC} | ${YELLOW}${total_count} Total Configured${NC} ]\n"

        echo "  [1] List All Tunnels & Status"
        echo "  [2] Create New Tunnel (Interactive Wizard)"
        echo "  [3] Control Tunnels (Start / Stop / Restart)"
        echo "  [4] Stream Live Tunnel Logs"
        echo "  [5] Edit Tunnel Configuration"
        echo "  [6] Test Connection & Exit Public IP"
        echo "  [7] Delete a Tunnel"
        echo "  [8] Reinstall / Refresh Binaries"
        echo "  [0] Exit Wizard"
        echo ""
        read -rp "Enter choice [0-8]: " choice

        case "$choice" in
            1) list_all_tunnels ;;
            2) create_tunnel_wizard ;;
            3) manage_tunnels_menu ;;
            4) view_tunnel_logs ;;
            5) edit_tunnel_config ;;
            6) test_tunnel_socks ;;
            7) delete_tunnel ;;
            8)
                deploy_binaries
                echo -e "${GREEN}[✓] Binaries & systemd template updated successfully.${NC}"
                sleep 1.5
                ;;
            0)
                echo -e "\n${CYAN}Exiting Dejavou Wizard. Goodbye!${NC}\n"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option.${NC}"
                sleep 1
                ;;
        esac
    done
}

main_menu

