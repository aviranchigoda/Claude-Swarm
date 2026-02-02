# Fix Corrupted Display Configuration

## Problem
The Mac crash corrupted the WindowServer display configuration plist. The file contains invalid 1x1 resolution entries that are preventing the second display from initializing properly.

## Evidence
- Both USB-C to DP cables are detected (two Chrontel CH7213 Billboard devices)
- First display works: Odyssey G93SD at 5120x1440@60Hz
- Second display fails to engage DisplayPort mode
- Config file shows corrupted `UnmirrorInfo` entries with `Wide=1, High=1`
- Historical config proves dual 5120x1440@120Hz setup worked previously

## Fix Steps

### Step 1: Backup and remove corrupted display preferences
```bash
mv ~/Library/Preferences/ByHost/com.apple.windowserver.displays.F94555C3-1180-5BF3-8C0C-CA9E4FAC45DF.plist ~/Desktop/windowserver.displays.backup.plist
```

### Step 2: Clear WindowServer cache
```bash
rm -f ~/Library/Preferences/com.apple.CoreGraphics.plist
```

### Step 3: Reset NVRAM display routing
```bash
sudo nvram -d display-crossbar0
```

### Step 4: Restart WindowServer (will log you out)
```bash
sudo killall WindowServer
```

### Step 5: After logging back in
1. Connect first monitor - wait for detection
2. Connect second monitor - wait for detection
3. Open System Settings > Displays to arrange them

## Verification
After restart, run:
```bash
system_profiler SPDisplaysDataType
```
Should show both Odyssey G93SD displays.

## Rollback (if needed)
```bash
mv ~/Desktop/windowserver.displays.backup.plist ~/Library/Preferences/ByHost/com.apple.windowserver.displays.F94555C3-1180-5BF3-8C0C-CA9E4FAC45DF.plist
```
