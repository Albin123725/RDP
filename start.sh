#!/bin/bash

# Set display
export DISPLAY=:99

# Create necessary directories
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

# Start Xvfb
echo "Starting Xvfb..."
Xvfb :99 -screen 0 1360x768x24 -ac +extension GLX +render -noreset &
sleep 2

# Start XFCE
echo "Starting XFCE desktop..."
startxfce4 &
sleep 5

# Start x11vnc with proper options for noVNC
echo "Starting x11vnc..."
x11vnc -display :99 -forever -shared -nopw -listen 0.0.0.0 -xkb -bg -rfbport 5900 &
sleep 3

# Start noVNC with proper WebSocket path
echo "Starting noVNC on port 8080..."
websockify --web=/usr/share/novnc 8080 localhost:5900 &

echo ""
echo "=========================================="
echo "   ✅ VNC Desktop is Ready!"
echo "=========================================="
echo ""
echo "🌐 Access URL:"
echo "   https://YOUR-SERVICE.onrender.com/vnc.html"
echo ""
echo "🖥️  Desktop includes Firefox Browser"
echo "=========================================="

# Keep running
wait
