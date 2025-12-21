#!/bin/bash

# Set environment variables
export USER=root
export HOME=/root
export DISPLAY=:1
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
export CHROMIUM_FLAGS="--no-sandbox --disable-dev-shm-usage"
export MOZ_DISABLE_CONTENT_SANDBOX=1

# Create necessary directories
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
mkdir -p /var/run/dbus
mkdir -p /run/user/0

# Start DBus
echo "Starting DBus..."
dbus-daemon --system --fork
sleep 1

# Create Xauthority file
touch /root/.Xauthority
chmod 600 /root/.Xauthority

# Generate Xauthority for display :1
xauth add :1 . $(mcookie)

# Start VNC server on display :1
echo "Starting VNC server on display :1..."
vncserver :1 -geometry 1360x768 -depth 24 -localhost no -SecurityTypes VncAuth -fg &

# Wait for VNC to start
echo "Waiting for VNC server to start..."
sleep 3

# Check if VNC is running
if ! nc -z localhost 5901; then
    echo "ERROR: VNC server failed to start on port 5901"
    echo "Trying alternative method..."
    # Try starting Xvfb first
    Xvfb :1 -screen 0 1360x768x24 &
    sleep 2
    # Then start VNC
    vncserver :1 -geometry 1360x768 -depth 24 -localhost no -SecurityTypes VncAuth
fi

# Wait a bit more
sleep 2

# Start noVNC on all interfaces (required for Render)
echo "Starting noVNC web interface on port 8900..."
websockify --web=/usr/share/novnc 0.0.0.0:8900 localhost:5901 &

# Display connection info
echo ""
echo "=========================================="
echo "   VNC Desktop is Ready!"
echo "=========================================="
echo ""
echo "🌐 Access URL: https://$(hostname):8900/vnc.html"
echo ""
echo "🔑 VNC Password: Albin4242"
echo ""
echo "🖥️  Desktop includes:"
echo "   • Chromium Browser"
echo "   • Firefox Browser"
echo "   • XFCE Desktop (English/US)"
echo "=========================================="
echo ""
echo "Debug Info:"
echo "VNC Port: 5901"
echo "Web Interface: 8900"
echo "Display: $DISPLAY"
echo ""

# Keep container running
tail -f /dev/null
