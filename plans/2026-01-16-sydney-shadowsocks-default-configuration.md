# Sydney Shadowsocks Default Configuration - MacBook M2 Pro Lockdown Plan

## Executive Summary

This plan adapts your existing VPN lockdown infrastructure to enforce that your MacBook M2 Pro **only connects to the internet via the Sydney Shadowsocks proxy**. All WiFi connections will be blocked unless traffic routes through the `149.28.188.224:443` Shadowsocks server.

---

## Current Infrastructure (Verified Working)

### Sydney Shadowsocks Server
| Parameter | Value |
|-----------|-------|
| **Server IP** | 149.28.188.224 |
| **Port** | 443 (HTTPS stealth) |
| **Password** | kfk/ZlfhrfFxxW9rF3y7MCIy8p7ChsDRgLyiphmToZU= |
| **Encryption** | chacha20-ietf-poly1305 |
| **Location** | Sydney, Australia (Vultr) |
| **Status** | DEPLOYED AND OPERATIONAL |

### Current Client Configuration
| Component | Path |
|-----------|------|
| **Binary** | `/opt/homebrew/bin/ss-local` |
| **Config** | `~/.shadowsocks/config.json` |
| **Local Proxy** | `127.0.0.1:1080` (SOCKS5) |
| **LaunchAgent** | `~/Library/LaunchAgents/com.shadowsocks.client.plist` |

### Existing Lockdown Infrastructure (Currently for NordVPN)
| Component | Path |
|-----------|------|
| **PF Rules** | `/etc/pf.anchors/vpn-lockdown` |
| **Main PF Config** | `/etc/pf.conf` |
| **LaunchDaemon** | `/Library/LaunchDaemons/com.cybersecurity.vpn-lockdown.plist` |

---

## Implementation Plan

### Phase 1: Create Shadowsocks-Specific PF Firewall Rules

**File to create:** `/etc/pf.anchors/shadowsocks-lockdown`

```pf
# ==============================================================================
# SHADOWSOCKS LOCKDOWN - Sydney Proxy Only (FULL DNS PROTECTION)
# ==============================================================================
# All traffic blocked except:
# 1. Direct TCP/UDP to Sydney Shadowsocks server (149.28.188.224:443)
# 2. Loopback interface (required for local SOCKS5 proxy)
# 3. DHCP (required for WiFi IP assignment)
#
# DNS: BLOCKED - All DNS routed through SOCKS5h tunnel (no leaks)
# ==============================================================================

# MACROS
ss_server = "149.28.188.224"
ss_port = "443"
lo_if = "lo0"

# OPTIONS
set skip on $lo_if                       # Allow loopback (127.0.0.1:1080)
set block-policy drop                    # Silently drop blocked packets
set state-policy if-bound                # State tracking per interface

# DEFAULT POLICY: BLOCK EVERYTHING
block quick inet6 all                    # Block ALL IPv6 (leak prevention)
block in all                             # Block all inbound by default
block out all                            # Block all outbound by default

# EXCEPTION RULES (Order matters - 'quick' stops rule processing)

# 1. Allow DHCP (required for WiFi to obtain IP address)
pass out quick proto udp from any port 68 to any port 67
pass in quick proto udp from any port 67 to any port 68

# 2. Allow outbound to Shadowsocks server ONLY (TCP and UDP)
pass out quick proto tcp from any to $ss_server port $ss_port flags S/SA keep state
pass out quick proto udp from any to $ss_server port $ss_port keep state

# 3. Allow inbound responses from Shadowsocks server
pass in quick proto tcp from $ss_server port $ss_port to any flags S/SA keep state
pass in quick proto udp from $ss_server port $ss_port to any keep state

# NOTE: NO DNS rules - all DNS must go through SOCKS5h tunnel
# This provides complete DNS leak protection
```

**Actions:**
1. Create `/etc/pf.anchors/shadowsocks-lockdown` with above rules
2. Backup existing `/etc/pf.conf`
3. Modify `/etc/pf.conf` to load shadowsocks anchor instead of vpn-lockdown

---

### Phase 2: Upgrade Shadowsocks Client to LaunchDaemon (Boot-Level)

The current LaunchAgent (`~/Library/LaunchAgents/com.shadowsocks.client.plist`) runs at user login. We need a **LaunchDaemon** that runs at boot, before user login.

