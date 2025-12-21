#!/bin/bash

# Set environment variables
export USER=root
export HOME=/root
export DISPLAY=:99
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export CHROMIUM_FLAGS="--no-sandbox --disable-dev-shm-usage --disable-setuid-sandbox --disable-gpu"
export MOZ_DISABLE_CONTENT_SANDBOX=1
export MOZ_DISABLE_GMP_SANDBOX=1

# Fix Firefox sandbox issues
export MOZ_FAKE_NO_SANDBOX=1

# Create necessary directories
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
mkdir -p /var/run/dbus

# Start DBus
echo "Starting DBus..."
dbus-daemon --system --fork
sleep 2

# Start Xvfb (virtual framebuffer)
echo "Starting Xvfb on display :99..."
Xvfb :99 -screen 0 1360x768x24 -ac +extension GLX +render -noreset &
sleep 3

# Set X authority
export XAUTHORITY=/tmp/.Xauthority
touch /tmp/.Xauthority
xauth generate :99 . trusted

# Start XFCE desktop
echo "Starting XFCE desktop..."
startxfce4 &
sleep 5

# Start x11vnc (VNC server)
echo "Starting x11vnc on port 5900..."
x11vnc -display :99 -forever -shared -nopw -listen 0.0.0.0 -xkb -bg -rfbport 5900 &
sleep 3

# Start noVNC web interface
echo "Starting noVNC web interface on port 8900..."
websockify --web=/usr/share/novnc 0.0.0.0:8900 localhost:5900 &

# Display connection info
echo ""
echo "=========================================="
echo "   🚀 VNC Desktop is Ready!"
echo "=========================================="
echo ""
echo "🌐 Access URL:"
echo "   https://$(hostname):8900/vnc.html"
echo ""
echo "🖥️  Desktop includes:"
echo "   • Chromium Browser (double-click icon)"
echo "   • Firefox Browser (double-click icon)"
echo "   • Terminal"
echo "   • XFCE Desktop"
echo ""
echo "⚠️  Note: Chromium needs extra flags for Docker"
echo "=========================================="
echo ""

# Test if browsers work
echo "Testing browser environment..."
sleep 5
if command -v chromium &> /dev/null; then
    echo "Chromium is installed and should work"
fi
if command -v firefox-esr &> /dev/null; then
    echo "Firefox is installed and should work"
fi

echo ""
echo "Service is running. Connect via the URL above."

# Keep container running
tail -f /dev/null
