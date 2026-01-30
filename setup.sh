#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/DaggerConnect"
SYSTEMD_DIR="/etc/systemd/system"

# لینک‌های اختصاصی شما در بیان‌باکس برای دور زدن تحریم/فیلتر گیت‌هاب
BINARY_URL="https://github.com/2amir563/-khodamneveshtamDaggerConnect/raw/main/DaggerConnect"

show_banner() {
    echo -e "${CYAN}"
    echo "
  ██████  █████  ██████  ██████  ███████  ██████  ███
  ██   ██ ██  ██ ██   ██ ██   ██ ██      ██    ██ ██
  ██████  ██   ██ ██████  ██   ██ █████   ██    ██ ██
  ██   ██ ██  ██ ██   ██ ██   ██ ██      ██    ██ ██
  ██████  █████  ██  ██ ██████  ███████  ██████  ███

             __o__
            /  / \  \
           /  /   \  \  DaggerConnect
          /  / | | \  \ Reverse Tunnel Installer
         /  /  | |  \  \
        /  /   | |   \  \
       /  /____| |____\  \
      /____________________\
"
    echo -e "${NC}"
    echo -e "${GREEN}         DaggerConnect Installer v2.3 (Internal Mirror)${NC}"
    echo ""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ This script must be run as root${NC}"
        exit 1
    fi
}

install_dependencies() {
    echo -e "${YELLOW}📦 Installing dependencies...${NC}"
    if command -v apt &>/dev/null; then
        apt update -qq
        apt install -y wget curl tar git > /dev/null 2>&1 || { echo -e "${RED}Failed to install dependencies${NC}"; exit 1; }
    elif command -v yum &>/dev/null; then
        yum install -y wget curl tar git > /dev/null 2>&1 || { echo -e "${RED}Failed to install dependencies${NC}"; exit 1; }
    else
        echo -e "${RED}❌ Unsupported package manager${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Dependencies installed${NC}"
}

get_current_version() {
    if [ -f "$INSTALL_DIR/DaggerConnect" ]; then
        VERSION=$("$INSTALL_DIR/DaggerConnect" -v 2>&1 | grep -oP 'v\d+\.\d+\.\d+' || echo "unknown")
        echo "$VERSION"
    else
        echo "not-installed"
    fi
}

download_binary() {
    echo -e "${YELLOW}⬇️  Downloading DaggerConnect binary from Internal Mirror...${NC}"
    mkdir -p "$INSTALL_DIR"

    if [ -f "$INSTALL_DIR/DaggerConnect" ]; then
        mv "$INSTALL_DIR/DaggerConnect" "$INSTALL_DIR/DaggerConnect.backup"
    fi

    # استفاده از --no-check-certificate برای اطمینان از دانلود در شبکه ایران
    if wget -q --show-progress --no-check-certificate "$BINARY_URL" -O "$INSTALL_DIR/DaggerConnect"; then
        chmod +x "$INSTALL_DIR/DaggerConnect"
        echo -e "${GREEN}✓ DaggerConnect downloaded successfully${NC}"

        if "$INSTALL_DIR/DaggerConnect" -v &>/dev/null; then
            VERSION=$("$INSTALL_DIR/DaggerConnect" -v 2>&1 | grep -oP 'v\d+\.\d+\.\d+' || echo "v1.1.3")
            echo -e "${CYAN}ℹ️  Version: $VERSION${NC}"
        fi

        rm -f "$INSTALL_DIR/DaggerConnect.backup"
    else
        echo -e "${RED}✖ Failed to download DaggerConnect binary from mirror${NC}"
        if [ -f "$INSTALL_DIR/DaggerConnect.backup" ]; then
            mv "$INSTALL_DIR/DaggerConnect.backup" "$INSTALL_DIR/DaggerConnect"
            echo -e "${YELLOW}⚠️  Restored previous version${NC}"
        fi
        exit 1
    fi
}