**File to create:** `/Library/LaunchDaemons/com.shadowsocks.client.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.shadowsocks.client</string>

    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/ss-local</string>
        <string>-c</string>
        <string>/etc/shadowsocks/config.json</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/var/log/shadowsocks.log</string>

    <key>StandardErrorPath</key>
    <string>/var/log/shadowsocks.error.log</string>

    <key>ProcessType</key>
    <string>Background</string>
</dict>
</plist>
```

**Actions:**
1. Copy config from `~/.shadowsocks/config.json` to `/etc/shadowsocks/config.json` (root-owned)
2. Create the LaunchDaemon plist
3. Set ownership: `sudo chown root:wheel /Library/LaunchDaemons/com.shadowsocks.client.plist`
4. Set permissions: `sudo chmod 644 /Library/LaunchDaemons/com.shadowsocks.client.plist`
5. Disable the existing LaunchAgent to avoid conflicts

---

### Phase 3: Create Firewall Activation LaunchDaemon

**File to create:** `/Library/LaunchDaemons/com.cybersecurity.shadowsocks-lockdown.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.cybersecurity.shadowsocks-lockdown</string>

    <key>ProgramArguments</key>
    <array>
        <string>/sbin/pfctl</string>
        <string>-e</string>
        <string>-f</string>
        <string>/etc/pf.conf</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <false/>

    <key>StandardErrorPath</key>
    <string>/var/log/shadowsocks-lockdown.log</string>

    <key>StandardOutPath</key>
    <string>/var/log/shadowsocks-lockdown.log</string>
</dict>
</plist>
```

**Actions:**
1. Create the LaunchDaemon plist
2. Set ownership and permissions (root:wheel, 644)
3. Load the daemon

---

### Phase 4: Configure System-Wide SOCKS5 Proxy

**Script to create:** `/usr/local/bin/ss-system-proxy-enable`

```bash
#!/bin/bash
# Enable system-wide SOCKS5 proxy on all network services

PROXY_HOST="127.0.0.1"
PROXY_PORT="1080"

# Get all network services
services=$(networksetup -listallnetworkservices | tail -n +2)

while IFS= read -r service; do
    echo "Configuring SOCKS proxy for: $service"
    networksetup -setsocksfirewallproxy "$service" $PROXY_HOST $PROXY_PORT
    networksetup -setsocksfirewallproxystate "$service" on
done <<< "$services"

echo "System-wide SOCKS5 proxy enabled on all network services"
```

**Script to create:** `/usr/local/bin/ss-system-proxy-disable`

```bash
#!/bin/bash
# Disable system-wide SOCKS5 proxy

services=$(networksetup -listallnetworkservices | tail -n +2)

while IFS= read -r service; do
    echo "Disabling SOCKS proxy for: $service"
    networksetup -setsocksfirewallproxystate "$service" off
done <<< "$services"

echo "System-wide SOCKS5 proxy disabled"
```

**Actions:**
1. Create both scripts in `/usr/local/bin/`
2. Make executable: `chmod +x /usr/local/bin/ss-system-proxy-*`
3. Run `ss-system-proxy-enable` to activate

---

### Phase 5: Create Management Scripts

**Script 1:** `/usr/local/bin/ss-lockdown-status`
```bash
#!/bin/bash
# Check status of Shadowsocks lockdown

echo "=== SHADOWSOCKS LOCKDOWN STATUS ==="
echo ""

# Check if ss-local is running
if pgrep -x "ss-local" > /dev/null; then
    echo "[OK] Shadowsocks client: RUNNING"
else
    echo "[!!] Shadowsocks client: NOT RUNNING"
fi

# Check PF firewall status
if sudo pfctl -s info 2>/dev/null | grep -q "Status: Enabled"; then
    echo "[OK] PF Firewall: ENABLED"
    rule_count=$(sudo pfctl -s rules 2>/dev/null | wc -l | tr -d ' ')
    echo "     Rules loaded: $rule_count"
else
    echo "[!!] PF Firewall: DISABLED"
fi

# Check SOCKS proxy setting
wifi_proxy=$(networksetup -getsocksfirewallproxy Wi-Fi 2>/dev/null | grep "Enabled" | awk '{print $2}')
if [ "$wifi_proxy" == "Yes" ]; then
    echo "[OK] System SOCKS Proxy: ENABLED"
else
    echo "[!!] System SOCKS Proxy: DISABLED"
fi

# Test connection through proxy
echo ""
echo "=== CONNECTION TEST ==="
exit_ip=$(curl -s --socks5 127.0.0.1:1080 --connect-timeout 10 ifconfig.me 2>/dev/null)
if [ -n "$exit_ip" ]; then
    echo "[OK] Exit IP: $exit_ip"
    if [ "$exit_ip" == "149.28.188.224" ]; then
        echo "[OK] Location: Sydney, Australia (VERIFIED)"
    else
        echo "[??] Location: Unknown (expected 149.28.188.224)"
    fi
else
    echo "[!!] Connection test FAILED - proxy not working"
fi
```

