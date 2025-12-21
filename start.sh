#!/bin/bash

# Set environment for browsers
export DISPLAY=:1
export CHROMIUM_FLAGS="--no-sandbox --disable-dev-shm-usage"
export MOZ_DISABLE_CONTENT_SANDBOX=1

# Prepare directories
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
mkdir -p /var/run/dbus

# Start DBus
dbus-daemon --system --fork

# Start VNC server
echo "Starting VNC server..."
vncserver :1 -geometry 1360x768 -depth 24 -localhost no

# Wait a moment
sleep 2

# Start noVNC on all interfaces (required for Render)
echo "Starting noVNC web interface..."
websockify --web=/usr/share/novnc 0.0.0.0:8900 localhost:5901 &

# Display connection info
echo "=========================================="
echo "   VNC Desktop is Ready!"
echo "=========================================="
echo ""
echo "🌐 Access URL: https://[YOUR-RENDER-URL]"
echo ""
echo "🔑 VNC Password: Albin4242"
echo ""
echo "🖥️  Desktop includes:"
echo "   • Chromium Browser"
echo "   • Firefox Browser"
echo "   • XFCE Desktop"
echo "=========================================="

# Keep container running
tail -f /dev/null
