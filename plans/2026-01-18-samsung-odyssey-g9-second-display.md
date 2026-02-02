# Samsung Odyssey G9 Second Display - Software-Only Solutions

## Problem Summary
- M2 Pro MacBook Pro with two Samsung Odyssey G9 displays
- One display works (right port), one doesn't (left port)
- Cause: Rapid hot-unplug corrupted DisplayPort Alt Mode state

## Diagnostic Results
- USB-C ports work (both cables detected as USB devices)
- DisplayPort Alt Mode negotiation fails on one cable/port

---

## Software-Only Solutions (No Cable Changes Required)

### Option 1: Force Display Detection
Open System Settings, go to Displays, hold **Option** key and click "Detect Displays"

### Option 2: Kill WindowServer (Logs You Out)
This restarts the entire display subsystem without a full reboot.
**Warning:** This will log you out and close all apps (same as logging out).
```bash
sudo killall WindowServer
```

### Option 3: Delete Display Preferences (Requires Logout)
Remove cached display configuration:
```bash
rm ~/Library/Preferences/ByHost/com.apple.windowserver.*
```
Then log out and log back in.

### Option 4: Safe Mode Quick Test
Hold Shift during boot to enter Safe Mode, check if display works, then restart normally. Safe Mode resets display drivers.

---

## Limitation

DisplayPort Alt Mode negotiation happens at the hardware/firmware level. **A full restart is the most reliable software fix** because it resets both macOS and the USB-C controller firmware.

Without physically touching cables or restarting, the options above have lower success rates because the USB-C port's firmware state may be stuck.

---

## Verification Command
```bash
system_profiler SPDisplaysDataType
```
Success = Both Odyssey displays listed
