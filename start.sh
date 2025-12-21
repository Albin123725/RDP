#!/bin/bash

# Set display
export DISPLAY=:99

# Create necessary directories
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
mkdir -p /var/run/dbus

# Start DBus
echo "Starting DBus..."
dbus-daemon --system --fork
sleep 2

# Start Xvfb
echo "Starting Xvfb..."
Xvfb :99 -screen 0 1360x768x24 -ac +extension GLX +render -noreset &
sleep 3

# Set up XFCE environment
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p $XDG_RUNTIME_DIR
chmod 0700 $XDG_RUNTIME_DIR

# Start XFCE properly with DBus
echo "Starting XFCE desktop..."
dbus-launch --exit-with-session startxfce4 &
sleep 5

# Start x11vnc
echo "Starting x11vnc..."
x11vnc -display :99 -forever -shared -nopw -listen 0.0.0.0 -xkb -bg -rfbport 5900 &
sleep 3

# Start noVNC
echo "Starting noVNC on port 8080..."
websockify --web=/usr/share/novnc 0.0.0.0:8080 localhost:5900 &

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
echo ""
echo "Debug info:"
echo "- Display: $DISPLAY"
echo "- x11vnc port: 5900"
echo "- noVNC port: 8080"
echo "- XFCE started with dbus-launch"
echo ""

# Keep running
wait