**Script 2:** `/usr/local/bin/ss-lockdown-enable`
```bash
#!/bin/bash
# Enable full Shadowsocks lockdown

echo "Enabling Shadowsocks lockdown..."

# 1. Start Shadowsocks client
sudo launchctl load -w /Library/LaunchDaemons/com.shadowsocks.client.plist 2>/dev/null

# 2. Enable PF firewall
sudo pfctl -e -f /etc/pf.conf 2>/dev/null

# 3. Enable system proxy
/usr/local/bin/ss-system-proxy-enable

echo "Lockdown ENABLED - all traffic now routed through Sydney"
/usr/local/bin/ss-lockdown-status
```

**Script 3:** `/usr/local/bin/ss-lockdown-disable`
```bash
#!/bin/bash
# EMERGENCY: Disable Shadowsocks lockdown
# WARNING: This will expose your real IP!

echo "!!! WARNING: Disabling lockdown will expose your real IP !!!"
read -p "Are you sure? (type YES to confirm): " confirm

if [ "$confirm" != "YES" ]; then
    echo "Aborted."
    exit 1
fi

# 1. Disable PF firewall
sudo pfctl -d 2>/dev/null

# 2. Disable system proxy
/usr/local/bin/ss-system-proxy-disable

# 3. Stop Shadowsocks client (optional - leave running)
# sudo launchctl unload /Library/LaunchDaemons/com.shadowsocks.client.plist

echo "Lockdown DISABLED - direct internet access restored"
```

---

### Phase 6: DNS Leak Protection (Route ALL DNS Through Shadowsocks)

All DNS queries will be routed through the Shadowsocks tunnel for maximum privacy.

**Configuration approach:**
1. Block external DNS at firewall level (remove local DNS exception)
2. Use SOCKS5h (hostname resolution through proxy) everywhere
3. Configure browsers to proxy DNS

**Updated PF rules** (remove local DNS exception):
```pf
# REMOVE these lines from shadowsocks-lockdown:
# pass out quick proto udp from any to { 192.168.0.1, ... } port 53
# pass in quick proto udp from { 192.168.0.1, ... } port 53 to any

# DNS will be resolved through SOCKS5 tunnel only
```

**Browser DNS configuration:**
- Firefox: `about:config` → `network.proxy.socks_remote_dns` = `true`
- Chrome: Uses system proxy DNS settings automatically when SOCKS proxy is configured

---

### Phase 7: Full Proxy Enforcement (Proxychains + Environment Variables)

**Install proxychains-ng:**
```bash
brew install proxychains-ng
```

**Create proxychains configuration:** `/opt/homebrew/etc/proxychains.conf`
```ini
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
socks5 127.0.0.1 1080
```

**Shell environment variables** (add to `~/.zshrc` or `~/.bashrc`):
```bash
# Force all tools to use SOCKS5 proxy
export ALL_PROXY="socks5h://127.0.0.1:1080"
export HTTP_PROXY="socks5h://127.0.0.1:1080"
export HTTPS_PROXY="socks5h://127.0.0.1:1080"
export NO_PROXY="localhost,127.0.0.1,::1"

# Alias for proxychains
alias pc="proxychains4 -q"
```

**Usage for stubborn applications:**
```bash
# Force any command through proxy
proxychains4 curl ifconfig.me
proxychains4 git clone https://github.com/...

# Or use alias
pc nmap -sT target.com
```

---

### Phase 8: Remove NordVPN Lockdown Infrastructure

Since we're replacing NordVPN entirely with Shadowsocks:

**Files to remove/disable:**
1. `/etc/pf.anchors/vpn-lockdown` - DELETE or rename to `.bak`
2. `/Library/LaunchDaemons/com.cybersecurity.vpn-lockdown.plist` - UNLOAD and DELETE
3. Remove vpn-lockdown anchor reference from `/etc/pf.conf`

