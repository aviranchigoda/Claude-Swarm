# Safe VPN Testing Plan - Shadowsocks & Proxychains

## Objective
Test the Shadowsocks VPN setup safely without risking Mac functionality or network connectivity.

## Your Current Setup Summary
| Component | Status | Location |
|-----------|--------|----------|
| Shadowsocks (ss-local) | Installed | `/opt/homebrew/bin/ss-local` |
| proxychains4 | Installed | `/opt/homebrew/bin/proxychains4` |
| Config | Ready | `~/.shadowsocks/config.json` |
| pf lockdown rules | Ready | `/etc/pf.conf` + `pf-shadowsocks-lockdown.conf` |
| Sydney VPS | 149.28.188.224:443 | Exit IP |

## Key Safety Principle
**Never enable the pf firewall (kill switch) until all components are verified working.**

Your pf rules do the following when enabled:
- **BLOCK ALL** outbound traffic by default
- **BLOCK ALL DNS** (port 53) - forces DNS through proxy
- **ALLOW ONLY** traffic to 149.28.188.224:443 (Shadowsocks)
- **ALLOW DHCP** (so Wi-Fi still works)

If Shadowsocks isn't working when pf is enabled, you lose ALL internet including DNS.

---

## EMERGENCY COMMANDS (Memorize These!)

```bash
# If you lose internet, run this IMMEDIATELY:
sudo pfctl -d

# Kill shadowsocks if stuck:
pkill -9 ss-local
```

---

## Recommended Testing Order

1. **Phases 1-3**: Safe tests (no system changes)
2. **Phase 4**: Proxychains testing (requires ss-local running)
3. **Phase 5**: Control script testing (partial mode only)
4. **Phase 6**: Full lockdown (only after everything else works)

---

## Phase 1: Pre-Flight Checks (Non-Destructive)

### 1.1 Check Current Network State
```bash
# Save your current working state
networksetup -getinfo Wi-Fi > ~/vpn-test-backup.txt
ifconfig en0 >> ~/vpn-test-backup.txt
```

### 1.2 Verify Dependencies Installed
```bash
which ss-local          # Should show /opt/homebrew/bin/ss-local
which proxychains4      # Check if proxychains is installed
brew list shadowsocks-libev
```

### 1.3 Validate Config File Syntax
```bash
cat ~/.shadowsocks/config.json | python3 -m json.tool
# Also check /etc/shadowsocks/config.json if it exists
```

---

## Phase 2: Isolated Component Testing

### 2.1 Test VPS Reachability (Without Proxy)
```bash
# Test basic connectivity to your Sydney VPS
ping -c 3 149.28.188.224
nc -zv 149.28.188.224 443 -w 5
```

### 2.2 Start Shadowsocks Client Manually (Foreground)
```bash
# Run in foreground to see errors immediately
# Keep this terminal open
ss-local -c ~/.shadowsocks/config.json -v
```
**Why foreground?** You see errors immediately and can Ctrl+C to stop if something breaks.

### 2.3 Test Proxy Works (In Separate Terminal)
```bash
# Basic connectivity test
curl --socks5 127.0.0.1:1080 --max-time 10 https://ifconfig.me

# Should return: 149.28.188.224 (your Sydney VPS IP)
# If this fails, do NOT proceed to firewall testing
```

### 2.4 Test DNS Resolution Through Proxy
```bash
# Use --socks5-hostname to route DNS through proxy too
curl --socks5-hostname 127.0.0.1:1080 --max-time 10 https://ifconfig.me
curl --socks5-hostname 127.0.0.1:1080 --max-time 10 ipinfo.io/country
# Should return: AU
```

---

## Phase 3: Use Your Monitor Script (Safe Verification)

```bash
# This is READ-ONLY - just displays status, doesn't change anything
./vpn-monitor.sh
```

Look for:
- Shadowsocks: GREEN/RUNNING
- Tunnel: GREEN/CONNECTED
- You should see "PARTIAL" protection (Shadowsocks running, firewall off)

---

## Phase 4: Proxychains Testing

Your proxychains config is already set up correctly at `/opt/homebrew/etc/proxychains.conf`:
- Mode: `strict_chain`
- DNS: `proxy_dns` enabled (prevents DNS leaks)
- Proxy: `socks5 127.0.0.1 1080`

### 4.1 Verify Shadowsocks is Running First
```bash
# proxychains REQUIRES ss-local to be running
pgrep ss-local || echo "Start ss-local first!"
```

### 4.2 Test Proxychains with Simple Commands
```bash
# Low-risk test - just fetches your IP
proxychains4 curl https://ifconfig.me
# Expected output: [proxychains] ... | 149.28.188.224

# Test DNS resolution through proxy
proxychains4 curl https://ipinfo.io/country
# Expected: AU
```

### 4.3 Test with Other Commands
```bash
# Test with wget
proxychains4 wget -qO- https://ifconfig.me

# Test SSH (if you have a test server)
proxychains4 ssh -o ConnectTimeout=5 user@some-server

# Test Python
proxychains4 python3 -c "import urllib.request; print(urllib.request.urlopen('https://ifconfig.me').read().decode())"
```

