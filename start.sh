#!/bin/bash

# 1. Handle "Sandboxing" for Firefox in Root Environment
# Browsers typically crash in Docker as root unless this is set
export MOZ_FAKE_NO_SANDBOX=1

# 2. Cleanup function to remove old lock files if container restarted
rm -rf /tmp/.X* /tmp/.X11-unix /root/.vnc/*.pid

# 3. Start VNC Server
# We use Display :1 (Port 5901). Your original used :2000, which is non-standard but valid.
# Standard :1 is easier to debug.
echo "Starting VNC Server on :1..."
USER=root vncserver :1 -geometry 1360x768 -depth 24

# 4. Start noVNC (The Web Bridge)
# This connects the Web Port (8900) to the VNC Port (5901)
echo "Starting noVNC on port 8900..."
/opt/noVNC/utils/launch.sh --vnc localhost:5901 --listen 8900