**Commands:**
```bash
# Unload NordVPN lockdown daemon
sudo launchctl unload /Library/LaunchDaemons/com.cybersecurity.vpn-lockdown.plist

# Backup and remove
sudo mv /etc/pf.anchors/vpn-lockdown /etc/pf.anchors/vpn-lockdown.bak
sudo rm /Library/LaunchDaemons/com.cybersecurity.vpn-lockdown.plist

# Clean up management scripts
sudo rm -f /usr/local/bin/vpn-lockdown-*
```

---

### Phase 9: Boot Sequence (Final Architecture)

```
BOOT SEQUENCE (Automatic - No User Intervention Required):
==========================================================
1. Kernel loads (Darwin XNU)
2. LaunchDaemons execute (BEFORE WiFi, BEFORE user login):
   a. com.cybersecurity.shadowsocks-lockdown → PF firewall ENABLED
      → ALL traffic BLOCKED except 149.28.188.224:443 + DHCP
   b. com.shadowsocks.client → ss-local STARTS
      → Listening on 127.0.0.1:1080
3. WiFi connects (gets IP via DHCP - only allowed traffic at this point)
4. ss-local establishes encrypted tunnel to Sydney
5. User logs in
6. Shell loads ~/.zshrc → proxy environment variables set
7. System SOCKS proxy active → all apps route through 127.0.0.1:1080
8. Proxychains available for stubborn apps

TRAFFIC FLOW (All Layers):
==========================
┌─────────────────────────────────────────────────────────────────────────┐
│ Application (Browser, curl, git, etc.)                                  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Layer 1: macOS System SOCKS Proxy (networksetup)                        │
│ OR       Shell Environment Variables (ALL_PROXY, HTTP_PROXY)            │
│ OR       Proxychains (for non-compliant apps)                           │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Layer 2: ss-local (127.0.0.1:1080)                                      │
│          Encrypts with ChaCha20-Poly1305                                │
│          Resolves DNS through tunnel (SOCKS5h)                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Layer 3: PF Firewall (Kernel Level)                                     │
│          ONLY allows: 149.28.188.224:443 + DHCP                         │
│          BLOCKS: Everything else (IPv4, IPv6)                           │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Layer 4: Internet → Sydney Shadowsocks Server (149.28.188.224)          │
│          Decrypts and forwards to destination                           │
│          All websites see Australian IP                                 │
└─────────────────────────────────────────────────────────────────────────┘

KILL SWITCH BEHAVIOR:
=====================
If ss-local crashes or connection drops:
  → PF firewall STILL ACTIVE
  → Only 149.28.188.224:443 allowed
  → No ss-local = No decryption = No internet
  → YOUR REAL IP NEVER EXPOSED
```

---

## Files to Create/Modify

| File | Action | Owner |
|------|--------|-------|
| `/etc/pf.anchors/shadowsocks-lockdown` | CREATE | root:wheel |
| `/etc/pf.conf` | MODIFY | root:wheel |
| `/etc/shadowsocks/config.json` | CREATE (copy) | root:wheel |
| `/Library/LaunchDaemons/com.shadowsocks.client.plist` | CREATE | root:wheel |
| `/Library/LaunchDaemons/com.cybersecurity.shadowsocks-lockdown.plist` | CREATE | root:wheel |
| `/usr/local/bin/ss-system-proxy-enable` | CREATE | root:wheel |
| `/usr/local/bin/ss-system-proxy-disable` | CREATE | root:wheel |
| `/usr/local/bin/ss-lockdown-status` | CREATE | root:wheel |
| `/usr/local/bin/ss-lockdown-enable` | CREATE | root:wheel |
| `/usr/local/bin/ss-lockdown-disable` | CREATE | root:wheel |
| `~/Library/LaunchAgents/com.shadowsocks.client.plist` | DISABLE | user |

---

## Verification Steps

### Basic Verification
1. **Reboot the MacBook**
2. **Before logging in**, firewall should already be active (LaunchDaemon runs at boot)
3. **After login**, run: `/usr/local/bin/ss-lockdown-status`
4. **Test connection**: `curl ifconfig.me` should return `149.28.188.224`

### Kill Switch Verification
5. **Stop ss-local**: `sudo launchctl unload /Library/LaunchDaemons/com.shadowsocks.client.plist`
6. **Try to access internet**: `curl -m 5 ifconfig.me` should TIMEOUT (blocked by PF)
7. **Restart ss-local**: `sudo launchctl load /Library/LaunchDaemons/com.shadowsocks.client.plist`