### 4.4 Proxychains Wrapper for Browser (Optional)
```bash
# Launch Firefox through proxychains
proxychains4 /Applications/Firefox.app/Contents/MacOS/firefox

# Note: Chrome doesn't work well with proxychains due to sandboxing
```

---

## Phase 5: Testing the Control Script (Partial Mode)

### 5.1 Check Status Only (Safe)
```bash
./vpn-control.sh status
```

### 5.2 Test "On" Without Full Lockdown
Before running `sudo ./vpn-control.sh on`, understand what it does:
1. Starts Shadowsocks (safe)
2. Verifies tunnel works (safe)
3. **Enables pf firewall** (BLOCKS all direct traffic)

**Safe alternative - start Shadowsocks only:**
```bash
# Start ss-local in background without firewall
ss-local -c ~/.shadowsocks/config.json &

# Verify it works
curl --socks5 127.0.0.1:1080 https://ifconfig.me

# If good, THEN test firewall (see Phase 6)
```

---

## Phase 6: Full Lockdown Testing (With Safety Net)

### 6.1 Create Emergency Recovery Script FIRST
```bash
cat > ~/vpn-emergency-off.sh << 'EOF'
#!/bin/bash
# Emergency VPN/Firewall disable
sudo pfctl -d 2>/dev/null
sudo pkill ss-local 2>/dev/null
networksetup -setsocksfirewallproxystate Wi-Fi off 2>/dev/null
echo "Emergency disable complete - direct internet restored"
EOF
chmod +x ~/vpn-emergency-off.sh
```

### 6.2 Keep Emergency Terminal Ready
Open a second terminal and have this ready to paste:
```bash
sudo pfctl -d
```

### 6.3 Test Full Lockdown
```bash
# Now test full lockdown
sudo ./vpn-control.sh on

# Verify you still have internet
curl https://ifconfig.me  # Should show Sydney IP or fail if pf working correctly
curl --socks5 127.0.0.1:1080 https://ifconfig.me  # Should always work
```

### 6.4 Turn Off When Done Testing
```bash
sudo ./vpn-control.sh off
```

---

## Safe Rollback Procedures

### If Internet Stops Working:
```bash
# Method 1: Disable pf firewall (FASTEST - memorize this!)
sudo pfctl -d

# Method 2: Use vpn-control.sh
sudo ./vpn-control.sh off

# Method 3: Use your emergency script (if created)
~/vpn-emergency-off.sh

# Method 4: System Settings GUI
# Go to: System Settings > Network > Wi-Fi > Details > Proxies
# Uncheck all proxy options
```

### If Shadowsocks Won't Stop:
```bash
pkill -9 ss-local
```

### Full Uninstall (Nuclear Option):
Your installer includes a complete uninstall script:
```bash
cd ~/Desktop/software/cybersecurity/shadowsocks-lockdown-install
sudo ./uninstall.sh
```
This removes:
- pf firewall rules
- System proxy settings
- LaunchDaemons
- Shadowsocks config

### Network Reset (if all else fails):
```bash
sudo ifconfig en0 down
sudo ifconfig en0 up
# Or: Toggle Wi-Fi off/on in menu bar
```

---

## Testing Checklist

| Test | Command | Expected Result | Status |
|------|---------|-----------------|--------|
| VPS reachable | `ping 149.28.188.224` | Response | [ ] |
| Port 443 open | `nc -zv 149.28.188.224 443` | Connection succeeded | [ ] |
| SS starts | `ss-local -c ~/.shadowsocks/config.json` | "listening at 127.0.0.1:1080" | [ ] |
| Proxy works | `curl --socks5 127.0.0.1:1080 ifconfig.me` | 149.28.188.224 | [ ] |
| DNS via proxy | `curl --socks5-hostname 127.0.0.1:1080 ipinfo.io/country` | AU | [ ] |
| Monitor runs | `./vpn-monitor.sh` | Dashboard displays | [ ] |
| Control status | `./vpn-control.sh status` | Shows current state | [ ] |
| Full lockdown | `sudo ./vpn-control.sh on` | "VPN LOCKDOWN ACTIVE" | [ ] |
| Lockdown verify | Direct curl fails, proxy curl works | Expected behavior | [ ] |
| Clean disable | `sudo ./vpn-control.sh off` | Direct internet restored | [ ] |

---

## What NOT to Do

1. **Don't enable pf firewall without testing Shadowsocks first** - You'll lose all internet
2. **Don't close the ss-local terminal** if running in foreground - proxy stops
3. **Don't run `sudo pfctl -e`** manually without a working proxy
4. **Don't modify /etc/pf.conf** without a backup
5. **Don't test during important work** - have a fallback (mobile hotspot)

---

## Verification Method

After each test phase, verify normal Mac operation:
1. Can you load a webpage in browser?
2. Does `ping 8.8.8.8` work?
3. Can you resolve DNS? `nslookup google.com`

If any fail unexpectedly, run the emergency disable command.
