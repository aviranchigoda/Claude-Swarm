# macOS Permission Architecture Analysis & Low-Level File Transfer to UTM Linux VM

## System Profile Summary

| Component | Value |
|-----------|-------|
| **Hardware** | MacBook Pro (Mac14,10), Apple M2 Pro, 12 cores, 16GB RAM |
| **Firmware** | iBoot-11881.121.1 |
| **OS** | macOS 15.5 Sequoia (Darwin 24.5.0) |
| **Hypervisor** | Apple Hypervisor.framework (kern.hv_support: 1) |
| **Virtualization** | UTM 4.7.4 with Virtualization.framework entitlements |

---

## 1. Complete macOS Permission Architecture

### 1.1 Boot Security Chain (Hardware → Kernel)

```
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 0: HARDWARE SECURITY                                    │
├─────────────────────────────────────────────────────────────────┤
│  ✓ Secure Enclave (SEP) - Hardware root of trust               │
│  ✓ Boot ROM - Immutable first-stage bootloader                 │
│  ✓ Activation Lock: ENABLED                                    │
│  ✓ Hardware UUID: F94555C3-1180-5BF3-8C0C-CA9E4FAC45DF         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 1: FIRMWARE SECURITY                                    │
├─────────────────────────────────────────────────────────────────┤
│  ✓ Secure Boot: FULL SECURITY                                  │
│  ✓ Signed System Volume (SSV): ENABLED                         │
│  ✓ Authenticated Root: ENABLED                                 │
│  ✓ Kernel CTRR (Code Text Region Relocation): ENABLED          │
│  ✓ Boot Arguments Filtering: ENABLED                           │
│  ✗ Allow All Kernel Extensions: NO                             │
│  ✗ MDM Operations: NOT APPROVED                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 2: KERNEL SECURITY                                      │
├─────────────────────────────────────────────────────────────────┤
│  ✓ System Integrity Protection (SIP): ENABLED                  │
│  ✓ NVRAM Protection: RESTRICTED                                │
│  ✓ Kernel Extension Loading: SYSTEM EXTENSIONS ONLY            │
│    - Active Drivers: Razer HID, Logitech G HUB (user-approved) │
│  ✓ Secure Virtual Memory: ENABLED                              │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Application Security Layers

```
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 3: GATEKEEPER & CODESIGNING                             │
├─────────────────────────────────────────────────────────────────┤
│  ✓ Gatekeeper: ENABLED (assessments enabled)                   │
│  ✓ Notarization: REQUIRED for new apps                         │
│  ✓ Quarantine Attribute: Active on downloaded files            │
│    (com.apple.quarantine extended attribute)                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 4: TCC (TRANSPARENCY, CONSENT, CONTROL)                 │
├─────────────────────────────────────────────────────────────────┤
│  Database Locations:                                           │
│  ├─ User: ~/Library/Application Support/com.apple.TCC/TCC.db   │
│  └─ System: /Library/Application Support/com.apple.TCC/TCC.db  │
│                                                                 │
│  Terminal.app Permissions (auth_value=2 means GRANTED):        │
│  ✓ Photos, Desktop, Documents, Downloads, Reminders            │
│  ✓ Address Book, FileProvider, Apple Events                    │
│  ✗ Calendar (auth_value=4 means LIMITED)                       │
│                                                                 │
│  Key Services Protected:                                        │
│  - kTCCServiceSystemPolicyDesktopFolder                         │
│  - kTCCServiceSystemPolicyDocumentsFolder                       │
│  - kTCCServiceSystemPolicyDownloadsFolder                       │
│  - kTCCServiceFileProviderDomain                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 5: APP SANDBOX                                          │
├─────────────────────────────────────────────────────────────────┤
│  UTM.app Entitlements (CRITICAL FOR VM FILE ACCESS):           │
│  ✓ com.apple.security.app-sandbox: true                        │
│  ✓ com.apple.security.virtualization: true                     │
│  ✓ com.apple.vm.device-access: true                            │
│  ✓ com.apple.vm.networking: true                               │
│  ✓ com.apple.security.network.client: true                     │
│  ✓ com.apple.security.network.server: true                     │
│  ✓ com.apple.security.files.user-selected.read-write: true     │
│  ✓ com.apple.security.device.usb: true                         │
│                                                                 │
│  Container Path:                                                │
│  ~/Library/Containers/com.utmapp.UTM/                           │
│  └─ Data/                                                       │
│     ├─ Desktop → ../../../../Desktop (SYMLINKED!)              │
│     ├─ Downloads → ../../../../Downloads (SYMLINKED!)          │
│     └─ Documents/ (isolated sandbox container)                 │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 Filesystem Permission Model

