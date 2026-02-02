# FileSync Deployment Plan: Automatic Sync on Boot with Deletion Protection

## Summary
Deploy the FileSync server on Linode and configure the macOS client to automatically start on boot, with deletion protection on synced files.

## Current State
- Server: **NOT RUNNING** on Linode (172.105.183.244)
- Client: Built but not configured for auto-start
- Files: No deletion protection

---

## Phase 1: Deploy Server to Linode

### 1.1 Copy Code to Linode
```bash
rsync -avz /Users/aviranchigoda/Desktop/software/filesync/ aidev@172.105.183.244:/home/aidev/filesync/
```

### 1.2 Build Server on Linode
```bash
ssh aidev@172.105.183.244 'cd /home/aidev/filesync && make CC=gcc server'
```

### 1.3 Create Sync Destination Directory with Immutable Attributes
```bash
ssh aidev@172.105.183.244 'mkdir -p /home/aidev/filesync-data && sudo chattr +a /home/aidev/filesync-data'
```
Note: `+a` makes directory append-only (files can be added but not deleted)

### 1.4 Create systemd Service for Auto-Start
Create `/etc/systemd/system/filesync.service` on Linode:
```ini
[Unit]
Description=FileSync Server
After=network.target

[Service]
Type=simple
ExecStart=/home/aidev/filesync/build/filesync-server -d /home/aidev/filesync-data -p 9999 -v
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 1.5 Enable and Start Server
```bash
ssh aidev@172.105.183.244 'sudo systemctl daemon-reload && sudo systemctl enable filesync && sudo systemctl start filesync'
```

### 1.6 Configure Firewall
```bash
ssh aidev@172.105.183.244 'sudo ufw allow 9999/tcp'
```

---

## Phase 2: Configure macOS Client for Auto-Start

### 2.1 Build Client on macOS
```bash
cd /Users/aviranchigoda/Desktop/software/filesync && make client
```

### 2.2 Create launchd plist for Boot Auto-Start
Create `~/Library/LaunchAgents/com.filesync.client.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.filesync.client</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/aviranchigoda/Desktop/software/filesync/build/filesync-client</string>
        <string>-w</string>
        <string>/Users/aviranchigoda/Desktop/software</string>
        <string>-s</string>
        <string>172.105.183.244</string>
        <string>-p</string>
        <string>9999</string>
        <string>-v</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/filesync-client.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/filesync-client.err</string>
</dict>
</plist>
```

### 2.3 Load the LaunchAgent
```bash
launchctl load ~/Library/LaunchAgents/com.filesync.client.plist
```

---

## Phase 3: Configure Deletion Protection on Server

### 3.1 Set Immutable Flag on Synced Files (Linux)
After sync completes, set files as immutable:
```bash
ssh aidev@172.105.183.244 'sudo chattr -R +i /home/aidev/filesync-data/*'
```
Note: `+i` makes files completely immutable (cannot be modified or deleted, even by root)

### 3.2 Alternative: Use append-only with automatic protection
Modify server code (`server/assembler.h`) to set immutable flag after each file is finalized:
```c
// After rename() in assembler_finalize_file():
// Set immutable attribute (requires server to run as root or with CAP_LINUX_IMMUTABLE)
char cmd[MAX_PATH_LEN + 64];
snprintf(cmd, sizeof(cmd), "sudo chattr +i '%s'", pf->path);
system(cmd);
```

---

## Phase 4: Fix Known Code Issues (Optional but Recommended)

### 4.1 Re-enable FSEvents for Real-Time Sync
File: `client/watcher.h` (lines 240-248)
Currently FSEvents is disabled. Need to re-enable for continuous sync.

### 4.2 Fix CRC32 Validation
File: `server/receiver.h` (lines 330-343)
Currently ignores checksum mismatches - should reject corrupted packets.

---

## Verification Steps

1. **Check server is running:**
   ```bash
   ssh aidev@172.105.183.244 'sudo systemctl status filesync'
   ```

2. **Check server is listening:**
   ```bash
   ssh aidev@172.105.183.244 'ss -tlnp | grep 9999'
   ```

3. **Check client is running:**
   ```bash
   launchctl list | grep filesync
   ```

4. **Check client logs:**
   ```bash
   cat /tmp/filesync-client.log
   cat /tmp/filesync-client.err
   ```

5. **Verify files synced:**
   ```bash
   ssh aidev@172.105.183.244 'ls -la /home/aidev/filesync-data/'
   ```

6. **Verify deletion protection:**
   ```bash
   ssh aidev@172.105.183.244 'lsattr /home/aidev/filesync-data/*'
   ```

---

## Critical Files to Modify

| File | Modification |
|------|--------------|
| `~/Library/LaunchAgents/com.filesync.client.plist` | NEW - launchd config |
| `/etc/systemd/system/filesync.service` (Linode) | NEW - systemd service |
| `server/assembler.h` | OPTIONAL - add chattr after finalize |
| `client/watcher.h` | OPTIONAL - re-enable FSEvents |

---

## Expected Outcome

After implementation:
1. Server starts automatically when Linode boots
2. Client starts automatically when macOS boots
3. All files in `/Users/aviranchigoda/Desktop/software` (including `deployment-1`) sync to Linode at `/home/aidev/filesync-data/`
4. Synced files on Linode cannot be deleted (immutable flag set via `chattr +i`)
5. Any new files added to the software folder will sync automatically (once FSEvents is re-enabled)