update_binary() {
    show_banner
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}      UPDATE DaggerConnect CORE${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    CURRENT_VERSION=$(get_current_version)

    if [ "$CURRENT_VERSION" == "not-installed" ]; then
        echo -e "${RED}❌ DaggerConnect is not installed yet${NC}"
        echo ""
        read -p "Press Enter to return to menu..."
        main_menu
        return
    fi

    echo -e "${CYAN}Current Version: ${GREEN}$CURRENT_VERSION${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  This will:${NC}"
    echo "  - Stop all running services"
    echo "  - Download latest version from Mirror"
    echo "  - Restart services automatically"
    echo ""
    read -p "Continue with update? [y/N]: " confirm

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        main_menu
        return
    fi

    echo ""
    echo -e "${YELLOW}Stopping services...${NC}"
    systemctl stop DaggerConnect-server 2>/dev/null
    systemctl stop DaggerConnect-client 2>/dev/null
    sleep 2

    download_binary

    NEW_VERSION=$(get_current_version)

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}   ✓ Update completed successfully!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "  Previous Version: ${YELLOW}$CURRENT_VERSION${NC}"
    echo -e "  Current Version:  ${GREEN}$NEW_VERSION${NC}"
    echo ""

    if systemctl is-enabled DaggerConnect-server &>/dev/null || systemctl is-enabled DaggerConnect-client &>/dev/null; then
        read -p "Restart services now? [Y/n]: " restart
        if [[ ! $restart =~ ^[Nn]$ ]]; then
            echo ""
            if systemctl is-enabled DaggerConnect-server &>/dev/null; then
                systemctl start DaggerConnect-server
                echo -e "${GREEN}✓ Server restarted${NC}"
            fi
            if systemctl is-enabled DaggerConnect-client &>/dev/null; then
                systemctl start DaggerConnect-client
                echo -e "${GREEN}✓ Client restarted${NC}"
            fi
        fi
    fi

    echo ""
    read -p "Press Enter to return to menu..."
    main_menu
}

create_systemd_service() {
    local MODE=$1
    local SERVICE_NAME="DaggerConnect-${MODE}"
    local SERVICE_FILE="$SYSTEMD_DIR/${SERVICE_NAME}.service"

    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=DaggerConnect Reverse Tunnel ${MODE^}
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$CONFIG_DIR
ExecStart=$INSTALL_DIR/DaggerConnect -c $CONFIG_DIR/${MODE}.yaml
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    echo -e "${GREEN}✓ Systemd service for ${MODE^} created: ${SERVICE_NAME}.service${NC}"
}

install_server() {
    show_banner
    mkdir -p "$CONFIG_DIR"

    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}      SERVER CONFIGURATION${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    echo -e "${YELLOW}Select Transport Type:${NC}"
    echo "  1) tcpmux  - TCP Multiplexing"
    echo "  2) kcpmux  - KCP Multiplexing (UDP based)"
    echo "  3) wsmux   - WebSocket"
    echo "  4) wssmux  - WebSocket Secure (TLS)"
    echo ""
    read -p "Choice [1-4]: " transport_choice
    case $transport_choice in
        1) TRANSPORT="tcpmux" ;;
        2) TRANSPORT="kcpmux" ;;
        3) TRANSPORT="wsmux" ;;
        4) TRANSPORT="wssmux" ;;
        *) TRANSPORT="tcpmux" ;;
    esac

    echo ""
    echo -e "${CYAN}Tunnel Port: Port for communication between Server and Client${NC}"
    read -p "Tunnel Port [2020]: " LISTEN_PORT
    LISTEN_PORT=${LISTEN_PORT:-2020}

    echo ""
    while true; do
        read -sp "Enter PSK (Pre-Shared Key): " PSK
        echo ""
        if [ -z "$PSK" ]; then
            echo -e "${RED}PSK cannot be empty!${NC}"
        else
            break
        fi
    done

    echo ""
    echo -e "${YELLOW}Select Performance Profile:${NC}"
    echo "  1) balanced      - Standard balanced performance"
    echo "  2) aggressive    - High speed, aggressive settings"
    echo "  3) latency       - Optimized for low latency"
    echo "  4) cpu-efficient - Low CPU usage"
    echo ""
    read -p "Choice [1-4]: " profile_choice
    case $profile_choice in
        1) PROFILE="balanced" ;;
        2) PROFILE="aggressive" ;;
        3) PROFILE="latency" ;;
        4) PROFILE="cpu-efficient" ;;
        *) PROFILE="balanced" ;;
    esac

    CERT_FILE=""
    KEY_FILE=""
    if [ "$TRANSPORT" == "wssmux" ]; then
        echo ""
        echo -e "${YELLOW}TLS Configuration (Required for wssmux):${NC}"
        read -p "Certificate file path: " CERT_FILE
        read -p "Private key file path: " KEY_FILE
    fi

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}      PORT MAPPINGS${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    MAPPINGS=""
    COUNT=0
    while true; do
        echo ""
        echo -e "${YELLOW}Add Port Mapping #$((COUNT+1))${NC}"
        echo "Protocol:"
        echo "  1) tcp"
        echo "  2) udp"
        echo "  3) both (tcp + udp)"
        read -p "Choice [1-3]: " proto_choice

        while true; do
            read -p "Port on Server (required): " BIND_PORT
            if [[ -n "$BIND_PORT" ]] && [[ "$BIND_PORT" =~ ^[0-9]+$ ]] && [ "$BIND_PORT" -ge 1 ] && [ "$BIND_PORT" -le 65535 ]; then
                break
            else
                echo -e "${RED}⚠ Invalid port!${NC}"
            fi
        done

        BIND="0.0.0.0:${BIND_PORT}"
        TARGET="0.0.0.0:${BIND_PORT}"

        case $proto_choice in
            1) MAPPINGS="${MAPPINGS}  - type: tcp\n    bind: \"${BIND}\"\n    target: \"${TARGET}\"\n" ;;
            2) MAPPINGS="${MAPPINGS}  - type: udp\n    bind: \"${BIND}\"\n    target: \"${TARGET}\"\n" ;;
            3) 
                MAPPINGS="${MAPPINGS}  - type: tcp\n    bind: \"${BIND}\"\n    target: \"${TARGET}\"\n"
                MAPPINGS="${MAPPINGS}  - type: udp\n    bind: \"${BIND}\"\n    target: \"${TARGET}\"\n" 
                ;;
        esac

        COUNT=$((COUNT+1))
        read -p "Add another port mapping? (y/n) [n]: " add_more
        [[ "$add_more" =~ ^[Yy] ]] || break
    done

    echo ""
    read -p "Enable verbose logging? [y/N]: " VERBOSE
    [[ $VERBOSE =~ ^[Yy]$ ]] && VERBOSE="true" || VERBOSE="false"

    CONFIG_FILE="$CONFIG_DIR/server.yaml"
    cat > "$CONFIG_FILE" << EOF
