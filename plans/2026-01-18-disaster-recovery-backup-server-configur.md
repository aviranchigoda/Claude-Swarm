# Disaster Recovery & Backup Server Configuration Plan

## Server Inventory

| Server | IP Address | Provider | Specs | Purpose |
|--------|------------|----------|-------|---------|
| MacBook Pro M2 | Local | - | Apple Silicon | Primary workstation |
| Vultr Sydney | 149.28.188.224 | Vultr | VPS | Shadowsocks VPN proxy |
| Akamai 8-core | 172.105.183.244 | Akamai/Linode | 8 CPU | Main development server |
| **Akamai 2-core BACKUP** | **194.195.123.136** | Akamai/Linode | 2 CPU | **Disaster recovery server** |

## Objective

Configure `194.195.123.136` as a centralized backup server that:
1. Can be accessed from iPad/iPhone via Termius with Face ID
2. Contains synchronized copies of all critical data
3. Stores emergency recovery documentation
4. Works even if MacBook is completely inaccessible

---

## Phase 1: Secure SSH Access for Termius (iPad/iPhone)

### 1.1 Generate SSH Key in Termius
**On iPad/iPhone:**
1. Open Termius app
2. Go to Keychain → Keys → Generate Key
3. Choose: ED25519 (recommended) or RSA 4096
4. Name it: `termius-recovery-key`
5. Enable Face ID protection for this key

### 1.2 Add Public Key to Backup Server
**On MacBook (to be executed):**
```bash
# SSH into backup server
ssh root@194.195.123.136

# Create .ssh directory if needed
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Add Termius public key (you'll paste from Termius app)
nano ~/.ssh/authorized_keys
# Paste the public key from Termius
chmod 600 ~/.ssh/authorized_keys
```

### 1.3 Configure SSH Security
**On backup server `/etc/ssh/sshd_config`:**
```bash
# Recommended settings
PermitRootLogin prohibit-password  # Key-only, no password
PasswordAuthentication no           # Disable password login
PubkeyAuthentication yes           # Enable key auth
MaxAuthTries 3                     # Limit attempts
```

### 1.4 Termius Connection Profile
**In Termius app, create host:**
- Label: `BACKUP-RECOVERY`
- Address: `194.195.123.136`
- Port: `22`
- Username: `root`
- Key: `termius-recovery-key`
- Enable Face ID unlock

---

## Phase 2: Data Synchronization Setup

### 2.1 Directory Structure on Backup Server
```
/backup/
├── macbook/
│   └── software/           # Synced from MacBook ~/Desktop/software
├── vultr/
│   ├── shadowsocks/        # Shadowsocks configs
│   └── etc/                # Critical /etc files
├── akamai-8core/
│   └── workspace/          # Synced from main dev server
└── recovery/
    ├── MASTER-RECOVERY.md  # Emergency instructions
    ├── credentials.gpg     # Encrypted credentials
    └── ssh-keys/           # Backup of all SSH keys
```

### 2.2 MacBook → Backup Server Sync
**Create sync script on MacBook: `~/sync-to-backup.sh`**
```bash
#!/bin/bash
BACKUP_SERVER="194.195.123.136"
rsync -avz --progress --delete \
    ~/Desktop/software/ \
    root@${BACKUP_SERVER}:/backup/macbook/software/
echo "Sync completed: $(date)"
```

### 2.3 Vultr → Backup Server Sync
**Create on Vultr server: `/root/sync-to-backup.sh`**
```bash
#!/bin/bash
BACKUP_SERVER="194.195.123.136"
rsync -avz \
    /etc/shadowsocks/ \
    root@${BACKUP_SERVER}:/backup/vultr/shadowsocks/
```

### 2.4 8-core Akamai → Backup Server Sync
**Create on 172.105.183.244: `/root/sync-to-backup.sh`**
```bash
#!/bin/bash
BACKUP_SERVER="194.195.123.136"
rsync -avz --progress \
    /home/ai_dev/workspace/ \
    root@${BACKUP_SERVER}:/backup/akamai-8core/workspace/
```

### 2.5 Automated Sync (Cron Jobs)
**On each source machine, add to crontab:**
```bash
# Sync every 6 hours
0 */6 * * * /root/sync-to-backup.sh >> /var/log/backup-sync.log 2>&1
```

