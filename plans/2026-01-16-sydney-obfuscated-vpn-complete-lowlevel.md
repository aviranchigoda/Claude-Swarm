# Sydney Obfuscated VPN - Complete Low-Level Engineering Lockdown Document

## Configuration Summary

| Parameter | Value |
|-----------|-------|
| **Protocol** | OpenVPN TCP + Obfuscation |
| **Target Server** | Sydney (Australia) Obfuscated |
| **Primary Use Case** | SSH to Sydney servers (latency-critical) |
| **Server Mode** | Dual-server (Netherlands + Sydney available) |
| **Obfuscation Source** | NordVPN obfuscated server configs |

---

## Part 1: Current Infrastructure Analysis

### Existing Files in /Desktop/software/cybersecurity/

| File | Size | Purpose | Status |
|------|------|---------|--------|
| `nl890.nordvpn.com.tcp.ovpn` | 2.8KB | Netherlands TCP/443 OpenVPN config | Active |
| `NORD-TUNNEL-LINK.md` | 30KB | Tunnelblick auto-auth setup guide | Reference |
| `VPN-LOCKDOWN-ENTERPRISE.md` | 23KB | PF firewall kill-switch | Partial implementation |
| `SSH_LATENCY_ENGINEERING_PLAN.md` | 21KB | Latency optimization techniques | Reference |
| `installation.md` | 42KB | Step-by-step lockdown installation | Reference |
| `Tunnelblick-problems.md` | 45KB | Extended attribute troubleshooting | Reference |
| `NORD-TUNNEL-CLAUDE-HISTORY.md` | 74KB | Configuration troubleshooting history | History |

### Current OpenVPN Configuration Analysis (nl890.nordvpn.com.tcp.ovpn)

```
client
dev tun
proto tcp                    # ← TCP causes latency issues
remote 213.232.87.111 443    # ← Netherlands server
tun-mtu 1500
mssfix 1450
cipher AES-256-CBC           # ← CBC mode, slower than GCM
auth SHA512                  # ← Overkill, adds overhead
comp-lzo no                  # ← Deprecated directive
```

**Issues Identified:**
1. TCP protocol adds ~50-150ms latency due to TCP-over-TCP meltdown
2. AES-256-CBC lacks hardware acceleration benefits of GCM mode
3. SHA512 unnecessary overhead (SHA256 is sufficient)
4. No obfuscation - traffic identifiable as OpenVPN by DPI
5. Geographic distance: Netherlands → Sydney = 16,000+ km

---

## Part 2: Low-Level Engineering Architecture

### Network Stack Layers

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    COMPLETE VPN LOCKDOWN ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  LAYER 0: HARDWARE (Network Interface Controller)                           │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │  • Intel/Broadcom NIC with hardware offload                        │     │
│  │  • AES-NI instruction set for hardware crypto acceleration         │     │
│  │  • TSO/GSO/GRO offload for packet segmentation                    │     │
│  └────────────────────────────────────────────────────────────────────┘     │
│                                                                              │
│  LAYER 1: KERNEL (Darwin XNU Network Stack)                                 │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │  • sysctl tunables for TCP buffer sizes                           │     │
│  │  • Delayed ACK configuration                                       │     │
│  │  • Window scaling (RFC 1323)                                       │     │
│  │  • Congestion control algorithm                                    │     │
│  └────────────────────────────────────────────────────────────────────┘     │
│                                                                              │
│  LAYER 2: PACKET FILTER (PF Firewall - BSD)                                 │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │  • Default DENY policy for all traffic                            │     │
│  │  • Whitelist: VPN server IPs only                                 │     │
│  │  • Allow: utun interfaces (VPN tunnel)                            │     │
│  │  • Block: IPv6 completely (leak prevention)                       │     │
│  │  • LaunchDaemon: Activates at boot before user login              │     │
│  └────────────────────────────────────────────────────────────────────┘     │
│                                                                              │
│  LAYER 3: OBFUSCATION (Traffic Disguise)                                    │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │  • XOR scramble (NordVPN obfuscated servers)                      │     │
│  │  • Traffic masquerades as HTTPS (port 443)                        │     │
│  │  • Defeats Deep Packet Inspection (DPI)                           │     │
│  │  • Random packet padding to defeat traffic analysis               │     │
│  └────────────────────────────────────────────────────────────────────┘     │
│                                                                              │
│  LAYER 4: VPN TUNNEL (OpenVPN)                                              │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │  • Encrypted tunnel over TCP/443                                  │     │
│  │  • AES-128-GCM cipher (hardware accelerated)                      │     │
│  │  • TLS 1.3 control channel                                        │     │
│  │  • Perfect Forward Secrecy (PFS)                                  │     │
│  └────────────────────────────────────────────────────────────────────┘     │
│                                                                              │
│  LAYER 5: DNS SECURITY                                                      │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │  • DNS forced through VPN tunnel                                  │     │
│  │  • block-outside-dns directive                                    │     │
│  │  • No system DNS leaks                                            │     │
│  └────────────────────────────────────────────────────────────────────┘     │
│                                                                              │
│  LAYER 6: APPLICATION (Tunnelblick + SSH)                                   │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │  • Auto-connect on launch                                         │     │
│  │  • Kill switch: Disable network on disconnect                     │     │
│  │  • SSH: Multiplexing, compression, optimized ciphers              │     │
│  └────────────────────────────────────────────────────────────────────┘     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Part 3: Implementation Steps