mode: "server"
listen: "0.0.0.0:${LISTEN_PORT}"
transport: "${TRANSPORT}"
psk: "${PSK}"
profile: "${PROFILE}"
verbose: ${VERBOSE}
EOF

    if [[ -n "$CERT_FILE" ]]; then
        cat >> "$CONFIG_FILE" << EOF
cert_file: "$CERT_FILE"
key_file: "$KEY_FILE"
EOF
    fi

    echo -e "maps:\n$MAPPINGS" >> "$CONFIG_FILE"

    cat >> "$CONFIG_FILE" << 'EOF'
smux:
  keepalive: 8
  max_recv: 8388608
  max_stream: 8388608
  frame_size: 32768
  version: 2
kcp:
  nodelay: 1
  interval: 10
  resend: 2
  nc: 1
  sndwnd: 1024
  rcvwnd: 1024
  mtu: 1400
advanced:
  tcp_nodelay: true
  tcp_keepalive: 15
  tcp_read_buffer: 8388608
  tcp_write_buffer: 8388608
  websocket_read_buffer: 262144
  websocket_write_buffer: 262144
  websocket_compression: false
  cleanup_interval: 3
  session_timeout: 30
  connection_timeout: 60
  stream_timeout: 120
  max_connections: 2000
  max_udp_flows: 1000
  udp_flow_timeout: 300
  udp_buffer_size: 4194304
heartbeat: 10
EOF

    create_systemd_service "server"
    systemctl start DaggerConnect-server
    systemctl enable DaggerConnect-server

    echo -e "\n${GREEN}✓ Server installation complete!${NC}\n"
    read -p "Press Enter to return to menu..."
    main_menu
}