---

## Phase 3: Emergency Recovery Documentation

### 3.1 Master Recovery Document
**Create `/backup/recovery/MASTER-RECOVERY.md` on backup server:**

```markdown
# EMERGENCY RECOVERY DOCUMENT
Last Updated: [DATE]

## If You've Lost Access to Everything

### Step 1: Access This Server
- IP: 194.195.123.136
- Use Termius app on iPad/iPhone
- Face ID will unlock your SSH key
- Username: root

### Step 2: Your Server Inventory
| Server | IP | SSH User | Purpose |
|--------|-----|----------|---------|
| Vultr VPN | 149.28.188.224 | root | Shadowsocks proxy |
| Akamai 8-core | 172.105.183.244 | ai_dev | Main dev server |
| This backup | 194.195.123.136 | root | You are here |

### Step 3: Disable MacBook Lockdown (If Needed)
If your MacBook is locked out due to VPN kill-switch:
1. Boot into Recovery Mode (hold Power button)
2. Open Terminal
3. Run: `pfctl -d`
4. Restart

### Step 4: VPN/Shadowsocks Credentials
Server: 149.28.188.224
Port: 443
Password: [STORED IN credentials.gpg]
Method: chacha20-ietf-poly1305

### Step 5: Your Data Locations
- MacBook software backup: /backup/macbook/software/
- Vultr configs: /backup/vultr/
- 8-core workspace: /backup/akamai-8core/
```

### 3.2 Encrypted Credentials File
**Store sensitive data encrypted:**
```bash
# On backup server
echo "All your passwords and keys" | gpg -c > /backup/recovery/credentials.gpg
# Use a password you'll remember even if you forget everything else
```

---

## Phase 4: Firewall & Security on Backup Server

### 4.1 UFW Firewall Rules
```bash
# Reset and configure
ufw default deny incoming
ufw default allow outgoing

# Allow SSH
ufw allow 22/tcp

# Allow from your other servers only for rsync
ufw allow from 149.28.188.224 to any port 22
ufw allow from 172.105.183.244 to any port 22

# Enable
ufw enable
```

### 4.2 Fail2ban for SSH Protection
```bash
apt install fail2ban
systemctl enable fail2ban
systemctl start fail2ban
```

---

## Phase 5: Verification & Testing

### 5.1 Test Checklist
- [ ] SSH from Termius on iPad with Face ID
- [ ] SSH from Termius on iPhone with Face ID
- [ ] Verify rsync from MacBook works
- [ ] Verify rsync from Vultr works
- [ ] Verify rsync from 8-core works
- [ ] Read MASTER-RECOVERY.md from Termius
- [ ] Decrypt credentials.gpg successfully

### 5.2 Monthly Maintenance
1. Verify all syncs are running (check logs)
2. Test Termius access from mobile devices
3. Update MASTER-RECOVERY.md if anything changes
4. Verify disk space on backup server

---

## Implementation Order

1. **SSH Setup** - Configure Termius key authentication
2. **Directory Setup** - Create /backup structure on server
3. **Recovery Docs** - Write MASTER-RECOVERY.md
4. **Sync Scripts** - Create and test rsync scripts
5. **Automation** - Set up cron jobs
6. **Security** - Configure firewall and fail2ban
7. **Testing** - Full end-to-end verification

---

## Critical Files to Modify

| Location | File | Action |
|----------|------|--------|
| Backup Server | `/root/.ssh/authorized_keys` | Add Termius public key |
| Backup Server | `/etc/ssh/sshd_config` | Harden SSH config |
| Backup Server | `/backup/recovery/MASTER-RECOVERY.md` | Create recovery doc |
| MacBook | `~/sync-to-backup.sh` | Create sync script |
| Vultr | `/root/sync-to-backup.sh` | Create sync script |
| 8-core | `/root/sync-to-backup.sh` | Create sync script |

---

## Notes

- Termius stores SSH keys in iOS Secure Enclave (protected by Face ID)
- Even if you forget all passwords, Face ID + Termius will get you into backup server
- Backup server should have ALL information needed to recover everything else
- Test this quarterly by pretending you've lost everything