```
┌─────────────────────────────────────────────────────────────────┐
│  UNIX PERMISSIONS + EXTENDED ATTRIBUTES                        │
├─────────────────────────────────────────────────────────────────┤
│  Desktop Directory Analysis:                                   │
│  drwx------@ 80 aviranchigoda staff 2560 Jan 14 19:20 .        │
│                                                                 │
│  Extended Attributes (xattr):                                   │
│  ├─ com.apple.file-provider-domain-id (80 bytes)               │
│  ├─ com.apple.fileprovider.detached#B (883 bytes)              │
│  └─ com.apple.icloud.desktop (11 bytes)                        │
│                                                                 │
│  ACLs (Access Control Lists):                                   │
│  ├─ 0: group:everyone deny delete                              │
│  └─ 1: group:everyone deny writeextattr                        │
│                                                                 │
│  File Flags (ls -O):                                            │
│  ├─ hidden: Hidden from Finder                                 │
│  ├─ compressed: HFS+ transparent compression                   │
│  └─ dataless: iCloud placeholder (content in cloud)            │
└─────────────────────────────────────────────────────────────────┘
```

### 1.4 Network Security Stack

```
┌─────────────────────────────────────────────────────────────────┐
│  FIREWALL & PACKET FILTER                                      │
├─────────────────────────────────────────────────────────────────┤
│  ✓ Application Firewall: ENABLED (State = 1)                   │
│  ✓ 34 apps with incoming connection rules                      │
│  ✓ PF (Packet Filter): Available (rules require sudo)          │
│                                                                 │
│  Active Network Interfaces:                                     │
│  ├─ en0 (Wi-Fi): 192.168.1.43/24 - PRIMARY                     │
│  ├─ utun6 (VPN): 10.100.0.2/16 - NordVPN ACTIVE                │
│  ├─ awdl0 (AirDrop): Active                                    │
│  └─ bridge0: Inactive (Thunderbolt bridge)                     │
│                                                                 │
│  VPN Routing (Split Tunnel Detection):                          │
│  ├─ 0/1 → 10.100.0.1 via utun6 (VPN captures half internet)    │
│  ├─ 128.0/1 → 10.100.0.1 via utun6 (VPN captures other half)   │
│  └─ 213.232.87.111 → 192.168.1.1 (VPN server direct)           │
└─────────────────────────────────────────────────────────────────┘
```

### 1.5 User Privilege Analysis

```
┌─────────────────────────────────────────────────────────────────┐
│  USER: aviranchigoda (UID 501)                                 │
├─────────────────────────────────────────────────────────────────┤
│  Groups:                                                        │
│  ├─ staff (20) - Primary                                       │
│  ├─ admin (80) - Full admin privileges                         │
│  ├─ _developer (204) - Developer tools access                  │
│  ├─ com.apple.access_ssh (399) - SSH access                    │
│  ├─ com.apple.access_screensharing (398)                       │
│  └─ com.apple.access_remote_ae (400) - Remote Apple Events     │
│                                                                 │
│  Sudo Privileges:                                               │
│  ├─ (ALL) ALL - Full sudo access                               │
│  └─ (ALL) NOPASSWD: pmset disablesleep commands                │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. UTM Virtualization Architecture

### 2.1 Technology Stack

```
┌─────────────────────────────────────────────────────────────────┐
│  UTM ON APPLE SILICON                                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  UTM.app (Sandboxed)                                      │ │
│  │  └─ QEMU + Apple Virtualization.framework Hybrid          │ │
│  └───────────────────────────────────────────────────────────┘ │
│                          │                                      │
│                          ▼                                      │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  Hypervisor.framework (kern.hv_support: 1)                │ │
│  │  └─ Hardware-accelerated virtualization                   │ │
│  │  └─ Direct CPU instruction execution (no emulation)       │ │
│  └───────────────────────────────────────────────────────────┘ │
│                          │                                      │
│                          ▼                                      │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  VirtIO Paravirtualized Devices                           │ │
│  │  ├─ virtio-net: Virtual network adapter                   │ │
│  │  ├─ virtio-blk: Virtual block devices (disk images)       │ │
│  │  ├─ virtio-gpu: Graphics acceleration                     │ │
│  │  └─ virtio-fs: SHARED FILESYSTEM (KEY FOR FILE TRANSFER)  │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 File Transfer Mechanisms (Ranked by Efficiency)

