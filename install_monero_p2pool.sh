#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ Error occurred on line $LINENO. Exiting." >&2' ERR

# 1. Ensure running as root
if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root (use sudo)." >&2
  exit 1
fi

echo ">>> Monero + P2Pool Installer for Debian/Ubuntu <<<"

# 2. Check system architecture (must be 64-bit)
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|aarch64) 
    echo "Architecture $ARCH detected – proceeding." ;;
  *) 
    echo "Unsupported architecture ($ARCH). Monero and P2Pool require 64-bit (ARM64 or x86_64)." >&2
    exit 1 ;;
esac

# Update package index
apt-get update

# Install required packages (build tools, libraries, etc.)
echo "Installing build dependencies..."
DEPS="build-essential cmake pkg-config git curl autoconf libtool \
      gperf libssl-dev libzmq3-dev libunbound-dev libsodium-dev libunwind8-dev \
      liblzma-dev libreadline6-dev libexpat1-dev qttools5-dev-tools libhidapi-dev \
      libusb-1.0-0-dev libprotobuf-dev protobuf-compiler libudev-dev \
      libboost-chrono-dev libboost-date-time-dev libboost-filesystem-dev \
      libboost-locale-dev libboost-program-options-dev libboost-regex-dev \
      libboost-serialization-dev libboost-system-dev libboost-thread-dev \
      python3 ccache doxygen graphviz \
      libuv1-dev libpgm-dev libnorm-dev libgss-dev libcurl4-openssl-dev libidn2-0-dev"
apt-get install -y $DEPS

# 3. Fetch latest Monero source code
MONERO_REPO="https://github.com/monero-project/monero.git"
MONERO_DIR="/tmp/monero"
echo "Cloning Monero source from $MONERO_REPO ..."
git clone --recursive -b release-v0.18 "$MONERO_REPO" "$MONERO_DIR"

# 4. Compile Monero (monerod)
echo "Compiling Monero (this may take a while)..."
cd "$MONERO_DIR"
# Use all available cores; USE_SINGLE_BUILDDIR for consistent output path
make -j"$(nproc)" USE_SINGLE_BUILDDIR=1
# Install monerod (and other binaries) to /usr/local/bin
cp build/release/bin/monero* /usr/local/bin/ 2>/dev/null || true
cp build/release/bin/monerod /usr/local/bin/  # ensure monerod is copied

# 5. Fetch latest P2Pool source code
P2POOL_REPO="https://github.com/SChernykh/p2pool.git"
P2POOL_DIR="/tmp/p2pool"
echo "Cloning P2Pool source from $P2POOL_REPO ..."
git clone --recursive "$P2POOL_REPO" "$P2POOL_DIR"

# 6. Compile P2Pool
echo "Compiling P2Pool..."
cd "$P2POOL_DIR"
mkdir build && cd build
cmake ..
make -j"$(nproc)"
# Install p2pool binary to /usr/local/bin
cp p2pool /usr/local/bin/

# 7. Prompt for P2Pool wallet address
read -p "Enter your PRIMARY Monero wallet address for P2Pool payouts: " WALLET_ADDR
# Basic validation of address
while [[ ! "$WALLET_ADDR" =~ ^4[0-9A-Za-z]{94}$ ]]; do
  echo "Address not valid (must start with 4 and be 95 characters). Please try again."
  read -p "Enter your PRIMARY Monero wallet address for P2Pool payouts: " WALLET_ADDR
done
echo "P2Pool will pay out to: $WALLET_ADDR"

# 8. Create system users for monero and p2pool (if not exist)
id -u monero &>/dev/null || useradd --system -d /var/lib/monero -m -s /usr/sbin/nologin monero
id -u p2pool &>/dev/null || useradd --system -d /var/lib/p2pool -m -s /usr/sbin/nologin p2pool

# 9. Create directories for config, data, and logs
mkdir -p /etc/monero /var/lib/monero /var/log/monero
mkdir -p /var/lib/p2pool
# Set ownership
chown -R monero:monero /var/lib/monero /var/log/monero
chown -R p2pool:p2pool /var/lib/p2pool

