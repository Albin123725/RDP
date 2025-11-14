# Design Guidelines: Web-Based Developer Workspace

## Design Approach
**System-Based Approach**: Drawing from VS Code, GitHub, and Linear's design patterns for developer-focused applications. Prioritizing information density, functional clarity, and efficient workflows over visual flourish.

## Layout Architecture

### Application Structure
- **Full-viewport layout**: No traditional webpage structure - this is an application interface filling 100vh
- **Three-panel layout**:
  - Left sidebar (w-64): File tree navigator with collapsible folders
  - Center panel (flex-1): Tabbed content area (editor/terminal/file viewer)
  - Right panel (w-80, collapsible): GitHub integration sidebar
- **Top toolbar** (h-12): Application menu, breadcrumbs, and actions
- **Bottom status bar** (h-8): System info, git status, terminal toggle

### Panel Behavior
- Resizable panels using drag handles between sections
- Collapsible sidebars with toggle buttons
- Minimum panel widths to prevent breaking layout
- Panel state persists across sessions

## Typography System

### Font Families
- **UI Text**: Inter or System UI (-apple-system, BlinkMacSystemFont)
- **Code**: JetBrains Mono or Fira Code (monospace with ligatures)

### Type Scale
- **Toolbar/Menu**: text-sm (14px), font-medium
- **File names**: text-sm (14px), font-normal
- **Code editor**: text-sm (14px), font-mono, leading-relaxed
- **Section headers**: text-xs (12px), font-semibold, uppercase, tracking-wide
- **Status bar**: text-xs (12px), font-normal

## Spacing System
**Tailwind Units**: 2, 3, 4, 6, 8, 12
- Component padding: p-3, p-4
- List item spacing: py-2, px-3
- Section gaps: gap-4, gap-6
- Panel padding: p-4, p-6
- Icon spacing: gap-2, gap-3

## Component Library

### Navigation & Sidebar
- **File Tree**: Nested list with indent levels (pl-4 per level), folder icons with expand/collapse arrows, file type icons
- **GitHub Sidebar**: Repository list, branch selector, recent commits feed, clone repository button

### Tabbed Interface
- **Tab Bar**: Horizontal tabs with close buttons, active tab indicator, overflow scroll for many tabs
- **Tab Content**: Full-height content area, independent scroll per tab
- **Tab Types**: Code editor, terminal, file preview, diff viewer

### Terminal Component
- **Terminal Window**: Full-bleed monospace text area, command prompt with user@host prefix
- **Terminal Controls**: Clear, split terminal, new terminal tabs
- **Output Styling**: ANSI color support, clickable file paths

### Code Editor
- **Editor Canvas**: Line numbers (w-12), syntax highlighting zones, current line highlight
- **Editor Gutter**: Line numbers, git diff indicators, breakpoint markers
- **Minimap**: Optional code overview (w-20, right edge)

### File Manager
- **List View**: Icon + filename, file size, modified date
- **Grid View**: Large file icons in responsive grid (grid-cols-4 to grid-cols-8)
- **Context Menu**: Right-click actions (rename, delete, download, open with)
- **Toolbar Actions**: Upload, new file, new folder, search, sort options

### Action Buttons
- **Primary Actions**: Prominent buttons for critical actions (Clone, Run, Save)
- **Icon Buttons**: Small square/circular buttons (h-8 w-8) for toolbar actions
- **Button Groups**: Segmented controls for view switching (list/grid)

### Forms & Inputs
- **Search Bar**: Icon prefix, clear button suffix, full-width in toolbar
- **Path Input**: Breadcrumb-style editable path
- **Dropdowns**: Repository selector, branch selector with search

## Interaction Patterns

### Split Views
- **Horizontal Split**: Terminal below editor
- **Vertical Split**: Multiple files side-by-side
- **Drag to Split**: Drop zones for file tabs

### GitHub Integration
- **Repository Actions**: Clone via URL input, browse public repos
- **File Preview**: Click repo files to preview in editor
- **Branch Switching**: Dropdown selector updates file tree

### Keyboard Shortcuts
- Display hint labels (text-xs, opacity-70) next to menu items
- Common shortcuts: Cmd+P (quick open), Cmd+K (command palette)

## Visual Hierarchy

### Depth Layers
- **Level 0** (Background): Main application surface
- **Level 1** (Raised): Sidebar panels, toolbars
- **Level 2** (Floating): Active tab, dropdowns, context menus
- **Level 3** (Modal): Dialogs, command palette overlays

### Borders & Dividers
- **Panel Dividers**: 1px borders between major sections
- **Resize Handles**: 4px wide interactive zones
- **Subtle Separators**: border-t or border-b for list items

## Iconography
**Library**: Heroicons (outline for inactive, solid for active states)
- File types: document, folder, code, terminal icons
- Actions: plus, trash, download, upload, settings
- Git: branch, commit, pull request icons
- UI: chevrons, x-marks, menu icons

## Responsive Behavior
- **Desktop (≥1024px)**: Full three-panel layout
- **Tablet (768-1023px)**: Collapsible sidebars, two-panel max
- **Mobile (<768px)**: Single panel, bottom tab bar navigation, hamburger menu for sidebars

## Performance Considerations
- Virtualized lists for large file trees (only render visible items)
- Lazy loading for file contents
- Debounced search inputs
- Cached syntax highlighting

## No Images Required
This is a functional application interface - all visuals are UI components, icons, and rendered content. No hero images or marketing imagery needed.