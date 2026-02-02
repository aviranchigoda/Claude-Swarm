# WireGuard VPN Setup Plan

## Goal
Replace complex Shadowsocks + proxychains + pf lockdown setup with a simple WireGuard VPN that routes all traffic through your Sydney VPS automatically.

## Current Status
- **VPS**: 149.28.188.224 (Vultr Sydney, Ubuntu 24.04 LTS)
- **SSH**: Configured but currently failing - need to fix first
- **Mac**: Ready for WireGuard client

---

## Phase 1: Fix SSH Access (YOU DO THIS MANUALLY)

**Problem**: SSH key authentication failing with "Permission denied (publickey,password)"

**Steps**:
1. Go to https://my.vultr.com → click your Sydney server
2. Click **"View Console"** button (opens web-based terminal)
3. Log in as `root` (use existing password or reset via Vultr dashboard)
4. Run these commands in the web console:

```bash
mkdir -p ~/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICL+UnPlnLPbM89RdHTikoNEdetOp0vvkDbvwiIdra+U linode-auto" >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

5. **Tell me when done** - I'll test SSH and continue with WireGuard installation

---

## Phase 2: Install WireGuard Server (on VPS)

**Commands to run on VPS**:
```bash
# Update system
apt update && apt upgrade -y

# Install WireGuard
apt install wireguard -y

# Generate server keys
cd /etc/wireguard
wg genkey | tee server_private.key | wg pubkey > server_public.key
chmod 600 server_private.key

# Create server config
cat > /etc/wireguard/wg0.conf << 'EOF'
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = SERVER_PRIVATE_KEY
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = CLIENT_PUBLIC_KEY
AllowedIPs = 10.0.0.2/32
EOF

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Open firewall port
ufw allow 51820/udp

# Start WireGuard
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
```

---

## Phase 3: Install WireGuard Client (on Mac)

**Steps**:
```bash
# Install WireGuard
brew install wireguard-tools

# Generate client keys
mkdir -p ~/.wireguard
cd ~/.wireguard
wg genkey | tee client_private.key | wg pubkey > client_public.key

# Create client config
cat > ~/.wireguard/sydney.conf << 'EOF'
[Interface]
PrivateKey = CLIENT_PRIVATE_KEY
Address = 10.0.0.2/24
DNS = 1.1.1.1

[Peer]
PublicKey = SERVER_PUBLIC_KEY
Endpoint = 149.28.188.224:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
```

**Or**: Install WireGuard GUI app from Mac App Store for easier on/off toggle

---

## Phase 4: Exchange Keys & Connect

1. Copy client public key to server config (replace CLIENT_PUBLIC_KEY)
2. Copy server public key to client config (replace SERVER_PUBLIC_KEY)
3. Restart WireGuard on server: `systemctl restart wg-quick@wg0`
4. Connect from Mac:
   ```bash
   sudo wg-quick up ~/.wireguard/sydney.conf
   ```

---

## Phase 5: Verify & Test

```bash
# Check connection status
sudo wg show

# Verify IP is Sydney
curl https://ifconfig.me
# Should return: 149.28.188.224

# Verify all traffic routed
curl https://ipinfo.io/country
# Should return: AU
```

---

## Phase 6: Optional Cleanup

Remove old Shadowsocks setup (after WireGuard is working):
```bash
# Stop Shadowsocks
pkill ss-local

# Disable pf if enabled
sudo pfctl -d

# Optionally uninstall
brew uninstall shadowsocks-libev proxychains-ng
```

---

## Files Modified

| Location | Purpose |
|----------|---------|
| VPS: /etc/wireguard/wg0.conf | Server config |
| Mac: ~/.wireguard/sydney.conf | Client config |
| VPS: /etc/sysctl.conf | Enable IP forwarding |

---

## Verification Checklist

- [ ] SSH access to VPS working
- [ ] WireGuard installed on VPS
- [ ] WireGuard installed on Mac
- [ ] Keys exchanged
- [ ] Connection established (`sudo wg show` shows handshake)
- [ ] IP shows as 149.28.188.224
- [ ] All websites accessible
- [ ] DNS working (no leaks)

---

## Rollback

If something breaks:
```bash
# On Mac - disconnect WireGuard
sudo wg-quick down ~/.wireguard/sydney.conf

# Direct internet restored immediately
```