### Step 1: Obtain Sydney Obfuscated Server Configuration

**Action Required:**
1. Log in to https://my.nordaccount.com/
2. Navigate to: **NordVPN** → **Advanced Configuration** → **OpenVPN Configuration Files**
3. Select:
   - Country: **Australia**
   - Protocol: **TCP**
   - Obfuscated: **Yes** (critical!)
4. Download the `.ovpn` file (likely named `au###.nordvpn.com.tcp.ovpn`)

**Expected filename format:** `au[server-number].nordvpn.com.tcp.ovpn`
- Example: `au580.nordvpn.com.tcp.ovpn`

### Step 2: Create Optimized Sydney Configuration

After downloading, the config needs optimization for SSH latency:

**File: `/Desktop/software/cybersecurity/au-sydney-obfs.ovpn`**

```openvpn
# ============================================================================
# SYDNEY OBFUSCATED VPN - OPTIMIZED FOR SSH LATENCY
# ============================================================================

client
dev tun
proto tcp

# --- SERVER CONNECTION ---
# Replace with actual Sydney obfuscated server IP from downloaded config
remote [SYDNEY_SERVER_IP] 443
remote-random

# --- TUNNEL SETTINGS ---
nobind
tun-mtu 1400                    # Reduced from 1500 to prevent fragmentation
mssfix 1360                     # MSS clamping for TCP-over-TCP
tcp-nodelay                     # CRITICAL: Disable Nagle's algorithm

# --- CRYPTO OPTIMIZATION ---
cipher AES-128-GCM              # Hardware accelerated, faster than AES-256-CBC
auth SHA256                     # Sufficient security, less overhead than SHA512
tls-cipher TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256
tls-version-min 1.2

# --- PERFORMANCE ---
fast-io
sndbuf 524288                   # 512KB send buffer
rcvbuf 524288                   # 512KB receive buffer
txqueuelen 1000

# --- KEEPALIVE ---
ping 10                         # More aggressive than default 15
ping-restart 60
keepalive 10 60

# --- RECONNECTION ---
resolv-retry infinite
connect-retry 2                 # Fast retry on failure
connect-retry-max 5

# --- AUTHENTICATION ---
auth-user-pass auth.txt
verify-x509-name [SERVER_CN] name  # Replace with CN from downloaded config
remote-cert-tls server

# --- LOGGING ---
verb 3
mute 10

# --- CERTIFICATES (Copy from downloaded config) ---
<ca>
# ... CA certificate from NordVPN ...
</ca>

key-direction 1
<tls-auth>
# ... TLS auth key from NordVPN ...
</tls-auth>
```

**Critical optimizations explained:**
- `tcp-nodelay`: Disables Nagle's algorithm, reduces keystroke latency
- `AES-128-GCM`: Uses hardware AES-NI, ~30% faster than CBC
- `sndbuf/rcvbuf 524288`: Large buffers for high-latency links
- `ping 10`: Faster detection of connection issues
- `mtu 1400`: Prevents fragmentation over VPN-over-TCP

