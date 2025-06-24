#!/bin/bash

# === Colors ===
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

# === Root check ===
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Please run this script as root (sudo)${NC}"
  exit 1
fi

# === Welcome banner ===
clear
echo -e "${YELLOW}==================================================${NC}"
echo -e "${GREEN}=         🚀 Nexus Node Setup                    =${NC}"
echo -e "${YELLOW}=               CPI.TM                          =${NC}"
echo -e "${GREEN}=             by billymoor                       =${NC}"
echo -e "${YELLOW}==================================================${NC}\n"

# === Check GLIBC version and install if missing ===
REQUIRED_GLIBC_VERSION="2.39"
INSTALL_GLIBC=false

if [ -f "/opt/glibc-2.39/lib/libc.so.6" ]; then
  INSTALLED_VERSION=$(/opt/glibc-2.39/lib/libc.so.6 | grep GLIBC | awk '{print $NF}' | sort -V | tail -n 1)
  if [[ "$INSTALLED_VERSION" == "$REQUIRED_GLIBC_VERSION" ]]; then
    echo -e "${GREEN}[✓] GLIBC $REQUIRED_GLIBC_VERSION already installed in /opt/glibc-2.39${NC}"
  else
    INSTALL_GLIBC=true
  fi
else
  INSTALL_GLIBC=true
fi

if [ "$INSTALL_GLIBC" = true ]; then
  echo -e "${RED}[!] GLIBC $REQUIRED_GLIBC_VERSION not found. Installing...${NC}"
  wget http://ftp.gnu.org/gnu/libc/glibc-2.39.tar.gz
  tar -xvzf glibc-2.39.tar.gz
  cd glibc-2.39
  mkdir build && cd build
  ../configure --prefix=/opt/glibc-2.39
  make -j$(nproc)
  make install
  cd ../.. && rm -rf glibc-2.39*

  export LD_LIBRARY_PATH=/opt/glibc-2.39/lib:$LD_LIBRARY_PATH
  echo "export LD_LIBRARY_PATH=/opt/glibc-2.39/lib:\$LD_LIBRARY_PATH" >> ~/.bashrc
  source ~/.bashrc

  echo -e "${GREEN}[✓] GLIBC $REQUIRED_GLIBC_VERSION installed successfully!${NC}"
fi

# === Working directory ===
WORKDIR="/root/nexus-prover"
echo -e "${GREEN}[*] Working directory: $WORKDIR${NC}"
mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

# === Install dependencies ===
apt update && apt upgrade -y
apt install -y screen curl wget build-essential pkg-config libssl-dev git-all protobuf-compiler ca-certificates

# === Install Rust if missing ===
if ! command -v rustup &>/dev/null; then
  echo -e "${GREEN}[*] Installing Rust...${NC}"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

# === Setup Rust environment ===
source "$HOME/.cargo/env"
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.bashrc"
source "$HOME/.bashrc"

# === Install Nexus CLI ===
echo -e "${GREEN}[*] Downloading and installing Nexus CLI...${NC}"
yes | curl -s https://cli.nexus.xyz/ | bash

# === Find nexus-network binary ===
echo -e "${GREEN}[*] Locating nexus-network binary...${NC}"
NEXUS_BIN=$(find / -type f -name "nexus-network" -perm /u+x 2>/dev/null | head -n 1)

if [ -x "$NEXUS_BIN" ]; then
  echo -e "${GREEN}[✓] nexus-network found at: $NEXUS_BIN${NC}"
  cp "$NEXUS_BIN" /usr/local/bin/
  chmod +x /usr/local/bin/nexus-network
else
  echo -e "${RED}[!] nexus-network binary not found after install. Aborting.${NC}"
  exit 1
fi

# === Ask user how many nodes ===
echo -e "${YELLOW}[?] How many node IDs do you want to run? (1-10)${NC}"
read -rp "> " NODE_COUNT
if ! [[ "$NODE_COUNT" =~ ^[1-9]$|^10$ ]]; then
  echo -e "${RED}[!] Invalid number. Choose between 1 to 10.${NC}"
  exit 1
fi

# === Read node IDs ===
NODE_IDS=()
for ((i=1;i<=NODE_COUNT;i++)); do
  echo -e "${YELLOW}Enter node-id #$i:${NC}"
  read -rp "> " NODE_ID
  if [ -z "$NODE_ID" ]; then
    echo -e "${RED}[!] Empty node-id. Aborting.${NC}"
    exit 1
  fi
  NODE_IDS+=("$NODE_ID")
done

# === Launch nodes in screen sessions ===
for ((i=0;i<NODE_COUNT;i++)); do
  SESSION_NAME="nexus$((i+1))"
  NODE_ID="${NODE_IDS[$i]}"

  if ! command -v screen &>/dev/null; then
    echo -e "${RED}[!] screen is not installed. Please install screen manually.${NC}"
    exit 1
  fi

  screen -S "$SESSION_NAME" -X quit 2>/dev/null || true

  echo -e "${GREEN}[*] Launching node-id $NODE_ID in screen session '$SESSION_NAME'...${NC}"
  screen -dmS "$SESSION_NAME" bash -c "cd $WORKDIR && LD_LIBRARY_PATH=/opt/glibc-2.39/lib nexus-network start --node-id $NODE_ID"

  sleep 1
  if screen -list | grep -q "$SESSION_NAME"; then
    echo -e "${GREEN}[✓] node-id $NODE_ID running in '$SESSION_NAME'${NC}"
  else
    echo -e "${RED}[!] Failed to start node-id $NODE_ID in '$SESSION_NAME'${NC}"
  fi
  sleep 1
done

# === Final instructions ===
echo -e "${YELLOW}\n[i] To detach logs: CTRL+A then D"
echo -e "[i] To reattach: screen -r nexus1 (or nexus2, etc.)"
echo -e "[i] To stop: screen -XS nexusX quit"
echo -e "[i] To cleanup: rm -rf $WORKDIR${NC}"

# === Auto-start Nexus CLI ===
echo -e "${GREEN}[*] Starting Nexus CLI with node-id $NODE_ID...${NC}"
LD_LIBRARY_PATH=/opt/glibc-2.39/lib nexus-network start --node-id "$NODE_ID"