| Rank | Method | Latency | Throughput | Kernel Copies | Security |
|------|--------|---------|------------|---------------|----------|
| **1** | **VirtioFS (Directory Sharing)** | ~μs | Near-native | 0 (zero-copy) | Sandboxed |
| 2 | SPICE Clipboard/Drag-Drop | ~ms | Medium | 2+ | SPICE channel |
| 3 | SSH/SCP over Virtual Network | ~ms | High | 2+ | Encrypted |
| 4 | USB Passthrough | ~ms | USB 3.0 speed | 1 | Physical device |
| 5 | Shared SMB/NFS over network | ~ms | Medium | 3+ | Network protocol |

---

## 3. Optimal Low-Level File Transfer: VirtioFS

### 3.1 Why VirtioFS is the Most Efficient

```
┌─────────────────────────────────────────────────────────────────┐
│  VIRTIOFS DATA PATH                                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  macOS Host                        Linux Guest                  │
│  ┌──────────────────┐              ┌──────────────────┐        │
│  │ ~/Desktop/file   │              │ /mnt/share/file  │        │
│  │ (HFS+/APFS)      │              │ (mounted fs)     │        │
│  └────────┬─────────┘              └────────┬─────────┘        │
│           │                                 │                   │
│           │  Virtualization.framework       │  virtio-fs driver │
│           │  VZVirtioFileSystemDevice       │  (FUSE or DAX)    │
│           │                                 │                   │
│           └────────────────┬────────────────┘                   │
│                            │                                    │
│                   ┌────────▼────────┐                           │
│                   │ Shared Memory   │                           │
│                   │ (Zero-Copy DAX) │                           │
│                   └─────────────────┘                           │
│                                                                 │
│  Key Performance Characteristics:                               │
│  ✓ Direct memory mapping (DAX mode) - no data copying          │
│  ✓ Bypasses guest filesystem cache when using DAX              │
│  ✓ Sub-millisecond latency for small files                     │
│  ✓ Near-native throughput for large files                      │
│  ✓ File metadata operations map directly to host               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Implementation Steps

#### Step 1: Create ARM64 Linux VM in UTM

```bash
# UTM GUI: Create new VM
# - Type: Virtualize (not Emulate) for Apple Silicon native speed
# - OS: Linux
# - Architecture: ARM64 (aarch64)
# - RAM: 4096 MB recommended
# - Storage: 64 GB+ qcow2
# - ISO: Ubuntu 24.04 ARM64 or Fedora ARM64
```

#### Step 2: Configure VirtioFS Directory Sharing in UTM

```
UTM VM Settings → Sharing:
├─ Enable Directory Sharing: ON
├─ Shared Directory: /Users/aviranchigoda/Desktop
├─ Read Only: OFF (for bidirectional transfer)
└─ Mount Tag: "hostshare" (used in Linux fstab)
```

#### Step 3: Mount in Linux Guest

```bash
# One-time mount (run inside Linux VM)
sudo mkdir -p /mnt/macos-desktop
sudo mount -t virtiofs hostshare /mnt/macos-desktop