### Step 3: Kernel Network Stack Tuning

**File: `/etc/sysctl.conf`** (Create if doesn't exist)

```bash
# ============================================================================
# macOS KERNEL NETWORK TUNING FOR HIGH-LATENCY VPN
# ============================================================================

# TCP Buffer Sizes (critical for high-latency)
net.inet.tcp.sendspace=262144
net.inet.tcp.recvspace=262144

# Socket Buffer Maximum
kern.ipc.maxsockbuf=8388608

# Window Scaling (RFC 1323) - essential for WAN
net.inet.tcp.rfc1323=1

# Disable Delayed ACK (reduces latency significantly)
net.inet.tcp.delayed_ack=0

# Increase Initial Congestion Window
net.inet.tcp.slowstart_flightsize=20
net.inet.tcp.local_slowstart_flightsize=20

# MSS Default
net.inet.tcp.mssdflt=1440

# Disable TCP slow-start after idle
net.inet.tcp.always_keepalive=1
```

**Apply immediately:**
```bash
sudo sysctl -w net.inet.tcp.sendspace=262144
sudo sysctl -w net.inet.tcp.recvspace=262144
sudo sysctl -w kern.ipc.maxsockbuf=8388608
sudo sysctl -w net.inet.tcp.rfc1323=1
sudo sysctl -w net.inet.tcp.delayed_ack=0
sudo sysctl -w net.inet.tcp.slowstart_flightsize=20
sudo sysctl -w net.inet.tcp.mssdflt=1440
```

### Step 4: Update PF Firewall for Dual-Server Support

**File: `/etc/pf.anchors/vpn-lockdown`**

```pf
# ============================================================================
# VPN LOCKDOWN - DUAL SERVER (NETHERLANDS + SYDNEY)
# ============================================================================

# --- SERVER DEFINITIONS ---
# Netherlands Server (existing)
vpn_nl = "213.232.87.111"

# Sydney Obfuscated Server (UPDATE WITH ACTUAL IP)
vpn_au = "SYDNEY_SERVER_IP"

# Combined server list
vpn_servers = "{ 213.232.87.111, SYDNEY_SERVER_IP }"

# Ports
vpn_port = "443"

# VPN Tunnel Interfaces
vpn_if = "{ utun0, utun1, utun2, utun3, utun4, utun5, utun6, utun7, utun8, utun9 }"

# Local DNS (update for your router)
local_dns = "{ 192.168.0.1, 192.168.1.1, 10.0.0.1 }"

# --- OPTIONS ---
set skip on lo0

# --- DEFAULT POLICY: BLOCK EVERYTHING ---
block in all
block out all

# Block IPv6 completely (leak prevention)
block quick inet6 all

# --- EXCEPTION RULES ---

# Allow VPN tunnel traffic
pass quick on $vpn_if all

# Allow connection to VPN servers
pass out quick proto tcp from any to $vpn_servers port $vpn_port

# Allow responses from VPN servers
pass in quick proto tcp from $vpn_servers port $vpn_port to any

# Allow DHCP
pass out quick proto udp from any port 68 to any port 67
pass in quick proto udp from any port 67 to any port 68

# Allow local DNS (for initial VPN hostname resolution)
pass out quick proto udp from any to $local_dns port 53
pass in quick proto udp from $local_dns port 53 to any

# ============================================================================
```

### Step 5: SSH Optimization for Sydney

**File: `~/.ssh/config`**

```ssh-config
# ============================================================================
# SSH CONFIGURATION - OPTIMIZED FOR SYDNEY VIA VPN
# ============================================================================

Host sydney-* au-*
    # Connection Multiplexing
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600

    # Compression (helps over VPN)
    Compression yes

    # Fastest ciphers (AES-NI accelerated)
    Ciphers aes128-gcm@openssh.com,chacha20-poly1305@openssh.com

    # Fast key exchange
    KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org

    # Reduce connection overhead
    AddressFamily inet

    # Keepalive
    ServerAliveInterval 30
    ServerAliveCountMax 3

    # Disable unused features
    ForwardAgent no
    ForwardX11 no

# Default for all hosts
Host *
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600
```

**Create socket directory:**
```bash
mkdir -p ~/.ssh/sockets
chmod 700 ~/.ssh/sockets
```

### Step 6: Create Tunnelblick Configuration Bundle

**Directory structure for Sydney config:**
```
au-sydney-obfs.tblk/
└── Contents/
    └── Resources/
        ├── config.ovpn      # Optimized Sydney config
        └── auth.txt         # Credentials
```

**Commands:**
```bash
# Create bundle structure
sudo mkdir -p "/Library/Application Support/Tunnelblick/Shared/au-sydney-obfs.tblk/Contents/Resources"

# Copy config (after you've customized it)
sudo cp ~/Desktop/software/cybersecurity/au-sydney-obfs.ovpn \
    "/Library/Application Support/Tunnelblick/Shared/au-sydney-obfs.tblk/Contents/Resources/config.ovpn"

# Create auth.txt
sudo nano "/Library/Application Support/Tunnelblick/Shared/au-sydney-obfs.tblk/Contents/Resources/auth.txt"
# Enter: username on line 1, password on line 2

# Set permissions
TBLK="/Library/Application Support/Tunnelblick/Shared/au-sydney-obfs.tblk"
sudo chown -R root:wheel "$TBLK"
sudo chmod 755 "$TBLK" "$TBLK/Contents" "$TBLK/Contents/Resources"
sudo chmod 644 "$TBLK/Contents/Resources/config.ovpn"
sudo chmod 600 "$TBLK/Contents/Resources/auth.txt"
```

---

## Part 4: Privacy Hardening Checklist

### DNS Leak Prevention
- [ ] OpenVPN config includes `block-outside-dns` (if supported)
- [ ] PF firewall blocks external DNS (only local router allowed)
- [ ] Tunnelblick "Set DNS/WINS" = "Set nameserver"

### IPv6 Leak Prevention
- [ ] PF rule: `block quick inet6 all`
- [ ] Tunnelblick: "Disable IPv6 unless VPN server accessed using IPv6" = checked

### WebRTC Leak Prevention (Browser)
- [ ] Firefox: `media.peerconnection.enabled` = false
- [ ] Chrome: Install WebRTC Leak Prevent extension

### Kill Switch
- [ ] PF firewall active at boot (LaunchDaemon)
- [ ] Tunnelblick: "On unexpected disconnect" = "Disable network access"
- [ ] Tunnelblick: "On expected disconnect" = "Disable network access"

---

## Part 5: Performance Expectations

### Latency Comparison

| Route | Current (NL) | Target (Sydney) | Improvement |
|-------|--------------|-----------------|-------------|
| MacBook → VPN Server | ~30ms | ~30ms | Same |
| VPN Server → Sydney | ~300ms | ~10ms | 97% |
| **Total RTT** | **~330ms** | **~40ms** | **88%** |

*Note: TCP-over-TCP adds ~50-150ms overhead regardless of server location*

### Why TCP + Obfuscation (Your Choice) Impacts Speed

You chose TCP + Obfuscation for compatibility. Important tradeoffs:

**Advantages:**
- Bypasses restrictive firewalls/DPI
- Port 443 appears as HTTPS traffic
- Most compatible with corporate/hotel networks

**Disadvantages:**
- TCP meltdown: Inner TCP (SSH) + Outer TCP (VPN) = exponential retransmits
- Obfuscation adds ~5-20ms processing overhead
- Cannot use UDP fast-path

**Mitigation for SSH specifically:**
Use **Mosh** (Mobile Shell) instead of SSH when possible:
```bash
brew install mosh
mosh user@sydney-server
```
Mosh uses UDP inside the VPN tunnel, avoiding TCP meltdown for the application layer.

---

## Part 6: Complete Installation Script

```bash
#!/bin/bash
# ============================================================================
# SYDNEY OBFUSCATED VPN - COMPLETE INSTALLATION
# Run after downloading Sydney obfuscated .ovpn from NordVPN
# ============================================================================

set -e

# Variables (UPDATE THESE)
SYDNEY_OVPN="$HOME/Downloads/au###.nordvpn.com.tcp.ovpn"  # Path to downloaded config
SYDNEY_IP="UPDATE_WITH_ACTUAL_IP"                          # From the .ovpn file
NL_IP="213.232.87.111"                                     # Existing Netherlands server

echo "=== Sydney Obfuscated VPN Installation ==="

# 1. Create kernel tuning
echo "[1/6] Applying kernel network tuning..."
sudo sysctl -w net.inet.tcp.sendspace=262144
sudo sysctl -w net.inet.tcp.recvspace=262144
sudo sysctl -w kern.ipc.maxsockbuf=8388608
sudo sysctl -w net.inet.tcp.delayed_ack=0
sudo sysctl -w net.inet.tcp.rfc1323=1

# 2. Create SSH socket directory
echo "[2/6] Setting up SSH multiplexing..."
mkdir -p ~/.ssh/sockets
chmod 700 ~/.ssh/sockets

# 3. Create Tunnelblick bundle
echo "[3/6] Creating Tunnelblick configuration..."
TBLK="/Library/Application Support/Tunnelblick/Shared/au-sydney-obfs.tblk"
sudo mkdir -p "$TBLK/Contents/Resources"
sudo cp "$SYDNEY_OVPN" "$TBLK/Contents/Resources/config.ovpn"

# 4. Prompt for credentials
echo "[4/6] Creating auth.txt..."
echo "Enter NordVPN service username:"
read USERNAME
echo "Enter NordVPN service password:"
read -s PASSWORD
echo "$USERNAME" | sudo tee "$TBLK/Contents/Resources/auth.txt" > /dev/null
echo "$PASSWORD" | sudo tee -a "$TBLK/Contents/Resources/auth.txt" > /dev/null

# 5. Set permissions
echo "[5/6] Setting permissions..."
sudo chown -R root:wheel "$TBLK"
sudo chmod 755 "$TBLK" "$TBLK/Contents" "$TBLK/Contents/Resources"
sudo chmod 644 "$TBLK/Contents/Resources/config.ovpn"
sudo chmod 600 "$TBLK/Contents/Resources/auth.txt"

# 6. Update PF firewall (manual step required)
echo "[6/6] PF Firewall update required..."
echo ""
echo "MANUAL STEP: Edit /etc/pf.anchors/vpn-lockdown"
echo "Add Sydney server IP: $SYDNEY_IP"
echo ""
echo "Command: sudo nano /etc/pf.anchors/vpn-lockdown"
echo "Then reload: sudo pfctl -f /etc/pf.conf"

echo ""
echo "=== Installation Complete ==="
echo "Restart Tunnelblick to see the new Sydney configuration."
```

---

## Part 7: Verification Commands

After installation, verify everything works:

```bash
# 1. Check Sydney IP after connecting
curl -s ifconfig.me
# Expected: Australian IP address

# 2. Verify DNS (no leaks)
dig +short whoami.akamai.net
# Expected: Should resolve through VPN DNS

# 3. Test SSH latency to Sydney
time ssh -o ConnectTimeout=10 user@sydney-server "echo connected"
# Expected: <500ms with TCP, <200ms if server is actually in Sydney

# 4. Verify PF firewall is active
sudo pfctl -s info | grep Status
# Expected: Status: Enabled

# 5. Test kill switch (disconnect VPN, try internet)
curl -m 5 https://google.com
# Expected: Timeout (blocked by firewall)

# 6. Check which utun interface VPN is using
ifconfig | grep utun
# Expected: utun0 or similar with IP assigned
```

---

## Part 8: Files to Create/Modify Summary

| File | Action | Location |
|------|--------|----------|
| `au-sydney-obfs.ovpn` | Download + optimize | ~/Desktop/software/cybersecurity/ |
| `au-sydney-obfs.tblk` | Create bundle | /Library/.../Tunnelblick/Shared/ |
| `/etc/pf.anchors/vpn-lockdown` | Add Sydney IP | System |
| `/etc/sysctl.conf` | Create/update | System |
| `~/.ssh/config` | Add Sydney host config | User |
| `~/.ssh/sockets/` | Create directory | User |

---

## Part 9: Next Steps After Plan Approval

1. **You provide**: Sydney obfuscated server IP from downloaded config
2. **I will create**: Complete optimized config files
3. **You execute**: Installation script
4. **We verify**: Connection, speed, and privacy tests
