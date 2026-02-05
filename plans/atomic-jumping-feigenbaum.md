# Plan: Upload Claude SSH Screenshot Tool to GitHub

## Task
Create a professional GitHub repository containing all code for the Claude Code SSH image paste solution.

## GitHub Account
- **Username**: aviranchigoda
- **Repository name**: `claude-ssh-screenshot`
- **Visibility**: Public (so others can use it)

---

## Repository Structure

```
claude-ssh-screenshot/
├── README.md                    # Main documentation
├── LICENSE                      # MIT License
├── mac/
│   ├── claude-paste.sh          # Main screenshot script
│   └── hammerspoon-init.lua     # Hammerspoon hotkey config
├── server/
│   ├── setup.sh                 # Server setup script
│   └── triggers.json            # Claude Code image triggers
└── docs/
    └── TROUBLESHOOTING.md       # Detailed troubleshooting guide
```

---

## Files to Create

### 1. README.md (Main)
Professional README with:
- Project description and demo
- Quick start guide
- Architecture diagram
- Requirements
- Installation steps
- Usage instructions
- Configuration options

### 2. mac/claude-paste.sh
Copy from: `~/.claude/mac-scripts/claude-paste.sh`

### 3. mac/hammerspoon-init.lua
Updated version using `hs.execute()` that works:
```lua
hs.hotkey.bind({"cmd", "shift"}, "V", function()
    hs.execute(os.getenv("HOME") .. "/bin/claude-paste.sh", true)
end)
```

### 4. server/setup.sh
Script to set up server-side:
- Create ~/.claude/paste-cache/images/
- Add image triggers to Claude Code

### 5. server/triggers.json
The image trigger configuration

### 6. LICENSE
MIT License

---

## Implementation Steps

1. Create GitHub repository `claude-ssh-screenshot`
2. Create all files with professional formatting
3. Push to GitHub
4. Return repository URL to user

---

## Verification

1. Repository exists at https://github.com/aviranchigoda/claude-ssh-screenshot
2. README displays correctly
3. All files are present and properly formatted
