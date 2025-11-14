# DevSpace - Web-Based Developer Workspace

## Overview
DevSpace is a comprehensive web-based development environment featuring an integrated terminal, file manager, code editor, and GitHub integration. Built with React, TypeScript, and Express, it provides a VS Code-like experience directly in the browser.

## Recent Changes
- **November 14, 2025**: Initial implementation of complete frontend with all MVP features
  - Three-panel resizable layout with file tree, editor/terminal tabs, and GitHub sidebar
  - Monaco code editor with syntax highlighting
  - XTerm.js terminal emulator
  - GitHub repository browser
  - Tab system for multiple files/terminals
  - Dark/light theme support
  - Responsive design following design guidelines

## Project Architecture

### Frontend (`client/src/`)
- **React + TypeScript** with Wouter for routing
- **Tailwind CSS + shadcn/ui** for styling
- **TanStack Query** for server state management
- **Monaco Editor** for code editing
- **XTerm.js** for terminal emulation
- **React Resizable Panels** for layout

### Backend (`server/`)
- **Express.js** server
- **WebSocket** for terminal I/O (to be implemented)
- **GitHub API** integration via Octokit
- **File system** operations

### Key Components
- `workspace.tsx` - Main workspace layout with three panels
- `file-tree.tsx` - Nested file/folder browser
- `code-editor.tsx` - Monaco editor wrapper
- `terminal.tsx` - XTerm terminal component
- `github-sidebar.tsx` - Repository browser
- `workspace-tabs.tsx` - Tab management
- `status-bar.tsx` - Bottom status information
- `theme-provider.tsx` - Dark/light mode

### Data Models (`shared/schema.ts`)
- `FileNode` - File tree structure
- `FileContent` - File contents with metadata
- `TerminalSession` - Terminal session data
- `GitHubRepo` - Repository information
- `Tab` - Editor/terminal tab data

## Technology Stack
- **Frontend**: React 18, TypeScript, Tailwind CSS
- **Backend**: Node.js, Express, WebSocket
- **Code Editor**: Monaco Editor (VS Code engine)
- **Terminal**: XTerm.js with fit and web-links addons
- **GitHub**: Octokit REST API client
- **State Management**: TanStack Query v5
- **UI Components**: shadcn/ui (Radix UI primitives)
- **Styling**: Tailwind CSS with custom design system

## Design System
- **Fonts**: Inter (UI), JetBrains Mono (code)
- **Colors**: VS Code-inspired with blue primary color
- **Spacing**: Consistent 4/8/12/16px scale
- **Layout**: Full-viewport application interface
- **Theme**: Dark mode by default, light mode available

## Development Status
- ✅ Phase 1: Complete frontend with all components
- ⏳ Phase 2: Backend API implementation (pending)
- ⏳ Phase 3: Integration and testing (pending)

## Running the Application
```bash
npm run dev
```
Starts Express server on port 5000 with Vite dev server for frontend.

## Features
- Browse and edit files with syntax highlighting
- Execute commands in integrated terminal
- View and clone GitHub repositories
- Multiple editor and terminal tabs
- Resizable panels
- Dark/light theme toggle
- Responsive layout
