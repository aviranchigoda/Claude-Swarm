# Agent Command - Desktop GUI Conversion Plan

## Summary
Convert the terminal TUI application (using ratatui/crossterm) into a native desktop GUI application using **egui/eframe**.

---

## Why egui/eframe?

- **Immediate mode GUI** - Fits perfectly with the existing refresh-based architecture
- **Single crate** - eframe bundles everything needed (windowing, graphics, input)
- **Cross-platform** - Works on Linux, macOS, Windows
- **Fast iteration** - No complex state management, just redraw each frame
- **Modern look** - Clean, professional appearance out of the box
- **Active ecosystem** - Well-maintained, good documentation

---

## Architecture Overview

### Current (Terminal TUI)
```
main() → event loop → poll input → refresh data → render to terminal
```

### New (Desktop GUI)
```
main() → eframe::run_native() → App::update() → refresh data → render egui widgets
```

**Key insight**: The `App` struct and all data collection logic stays the same. Only the rendering layer changes.

---

## Implementation Plan

### Phase 1: Update Dependencies

**File: `Cargo.toml`**

Remove:
```toml
ratatui = "0.28"
crossterm = "0.28"
```

Add:
```toml
eframe = "0.31"
egui = "0.31"
egui_extras = "0.31"  # For tables and images
```

Keep:
```toml
sysinfo = "0.31"
chrono = "0.4"
anyhow = "1.0"
```

---

### Phase 2: Core Application Structure

**File: `src/main.rs`**

#### 2.1 Entry Point
```rust
fn main() -> eframe::Result<()> {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([1200.0, 800.0])
            .with_title("Agent Command"),
        ..Default::default()
    };

    eframe::run_native(
        "Agent Command",
        options,
        Box::new(|cc| Ok(Box::new(App::new(cc)))),
    )
}
```

#### 2.2 Implement eframe::App Trait
```rust
impl eframe::App for App {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        // Check if refresh needed (every 2 seconds)
        if self.last_refresh.elapsed() >= self.refresh_interval {
            self.refresh_all();
        }

        // Request continuous repainting for live updates
        ctx.request_repaint_after(Duration::from_millis(100));

        // Render UI
        self.render_ui(ctx);
    }
}
```

---

### Phase 3: Color Theme

**Map existing colors to egui:**

```rust
mod colors {
    use egui::Color32;

    pub const BG_PRIMARY: Color32 = Color32::from_rgb(8, 8, 8);
    pub const BG_SECONDARY: Color32 = Color32::from_rgb(12, 12, 12);
    pub const BG_TERTIARY: Color32 = Color32::from_rgb(18, 18, 18);
    pub const BG_HIGHLIGHT: Color32 = Color32::from_rgb(40, 60, 80);

    pub const TEXT_PRIMARY: Color32 = Color32::from_rgb(220, 220, 220);
    pub const TEXT_SECONDARY: Color32 = Color32::from_rgb(140, 140, 140);
    pub const TEXT_MUTED: Color32 = Color32::from_rgb(80, 80, 80);

    pub const ACCENT_BLUE: Color32 = Color32::from_rgb(100, 149, 237);
    pub const ACCENT_GREEN: Color32 = Color32::from_rgb(80, 200, 120);
    pub const ACCENT_YELLOW: Color32 = Color32::from_rgb(255, 193, 7);
    pub const ACCENT_RED: Color32 = Color32::from_rgb(220, 53, 69);
    pub const ACCENT_PURPLE: Color32 = Color32::from_rgb(138, 43, 226);
}
```

---

### Phase 4: UI Layout

