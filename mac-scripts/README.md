# Claude Code SSH Image Paste - Mac Setup

This folder contains scripts to enable one-keystroke image pasting from your Mac to the Linux server running Claude Code.

## How It Works

1. **Cmd+Shift+V** - Captures clipboard image, uploads via SCP, copies remote path to clipboard
2. **Cmd+V** - Paste the path into Claude Code prompt
3. Claude reads the image using its Read tool

## Quick Setup (5 minutes)

### Step 1: Install pngpaste on Mac

```bash
brew install pngpaste
```

Test it works:
```bash
# Copy an image to clipboard first (Cmd+Shift+4 for screenshot)
pngpaste /tmp/test.png && ls -la /tmp/test.png
```

### Step 2: Copy the paste script

From your Mac terminal:

```bash
# Create bin directory if needed
mkdir -p ~/bin

# Copy the script from the server
scp linode-sydney:~/.claude/mac-scripts/claude-paste.sh ~/bin/

# Make it executable
chmod +x ~/bin/claude-paste.sh
```

Test it works:
```bash
# Copy an image to clipboard first
~/bin/claude-paste.sh

# Check the path was copied to clipboard
pbpaste
```

### Step 3: Configure Hammerspoon hotkey

If you don't have Hammerspoon installed:
```bash
brew install --cask hammerspoon
```

Add to your `~/.hammerspoon/init.lua`:

```lua
-- Claude Code Image Paste (Cmd+Shift+V)
hs.hotkey.bind({"cmd", "shift"}, "V", function()
    local task = hs.task.new(os.getenv("HOME") .. "/bin/claude-paste.sh", function(exitCode, stdOut, stdErr)
        if exitCode ~= 0 and exitCode ~= 1 then
            hs.alert.show("Claude Paste error: " .. tostring(exitCode))
        end
    end)
    task:start()
end)
```

Or copy the full version:
```bash
cat ~/.hammerspoon/init.lua  # Check existing content first
scp linode-sydney:~/.claude/mac-scripts/hammerspoon-init.lua /tmp/
cat /tmp/hammerspoon-init.lua >> ~/.hammerspoon/init.lua
```

Reload Hammerspoon: **Cmd+Shift+R** or click menu bar → Reload Config

## Usage

1. **Take a screenshot**: Cmd+Shift+4 (or any method that copies image to clipboard)
2. **Upload to server**: Cmd+Shift+V
3. **Wait for notification**: "Claude Paste ✓" with filename
4. **In Claude Code prompt**: Cmd+V (pastes the full path)
5. **Ask Claude**: "describe this screenshot" or "analyze this image"

## Example Session

```
You: /home/ai_dev/.claude/paste-cache/images/2026-02-02_143022_a7f3b2.png

please describe what you see in this screenshot
```

## Trigger Commands (Server Side)

These triggers are now available in Claude Code:

| Command | Action |
|---------|--------|
| `show images` | List recent uploaded images |
| `latest image` | Get path of most recent image |
| `clear images` | Delete old images (keeps last 10) |

## Troubleshooting

### "pngpaste not installed"
```bash
brew install pngpaste
```

### "No image in clipboard"
Make sure you have an image (not text) in your clipboard. Use Cmd+Shift+4 to capture a screenshot.

### "Upload failed"
Check SSH connection:
```bash
ssh linode-sydney 'echo "Connection OK"'
```

### Path not copying to clipboard
The script uses `pbcopy`. Make sure it's available:
```bash
which pbcopy  # Should show /usr/bin/pbcopy
```

### Hammerspoon hotkey not working
1. Check Hammerspoon is running (menu bar icon)
2. Reload config: Cmd+Shift+R
3. Grant accessibility permissions in System Settings → Privacy & Security → Accessibility

## Files

| File | Purpose |
|------|---------|
| `claude-paste.sh` | Main upload script (copy to ~/bin/) |
| `hammerspoon-init.lua` | Hammerspoon hotkey config (append to init.lua) |
| `README.md` | This file |

## Customization

### Use a different SSH alias

Edit `~/bin/claude-paste.sh` and change:
```bash
SSH_ALIAS="${CLAUDE_SSH_ALIAS:-linode-sydney}"
```

Or set environment variable:
```bash
export CLAUDE_SSH_ALIAS="my-other-server"
```

### Change the hotkey

Edit `~/.hammerspoon/init.lua`:
```lua
-- Change from Cmd+Shift+V to Ctrl+Shift+P
hs.hotkey.bind({"ctrl", "shift"}, "P", function()
```
