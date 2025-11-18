# 24/7 Ubuntu noVNC Desktop - Replit Project

## Project Overview

This project provides a Docker-based Ubuntu 22.04 desktop environment accessible via web browser through noVNC. It's designed for deployment to Render.com with high resource allocation (4GB-16GB RAM) for 24/7 availability.

## Architecture

- **Base OS**: Ubuntu 22.04 LTS
- **Desktop Environment**: XFCE4 (lightweight)
- **VNC Server**: TigerVNC
- **Web Interface**: noVNC (browser-based VNC client)
- **Process Manager**: Supervisord (manages VNC + noVNC processes)
- **Deployment**: Docker container via Render.com

## Key Components

1. **Dockerfile** - Defines the Ubuntu environment with all tools
2. **entrypoint.sh** - Sets up VNC password and initialization
3. **supervisord.conf** - Manages VNC server and noVNC processes
4. **docker-compose.yml** - For local testing with Docker
5. **render.yaml** - Render deployment configuration

## Pre-installed Tools

- GitHub CLI (gh)
- Git
- Node.js & npm
- Python 3
- Firefox browser
- Development tools (gcc, make, build-essential)
- Text editors (vim, nano)

## Deployment Target

**Render.com** - Cloud platform supporting Docker deployments
- Persistent storage for user files
- 24/7 uptime with paid plans
- Scalable resources (4GB to 16GB+ RAM)
- HTTPS by default for secure noVNC access

## Important Notes

- This project **cannot run in Replit** due to Docker requirement
- Built in Replit for version control and collaboration
- Deployed to Render for actual 24/7 operation
- VNC password should be changed from default
- Recommended minimum: 4GB RAM (Render Standard plan)

## Recent Changes

- 2025-11-18: Initial project setup with noVNC + Ubuntu + GitHub integration
- All Docker configuration files created
- Render deployment configuration added
- Comprehensive README with deployment instructions

## User Preferences

User requested:
- Ubuntu operating system
- Deployment to Render (not Replit deployment)
- High resource allocation ("huge resource")
- 24/7 availability
- GitHub integration
