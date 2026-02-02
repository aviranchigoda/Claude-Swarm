# Proxychains Setup for Claude Code with Shadowsocks

## Overview

Route Claude Code through your existing Shadowsocks tunnel using proxychains-ng, allowing it to work with your pf firewall lockdown active.

## Implementation Steps

### Step 1: Install proxychains-ng

```bash
brew install proxychains-ng
```

### Step 2: Configure proxychains

**File:** `/opt/homebrew/etc/proxychains.conf`

Replace contents with:

```conf
# Proxychains configuration for Shadowsocks
# ==========================================

# Quiet mode (no output from proxychains itself)
quiet_mode

# Proxy DNS requests through the proxy (prevents DNS leaks)
proxy_dns

# Timeout settings
tcp_read_time_out 15000
tcp_connect_time_out 8000

# Proxy type: strict_chain means all proxies must work in order
strict_chain

[ProxyList]
# Shadowsocks local SOCKS5 proxy
socks5 127.0.0.1 1080
```

### Step 3: Create convenience alias (optional)

Add to `~/.zshrc`:

```bash
# Claude Code through Shadowsocks tunnel
alias claude='proxychains4 -q claude'
```

Then reload: `source ~/.zshrc`

---

## Manual Safety Tests

Run these tests IN ORDER. Each test is safe and read-only. Stop if any test fails.

### Test 1: Verify proxychains is installed

```bash
which proxychains4
```

**Expected:** `/opt/homebrew/bin/proxychains4`

### Test 2: Verify Shadowsocks is running (without VPN lockdown)

First, make sure your VPN lockdown is OFF for initial testing:

```bash
sudo ./vpn-control.sh off
```

Then check Shadowsocks:

```bash
pgrep -f ss-local && echo "Shadowsocks running" || echo "Shadowsocks NOT running"
```

**Expected:** `Shadowsocks running`

### Test 3: Test direct curl (baseline)

```bash
curl -s --max-time 5 https://ifconfig.me
```

**Expected:** Your real ISP IP address (e.g., Australian IP)

### Test 4: Test proxychains with curl

```bash
proxychains4 -q curl -s --max-time 10 https://ifconfig.me
```

**Expected:** `149.28.188.224` (your Sydney VPS IP)

### Test 5: Test DNS resolution through proxy

```bash
proxychains4 -q curl -s --max-time 10 https://api.anthropic.com/v1/models 2>&1 | head -c 100
```

**Expected:** Some JSON response or "authentication" error (not a connection timeout). This proves DNS resolves and the connection works.

### Test 6: Enable VPN lockdown and re-test

```bash
sudo ./vpn-control.sh on
```

Then repeat Test 4:

```bash
proxychains4 -q curl -s --max-time 10 https://ifconfig.me
```

**Expected:** `149.28.188.224` (still works through tunnel)

### Test 7: Verify direct connections are blocked

```bash
curl -s --max-time 5 https://ifconfig.me || echo "BLOCKED (expected)"
```

**Expected:** Timeout or "BLOCKED (expected)" - this confirms your firewall is working.

### Test 8: Test Claude Code through proxychains

```bash
proxychains4 -q claude --version
```

**Expected:** Claude Code version output (proves it can reach Anthropic's servers)

### Test 9: Interactive Claude Code test

```bash
proxychains4 -q claude
```

Then type a simple message like "hello" to verify full functionality.

---

## Rollback

If anything goes wrong:

```bash
# Disable VPN lockdown (restore direct internet)
sudo ./vpn-control.sh off

# Uninstall proxychains if needed
brew uninstall proxychains-ng

# Remove alias from ~/.zshrc if added
```

---

## Files Modified

| File | Action | Purpose |
|------|--------|---------|
| `/opt/homebrew/etc/proxychains.conf` | Edit | Configure SOCKS5 proxy |
| `~/.zshrc` | Edit (optional) | Add convenience alias |

## Verification Checklist

After all tests pass:

- [ ] Test 1: proxychains4 installed
- [ ] Test 2: Shadowsocks running
- [ ] Test 3: Direct curl shows real IP
- [ ] Test 4: Proxychains curl shows Sydney IP
- [ ] Test 5: API endpoint reachable through proxy
- [ ] Test 6: Works with VPN lockdown ON
- [ ] Test 7: Direct connections blocked (firewall working)
- [ ] Test 8: Claude --version works through proxy
- [ ] Test 9: Interactive Claude works