install_client() {
    show_banner
    mkdir -p "$CONFIG_DIR"

    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}      CLIENT CONFIGURATION${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    while true; do
        read -sp "Enter PSK (must match server): " PSK
        echo ""
        if [ -z "$PSK" ]; then
            echo -e "${RED}PSK cannot be empty!${NC}"
        else
            break
        fi
    done

    echo ""
    read -p "Select Performance Profile [1-4]: " profile_choice
    case $profile_choice in
        1) PROFILE="balanced" ;;
        2) PROFILE="aggressive" ;;
        3) PROFILE="latency" ;;
        4) PROFILE="cpu-efficient" ;;
        *) PROFILE="balanced" ;;
    esac

    declare -a PATH_ENTRIES=()
    COUNT=0

    while true; do
        echo -e "\n${YELLOW}Add Connection Path #$((COUNT+1))${NC}"
        read -p "Transport (1:tcpmux, 2:kcpmux, 3:wsmux, 4:wssmux): " t_choice
        case $t_choice in
            1) T="tcpmux" ;; 2) T="kcpmux" ;; 3) T="wsmux" ;; 4) T="wssmux" ;; *) T="tcpmux" ;;
        esac

        read -p "Server Address:TunnelPort (e.g. 1.2.3.4:2020): " ADDR
        read -p "Pool Size [2]: " POOL
        POOL=${POOL:-2}

        PATH_ENTRIES+=("  - transport: \"$T\"\n    addr: \"$ADDR\"\n    connection_pool: $POOL\n    aggressive_pool: false\n    retry_interval: 3\n    dial_timeout: 10")
        
        COUNT=$((COUNT+1))
        read -p "Add another path? [y/N]: " MORE
        [[ ! $MORE =~ ^[Yy]$ ]] && break
    done

    CONFIG_FILE="$CONFIG_DIR/client.yaml"
    cat > "$CONFIG_FILE" << EOF
mode: "client"
psk: "${PSK}"
profile: "${PROFILE}"
verbose: false
paths:
EOF
    for entry in "${PATH_ENTRIES[@]}"; do
        echo -e "$entry" >> "$CONFIG_FILE"
    done

    cat >> "$CONFIG_FILE" << 'EOF'
smux:
  keepalive: 8
  max_recv: 8388608
  max_stream: 8388608
  frame_size: 32768
  version: 2
kcp:
  nodelay: 1
  interval: 10
  resend: 2
  nc: 1
  sndwnd: 1024
  rcvwnd: 1024
  mtu: 1400
advanced:
  tcp_nodelay: true
  tcp_keepalive: 15
  tcp_read_buffer: 8388608
  tcp_write_buffer: 8388608
  websocket_read_buffer: 262144
  websocket_write_buffer: 262144
  websocket_compression: false
  cleanup_interval: 3
  session_timeout: 30
  connection_timeout: 60
  stream_timeout: 120
  max_connections: 2000
  max_udp_flows: 1000
  udp_flow_timeout: 300
  udp_buffer_size: 4194304
heartbeat: 10
EOF

    create_systemd_service "client"
    systemctl start DaggerConnect-client
    systemctl enable DaggerConnect-client

    echo -e "\n${GREEN}✓ Client installation complete!${NC}\n"
    read -p "Press Enter to return to menu..."
    main_menu
}

service_management() {
    local MODE=$1
    local SERVICE_NAME="DaggerConnect-${MODE}"
    local CONFIG_FILE="$CONFIG_DIR/${MODE}.yaml"
    
    show_banner
    echo "1) Start 2) Stop 3) Restart 4) Status 5) Logs 0) Back"
    read -p "Select: " choice
    case $choice in
        1) systemctl start "$SERVICE_NAME" ;;
        2) systemctl stop "$SERVICE_NAME" ;;
        3) systemctl restart "$SERVICE_NAME" ;;
        4) systemctl status "$SERVICE_NAME" ;;
        5) journalctl -u "$SERVICE_NAME" -f ;;
        0) settings_menu ;;
    esac
    service_management "$MODE"
}

settings_menu() {
    show_banner
    echo "1) Manage Server  2) Manage Client  0) Back"
    read -p "Select: " choice
    case $choice in
        1) service_management "server" ;;
        2) service_management "client" ;;
        0) main_menu ;;
    esac
}

uninstall_DaggerConnect() {
    systemctl stop DaggerConnect-server DaggerConnect-client 2>/dev/null
    rm -rf "$INSTALL_DIR/DaggerConnect" "$CONFIG_DIR" "$SYSTEMD_DIR/DaggerConnect-*"
    systemctl daemon-reload
    echo "Uninstalled."
    exit 0
}

main_menu() {
    show_banner
    echo "1) Install Server"
    echo "2) Install Client"
    echo "3) Settings"
    echo "4) Update Core"
    echo "5) Uninstall"
    echo "0) Exit"
    read -p "Choice: " choice
    case $choice in
        1) install_server ;;
        2) install_client ;;
        3) settings_menu ;;
        4) update_binary ;;
        5) uninstall_DaggerConnect ;;
        0) exit 0 ;;
        *) main_menu ;;
    esac
}

check_root
install_dependencies
if [ ! -f "$INSTALL_DIR/DaggerConnect" ]; then
    download_binary
fi
main_menu