# Persistent mount (add to /etc/fstab)
echo "hostshare /mnt/macos-desktop virtiofs defaults,nofail 0 0" | sudo tee -a /etc/fstab

# Verify mount
ls -la /mnt/macos-desktop
# You will see your macOS Desktop files directly
```

#### Step 4: Transfer Files (Zero-Copy)

```bash
# From macOS Terminal - just copy to Desktop
cp /path/to/file ~/Desktop/transfer/

# Inside Linux VM - file appears instantly
ls /mnt/macos-desktop/transfer/
cat /mnt/macos-desktop/transfer/file

# Reverse direction works too
# Inside Linux VM:
echo "from linux" > /mnt/macos-desktop/from_linux.txt
# On macOS, file appears on Desktop immediately
```

---

## 4. Alternative: SSH Over Virtual Network

If VirtioFS is unavailable or you need encrypted transfer:

### 4.1 UTM Virtual Network Configuration

```
UTM VM Settings → Network:
├─ Network Mode: Shared Network (NAT with host-to-guest)
├─ Port Forward: Host 2222 → Guest 22 (SSH)
└─ Or: Bridged (VM gets LAN IP directly)
```

### 4.2 SSH Transfer Commands

```bash
# Enable SSH in Linux VM
sudo apt install openssh-server
sudo systemctl enable --now sshd

# From macOS Terminal (with port forward)
scp -P 2222 ~/Desktop/myfile.txt localhost:/home/user/

# Or with Bridged mode (if VM IP is 192.168.1.100)
scp ~/Desktop/myfile.txt user@192.168.1.100:/home/user/

# Rsync for efficient syncing
rsync -avz --progress ~/Desktop/project/ user@192.168.1.100:/home/user/project/
```

---

## 5. Security Considerations for Cybersecurity Operations

### 5.1 Sandboxed File Access

UTM's sandbox restricts arbitrary filesystem access. Only user-selected directories or symlinked paths in the container work:

```
Safe paths for sharing:
├─ ~/Desktop (symlinked into UTM container)
├─ ~/Downloads (symlinked)
├─ ~/Documents (requires TCC permission)
└─ Any folder explicitly added via UTM's Open Panel
```

### 5.2 Bypassing Sandbox for Full Control (If Needed)

For maximum control, you can use non-sandboxed UTM:

```bash
# Download UTM from GitHub releases (not Mac App Store)
# The GitHub version has:
# - com.apple.security.app-sandbox: false
# - Full filesystem access
# - QEMU backend with more device options
```

### 5.3 Firewall Rules for VM Traffic

```bash
# Allow traffic from VM subnet (if using shared network, typically 192.168.64.0/24)
# Check VM IP with: arp -a | grep vmnet

# If needed, add PF rule
echo "pass in quick on vmnet8 all" | sudo pfctl -ef -
```

---

## 6. Verification Commands

```bash
# On macOS: Verify UTM has virtualization entitlement
codesign -d --entitlements - /Applications/UTM.app 2>&1 | grep virtualization

# On macOS: Check if Hypervisor is available
sysctl kern.hv_support
# Expected: kern.hv_support: 1

# Inside Linux VM: Verify VirtioFS mount
mount | grep virtiofs
df -h /mnt/macos-desktop

# Test transfer speed (in Linux VM)
dd if=/dev/zero of=/mnt/macos-desktop/testfile bs=1M count=100
# Expected: 200+ MB/s on M2 Pro with VirtioFS
```

---

## Summary: Recommended Approach

**For a cybersecurity professional requiring maximum control:**

1. **Install UTM from GitHub** (non-sandboxed version) for full filesystem access
2. **Use VirtioFS Directory Sharing** for zero-copy, kernel-level file transfer
3. **Mount ~/Desktop as the shared directory** - already symlinked into UTM's container
4. **Simple terminal command to transfer:**
   ```bash
   # Just copy to Desktop, it appears in Linux VM instantly
   cp /path/to/file ~/Desktop/
   ```

This approach operates at the lowest practical level (paravirtualized device directly mapping host memory) while respecting macOS security architecture.