### DNS Leak Verification
8. **Test DNS resolution through proxy**:
   ```bash
   curl --socks5-hostname 127.0.0.1:1080 https://dnsleaktest.com/
   ```
9. **Verify no external DNS allowed**:
   ```bash
   dig @8.8.8.8 google.com  # Should TIMEOUT (blocked by PF)
   ```

### Proxychains Verification
10. **Test proxychains**:
    ```bash
    proxychains4 curl ifconfig.me  # Should return 149.28.188.224
    ```

### Environment Variables Verification
11. **Check env vars loaded**:
    ```bash
    echo $ALL_PROXY  # Should show socks5h://127.0.0.1:1080
    ```

### Full Lockdown Test
12. **Disconnect from WiFi and reconnect**
13. **Verify internet only works through proxy** (direct connections blocked)

---

## Emergency Recovery

If locked out of internet:

**Method 1: Terminal (if accessible)**
```bash
sudo pfctl -d                  # Disable firewall temporarily
# OR
/usr/local/bin/ss-lockdown-disable  # Full disable with confirmation
```

**Method 2: Recovery Mode (Apple Silicon M2 Pro)**
1. Shut down Mac
2. Press and hold power button until "Loading startup options" appears
3. Select "Options" → Continue → Recovery Mode
4. Open Terminal from Utilities menu
5. Find your volume: `ls /Volumes/`
6. Edit: `nano /Volumes/Macintosh\ HD/etc/pf.conf`
7. Comment out the shadowsocks-lockdown anchor line:
   ```
   # anchor "shadowsocks-lockdown"
   # load anchor "shadowsocks-lockdown" from "/etc/pf.anchors/shadowsocks-lockdown"
   ```
8. Save and reboot

**Method 3: Single User Mode (if Recovery fails)**
1. Hold Cmd+S during boot
2. Mount filesystem: `mount -uw /`
3. Disable PF: `pfctl -d`
4. Edit `/etc/pf.conf` to comment out anchor
5. `reboot`

**Note:** Emergency recovery scripts will be created at known location for quick access

---

## User Decisions (Confirmed)

1. **NordVPN infrastructure:** REPLACE entirely with Shadowsocks
2. **DNS handling:** Route ALL DNS through Shadowsocks tunnel
3. **Proxy enforcement:** FULL - proxychains, terminal env vars, browser configs

---

## Complete File Summary

| File | Action | Purpose |
|------|--------|---------|
| `/etc/pf.anchors/shadowsocks-lockdown` | CREATE | Firewall rules blocking all non-Shadowsocks traffic |
| `/etc/pf.conf` | MODIFY | Load shadowsocks-lockdown anchor |
| `/etc/shadowsocks/config.json` | CREATE | Root-owned Shadowsocks client config |
| `/Library/LaunchDaemons/com.shadowsocks.client.plist` | CREATE | Boot-time ss-local service |
| `/Library/LaunchDaemons/com.cybersecurity.shadowsocks-lockdown.plist` | CREATE | Boot-time firewall activation |
| `/usr/local/bin/ss-system-proxy-enable` | CREATE | Enable system SOCKS proxy |
| `/usr/local/bin/ss-system-proxy-disable` | CREATE | Disable system SOCKS proxy |
| `/usr/local/bin/ss-lockdown-status` | CREATE | Status check script |
| `/usr/local/bin/ss-lockdown-enable` | CREATE | Manual enable script |
| `/usr/local/bin/ss-lockdown-disable` | CREATE | Emergency disable script |
| `/opt/homebrew/etc/proxychains.conf` | CREATE | Proxychains configuration |
| `~/.zshrc` | MODIFY | Add proxy environment variables |
| `/etc/pf.anchors/vpn-lockdown` | DELETE | Remove old NordVPN rules |
| `/Library/LaunchDaemons/com.cybersecurity.vpn-lockdown.plist` | DELETE | Remove old NordVPN daemon |
| `~/Library/LaunchAgents/com.shadowsocks.client.plist` | DISABLE | Prevent duplicate ss-local |

---

## Implementation Order

1. Backup all existing configs
2. Remove NordVPN infrastructure
3. Create Shadowsocks PF rules
4. Create root-level Shadowsocks config
5. Create Shadowsocks LaunchDaemon
6. Create firewall LaunchDaemon
7. Update /etc/pf.conf
8. Create management scripts
9. Install and configure proxychains
10. Add shell environment variables
11. Enable system proxy
12. Configure browser DNS settings
13. Test and verify
14. Reboot and confirm boot-time activation