#### 4.1 Main Layout Structure
```
┌─────────────────────────────────────────────────────────────┐
│  [Dashboard] [Server] [Sessions] [Claude]      Status Bar   │  ← Top Panel (tabs)
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    Central Panel                            │  ← Page content
│                    (changes per tab)                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 4.2 Tab Navigation
```rust
fn render_tabs(&mut self, ui: &mut egui::Ui) {
    ui.horizontal(|ui| {
        ui.selectable_value(&mut self.current_page, Page::Dashboard, "Dashboard");
        ui.selectable_value(&mut self.current_page, Page::Server, "Server");
        ui.selectable_value(&mut self.current_page, Page::Sessions, "Sessions");
        ui.selectable_value(&mut self.current_page, Page::Claude, "Claude");
    });
}
```

---

### Phase 5: Page Implementations

#### 5.1 Dashboard Page
- **Summary cards** using `egui::Frame` with colored backgrounds
- **Stats display**: CPU%, Memory GB, Session count, Claude count
- **Alerts list**: Scrollable with colored severity indicators

#### 5.2 Server Page
- **Progress bars** for CPU, Memory, Disk using `egui::ProgressBar`
- **System info panel** with hostname, IP, OS, kernel, uptime
- **Load average display**

#### 5.3 Sessions Page (Split Panel)
- **Left**: Scrollable session list using `egui::ScrollArea`
- **Right**: Selected session details (path, git info, panes)
- **Actions**: New session button, Kill button, Attach button

#### 5.4 Claude Page (Split Panel)
- **Left**: Claude process list with status indicators
- **Right**: Activity log (or process details)
- **Actions**: Kill process button

---

### Phase 6: Interactive Elements

#### 6.1 List Selection
```rust
fn render_session_list(&mut self, ui: &mut egui::Ui) {
    egui::ScrollArea::vertical().show(ui, |ui| {
        for (i, session) in self.sessions.iter().enumerate() {
            let selected = self.selected_session == Some(i);
            let response = ui.selectable_label(selected, &session.name);
            if response.clicked() {
                self.selected_session = Some(i);
                self.refresh_selected_session_panes();
            }
        }
    });
}
```

#### 6.2 Action Buttons
```rust
fn render_session_actions(&mut self, ui: &mut egui::Ui) {
    ui.horizontal(|ui| {
        if ui.button("New Session").clicked() {
            self.create_new_session();
        }
        if ui.button("Attach").clicked() {
            if let Some(idx) = self.selected_session {
                self.attach_to_session(&self.sessions[idx].name);
            }
        }
        if ui.button("Kill").clicked() {
            if let Some(idx) = self.selected_session {
                self.kill_session(&self.sessions[idx].name);
            }
        }
    });
}
```

#### 6.3 Keyboard Shortcuts
```rust
fn handle_input(&mut self, ctx: &egui::Context) {
    if ctx.input(|i| i.key_pressed(egui::Key::Num1)) {
        self.current_page = Page::Dashboard;
    }
    if ctx.input(|i| i.key_pressed(egui::Key::Num2)) {
        self.current_page = Page::Server;
    }
    // ... etc
}
```

---

### Phase 7: Preserve Backend Logic

**These functions remain unchanged:**
- `refresh_system_stats()` - System info via sysinfo + shell commands
- `refresh_sessions()` - tmux list-sessions parsing
- `refresh_claude_processes()` - pgrep + /proc filesystem
- `refresh_alerts()` - Alert generation based on thresholds
- `build_pane_pid_map()` - PID to session mapping
- `find_session_for_pid()` - Parent chain walking
- `get_git_info()` - Git branch/status detection
- All Command::new() calls for tmux operations

---

### Phase 8: Remove Terminal-Specific Code

**Delete:**
- All `ratatui::` imports and usages
- All `crossterm::` imports and usages
- `render_*` functions that use ratatui widgets
- Terminal setup/teardown in main()
- `ListState` (use egui selection instead)
- Mouse event handling (egui handles this)
- Raw mode / alternate screen management

---

## Files to Modify

| File | Action |
|------|--------|
| `Cargo.toml` | Replace dependencies |
| `src/main.rs` | Complete rewrite of UI layer, keep backend |

---

## Verification

1. **Build**: `cargo build` - Should compile without errors
2. **Run**: `cargo run` - Desktop window should open
3. **Test tabs**: Click each tab, verify page switches
4. **Test data**: Verify sessions and Claude processes appear
5. **Test refresh**: Wait 2+ seconds, data should auto-update
6. **Test actions**:
   - Create new session (N or button)
   - Select session, click Attach
   - Kill a session
7. **Test keyboard**: 1-4 should switch tabs

---

## Estimated Structure

```rust
// main.rs (~800-1000 lines total)

mod colors { ... }           // ~20 lines

// Data structs (unchanged)
struct TmuxSession { ... }   // ~15 lines
struct PaneInfo { ... }      // ~12 lines
struct ClaudeProcess { ... } // ~10 lines
struct SystemStats { ... }   // ~18 lines
struct Alert { ... }         // ~6 lines
enum Page { ... }            // ~6 lines
enum ClaudeStatus { ... }    // ~5 lines
enum AlertLevel { ... }      // ~6 lines

struct App { ... }           // ~25 lines

impl App {
    fn new() { ... }         // ~30 lines

    // Backend (unchanged)
    fn refresh_all() { ... }
    fn refresh_system_stats() { ... }
    fn refresh_sessions() { ... }
    fn refresh_claude_processes() { ... }
    fn refresh_alerts() { ... }
    fn refresh_selected_session_panes() { ... }
    // ... helper functions (~400 lines total)

    // New UI rendering
    fn render_ui() { ... }           // ~30 lines
    fn render_tabs() { ... }         // ~15 lines
    fn render_dashboard() { ... }    // ~80 lines
    fn render_server() { ... }       // ~100 lines
    fn render_sessions() { ... }     // ~120 lines
    fn render_claude() { ... }       // ~100 lines
    fn handle_input() { ... }        // ~30 lines
}

impl eframe::App for App { ... }  // ~15 lines

fn main() { ... }            // ~15 lines
```

---

## Benefits of Desktop GUI

1. **No terminal required** - Runs as standalone window
2. **Better visuals** - Smooth progress bars, proper fonts
3. **Mouse-first** - Click to select, scroll naturally
4. **Resizable** - Window adapts to any size
5. **Multi-monitor** - Can position on any display
6. **Copy/paste** - Standard OS clipboard support
7. **Accessibility** - Better screen reader support
