# Plan: Organize tmux-desktop Projects & Merge ChatGPT UI

## Summary

Consolidate the tmux-desktop project across Linux server and Mac, push to GitHub, and upgrade the Sessions UI with the ChatGPT-designed 3-column layout.

---

## Part 1: Push Linux tmux-desktop to New GitHub Repo

**Goal**: Create `aviranchigoda/tmux-desktop-sydney-server` repository

**Steps**:
1. Initialize git in `/home/ai_dev/tmux-final/tmux-desktop/`
2. Create `.gitignore` for Node/Electron project (node_modules, dist, out, etc.)
3. Create the new GitHub repository `tmux-desktop-sydney-server`
4. Add remote, commit all files, and push

**Files involved**:
- `/home/ai_dev/tmux-final/tmux-desktop/` (entire directory)

---

## Part 2: Push Mac tmux-desktop to tmux-software Repo

**Goal**: Add Mac version as a new branch `tmux-desktop-mac` in existing `tmux-software` repo

**Constraint**: I cannot directly access the Mac filesystem from this Linux server.

**Options**:
1. **You run git commands on Mac** - I provide the exact commands to run
2. **Copy files to server** - You sync the Mac folder to server, then I push it

**Recommended approach**: I'll provide the exact git commands for you to run on your Mac.

---

## Part 3: Merge ChatGPT SessionsPage.tsx into Codebase

**Goal**: Replace the existing simple table-based SessionsPage with the new 3-column layout

### UI Comparison

| Feature | Current | ChatGPT Version |
|---------|---------|-----------------|
| Layout | Single table in card | 3-column grid (sidebar, main, decision surface) |
| Session selection | Modal popup | Inline sidebar selection |
| Details view | Modal | Inline center panel |
| Risk indicators | None | HIGH/MEDIUM/LOW based on inactivity |
| Activity feed | None | Real-time feed in right panel |
| Capture output | None | Capture pane content to modal |
| Window matrix | Simple list in modal | Visual load bars inline |
| Command bar | None | Bottom bar with tmux command preview |

### Required Changes

**1. Zustand Store** (`src/renderer/src/store/appStore.ts`)
✅ Already has `selectedSession` and `setSelectedSession` - NO CHANGES NEEDED

**2. Replace SessionsPage.tsx** (`src/renderer/src/pages/SessionsPage.tsx`)
- Replace entire file with ChatGPT version
- File grows from ~310 lines to ~600 lines

**3. Verify Component Compatibility**
The ChatGPT version uses existing components:
- `Header` from `../components/layout` ✓
- `Button`, `Modal`, `Input` from `../components/common` ✓
- `useAppStore` from `../store/appStore` ✓
- Types: `TmuxSession`, `TmuxWindow` ✓

**4. Test Build**
Run `npm run dev` to verify no TypeScript errors

---

## Execution Order

1. **Git setup for Linux tmux-desktop** - init, .gitignore, initial commit
2. **Create GitHub repo** - `tmux-desktop-sydney-server`
3. **Push to GitHub** - add remote and push
4. **Replace SessionsPage.tsx** - swap in ChatGPT 3-column UI
5. **Test build** - `npm run dev` to verify
6. **Commit UI changes** - commit the SessionsPage upgrade
7. **Provide Mac git commands** - you execute on your Mac

---

## Verification

1. Run `npm run dev` - app should start without errors
2. Navigate to Sessions page - should see 3-column layout
3. Select a session - details should appear in center panel
4. Verify all buttons work: Attach, Capture, Kill, New Session
5. Check GitHub repos are properly set up

---

## Files to Modify

| File | Action |
|------|--------|
| `/home/ai_dev/tmux-final/tmux-desktop/.gitignore` | Create |
| `/home/ai_dev/tmux-final/tmux-desktop/src/renderer/src/pages/SessionsPage.tsx` | Replace with ChatGPT version |

---

## Mac Commands (for you to run)

```bash
cd /Users/aviranchigoda/tmux-desktop
git init
git remote add origin https://github.com/aviranchigoda/tmux-software.git
git checkout -b tmux-desktop-mac
git add .
git commit -m "Add Mac tmux-desktop codebase"
git push -u origin tmux-desktop-mac
```

---

## Questions Resolved

- ✅ ChatGPT file location: Provided in chat
- ✅ Mac path: `/Users/aviranchigoda/tmux-desktop`
- ✅ GitHub organization: New repo `tmux-desktop-sydney-server` for Linux version
