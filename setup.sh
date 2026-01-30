#!/bin/bash

# رنگ‌ها برای زیبایی کنسول
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/DaggerConnect"
SYSTEMD_DIR="/etc/systemd/system"

# لینک مستقیم دانلود از گیت‌هاب شما (مخصوص سرور خارج)
BINARY_URL="https://raw.githubusercontent.com/2amir563/-khodamneveshtamDaggerConnect/main/DaggerConnect"

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
           /  /   \  \  DaggerConnect (GitHub Edition)
          /  / | | \  \ Reverse Tunnel Installer
         /  /  | |  \  \
        /  /   | |   \  \
       /  /____| |____\  \
      /____________________\
"
    echo -e "${NC}"
}

check_root() {
    [[ $EUID -ne 0 ]] && echo -e "${RED}❌ Run as root!${NC}" && exit 1
}

install_dependencies() {
    echo -e "${YELLOW}📦 Installing dependencies...${NC}"
    if command -v apt &>/dev/null; then
        apt update -qq && apt install -y wget curl tar git > /dev/null 2>&1
    elif command -v yum &>/dev/null; then
        yum install -y wget curl tar git > /dev/null 2>&1
    fi
    echo -e "${GREEN}✓ Done${NC}"
}

download_binary() {
    echo -e "${YELLOW}⬇️  Downloading from GitHub Mirror...${NC}"
    mkdir -p "$INSTALL_DIR"
    [ -f "$INSTALL_DIR/DaggerConnect" ] && mv "$INSTALL_DIR/DaggerConnect" "$INSTALL_DIR/DaggerConnect.backup"
    
    if wget -q --show-progress "$BINARY_URL" -O "$INSTALL_DIR/DaggerConnect"; then
        chmod +x "$INSTALL_DIR/DaggerConnect"
        echo -e "${GREEN}✓ Downloaded successfully${NC}"
        rm -f "$INSTALL_DIR/DaggerConnect.backup"
    else
        echo -e "${RED}❌ Download failed! Check GitHub link.${NC}"
        [ -f "$INSTALL_DIR/DaggerConnect.backup" ] && mv "$INSTALL_DIR/DaggerConnect.backup" "$INSTALL_DIR/DaggerConnect"
        exit 1
    fi
}

create_service() {
    local MODE=$1
    cat > "$SYSTEMD_DIR/DaggerConnect-${MODE}.service" << EOF
[Unit]
Description=DaggerConnect ${MODE^}
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$CONFIG_DIR
ExecStart=$INSTALL_DIR/DaggerConnect -c $CONFIG_DIR/${MODE}.yaml
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
}

install_server() {
    show_banner
    mkdir -p "$CONFIG_DIR"
    echo -e "${YELLOW}--- Server Setup ---${NC}"
    read -p "Tunnel Port [2020]: " LP; LP=${LP:-2020}
    read -sp "Enter PSK: " PSK; echo ""
    
    # تنظیمات Port Mapping
    MAPPINGS=""
    while true; do
        read -p "Port to Open on Server: " B_PORT
        MAPPINGS="${MAPPINGS}  - type: tcp\n    bind: \"0.0.0.0:${B_PORT}\"\n    target: \"0.0.0.0:${B_PORT}\"\n"
        read -p "Add another port? [y/N]: " MORE
        [[ ! $MORE =~ ^[Yy]$ ]] && break
    done

    cat > "$CONFIG_DIR/server.yaml" << EOF
mode: "server"
listen: "0.0.0.0:${LP}"
transport: "tcpmux"
psk: "${PSK}"
profile: "balanced"
verbose: false
maps:
$(echo -e "$MAPPINGS")
EOF
    create_service "server"
    systemctl enable --now DaggerConnect-server
    echo -e "${GREEN}✓ Server Installed and Running!${NC}"
    read -p "Press Enter..."
    main_menu
}

install_client() {
    show_banner
    mkdir -p "$CONFIG_DIR"
    echo -e "${YELLOW}--- Client Setup ---${NC}"
    read -sp "Enter PSK (Same as Server): " PSK; echo ""
    read -p "Server IP:Port (e.g. 1.2.3.4:2020): " ADDR
    
    cat > "$CONFIG_DIR/client.yaml" << EOF
mode: "client"
psk: "${PSK}"
profile: "balanced"
paths:
  - transport: "tcpmux"
    addr: "${ADDR}"
    connection_pool: 2
EOF
    create_service "client"
    systemctl enable --now DaggerConnect-client
    echo -e "${GREEN}✓ Client Installed and Running!${NC}"
    read -p "Press Enter..."
    main_menu
}

manage_services() {
    show_banner
    echo "1) Server Status  2) Client Status"
    echo "3) Server Logs    4) Client Logs"
    echo "0) Back"
    read -p "Choice: " c
    case $c in
        1) systemctl status DaggerConnect-server ;;
        2) systemctl status DaggerConnect-client ;;
        3) journalctl -u DaggerConnect-server -f ;;
        4) journalctl -u DaggerConnect-client -f ;;
        *) main_menu ;;
    esac
}

main_menu() {
    show_banner
    echo "1) Install Server (خارج)"
    echo "2) Install Client (ایران - اگر از گیت‌هاب استفاده می‌کنید)"
    echo "3) Service Management"
    echo "4) Uninstall"
    echo "0) Exit"
    read -p "Choice: " choice
    case $choice in
        1) install_server ;;
        2) install_client ;;
        3) manage_services ;;
        4) 
            systemctl stop DaggerConnect-server DaggerConnect-client 2>/dev/null
            rm -rf "$INSTALL_DIR/DaggerConnect" "$CONFIG_DIR" "$SYSTEMD_DIR/DaggerConnect-*"
            echo "Uninstalled." ;;
        0) exit 0 ;;
        *) main_menu ;;
    esac
}

check_root
install_dependencies
[ ! -f "$INSTALL_DIR/DaggerConnect" ] && download_binary
main_menu
