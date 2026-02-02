-- =============================================================================
-- Claude Code Image Paste - Hammerspoon Configuration
-- =============================================================================
-- Add this to your ~/.hammerspoon/init.lua
-- Then reload Hammerspoon: Cmd+Shift+R or click menu bar -> Reload Config
-- =============================================================================

-- Claude Code Image Paste (Cmd+Shift+V)
-- Captures clipboard image, uploads to server, copies path to clipboard
hs.hotkey.bind({"cmd", "shift"}, "V", function()
    local home = os.getenv("HOME")
    local script = home .. "/bin/claude-paste.sh"

    -- Check if script exists
    local f = io.open(script, "r")
    if f == nil then
        hs.alert.show("claude-paste.sh not found at ~/bin/")
        return
    end
    f:close()

    -- Run the script asynchronously
    local task = hs.task.new(script, function(exitCode, stdOut, stdErr)
        if exitCode ~= 0 then
            -- Script handles its own notifications, but show alert for unexpected errors
            if exitCode ~= 1 then  -- exit 1 is handled by script (no image, upload failed)
                hs.alert.show("Claude Paste error: " .. tostring(exitCode))
            end
        end
    end)

    if not task:start() then
        hs.alert.show("Failed to start claude-paste.sh")
    end
end)

-- Optional: Show alert on load to confirm binding
-- hs.alert.show("Claude Paste: Cmd+Shift+V")