# 10. Prompt for full or pruned blockchain
PRUNE_MODE=""
while [[ "$PRUNE_MODE" != "full" && "$PRUNE_MODE" != "pruned" ]]; do
  read -p "Do you want to run a full node (full) or pruned node (pruned)? [full/pruned]: " PRUNE_MODE
  PRUNE_MODE="${PRUNE_MODE,,}"  # to lowercase
done
if [[ "$PRUNE_MODE" == "pruned" ]]; then
  echo "You chose pruned mode. (Make sure you have at least ~100GB free disk space.)"
  PRUNE_FLAG="prune-blockchain=1"
else
  echo "You chose full node. (Make sure you have at least ~300GB free disk space.)"
  PRUNE_FLAG=""
fi

# 11. Create monerod config file
cat > /etc/monero/monerod.conf <<EOF
# monerod configuration
data-dir=/var/lib/monero
log-file=/var/log/monero/monero.log
p2p-bind-ip=0.0.0.0
p2p-bind-port=18080
rpc-bind-ip=127.0.0.1
rpc-bind-port=18081
max-concurrency=1
$PRUNE_FLAG
# Enable ZMQ for P2Pool (block notifications)
zmq-pub=tcp://127.0.0.1:18083
EOF
chmod 644 /etc/monero/monerod.conf

# 12. Create systemd service for monerod
cat > /etc/systemd/system/monerod.service <<EOF
[Unit]
Description=Monero Daemon (monerod)
After=network-online.target

[Service]
# Run as 'monero' user
User=monero
Group=monero
Type=forking
ExecStart=/usr/local/bin/monerod --detach --config-file /etc/monero/monerod.conf --pidfile /run/monero/monerod.pid
ExecStartPost=/bin/sleep 0.1
PIDFile=/run/monero/monerod.pid
# Auto-restart on failure
Restart=on-failure
RestartSec=30
RuntimeDirectory=monero

[Install]
WantedBy=multi-user.target
EOF

# 13. Create systemd service for p2pool
cat > /etc/systemd/system/p2pool.service <<EOF
[Unit]
Description=P2Pool (Monero) mining node
After=network-online.target

[Service]
User=p2pool
Group=p2pool
WorkingDirectory=/var/lib/p2pool
ExecStart=/usr/local/bin/p2pool --host 127.0.0.1 --wallet $WALLET_ADDR
# (P2Pool default ports: 37889 for P2P, 3333 for stratum)
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 14. Enable and start the services
echo "Enabling and starting monerod and p2pool services..."
systemctl daemon-reload
systemctl enable monerod.service p2pool.service
systemctl start monerod.service p2pool.service

# 15. Set up UFW firewall
echo "Configuring UFW firewall..."
apt-get install -y ufw
ufw allow OpenSSH > /dev/null 2>&1 || true  # allow SSH if applicable
ufw allow 18080/tcp   # Monero P2P
ufw allow 37889/tcp   # P2Pool P2P (main chain)
# Ask about P2Pool stratum port
read -p "Should the P2Pool stratum port 3333 be accessible from the internet? [y/N]: " OPEN_STRATUM
OPEN_STRATUM="${OPEN_STRATUM,,}"  # lowercase
if [[ "$OPEN_STRATUM" == "y" || "$OPEN_STRATUM" == "yes" ]]; then
  ufw allow 3333/tcp
  echo "Allowed port 3333 for external miners."
else
  echo "Keeping port 3333 closed to external connections."
fi
ufw --force enable

# 16. Alias for monero-status
echo "Adding 'monero-status' alias for checking sync status."
cat > /etc/profile.d/monero_alias.sh <<'ALIAS'
alias monero-status='curl -s http://127.0.0.1:18081/get_info | tr "," "\n" | grep -E "height|target_height"'
ALIAS

echo "✅ Installation complete. Monero (monerod) and P2Pool are running as services."
echo "- To check Monero daemon status: systemctl status monerod"
echo "- To check P2Pool status: systemctl status p2pool (or view /var/lib/p2pool/p2pool.log)"
echo "- To view sync progress at any time, use the 'monero-status' alias (may need to re-login for alias to take effect)."
