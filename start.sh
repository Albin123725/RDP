#!/bin/bash

# Set environment
export USER=root
export HOME=/root
export DISPLAY=:99
export LANG=en_US.UTF-8
export CHROMIUM_FLAGS="--no-sandbox --disable-dev-shm-usage"
export MOZ_DISABLE_CONTENT_SANDBOX=1

# Create necessary directories
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
mkdir -p /var/run/dbus

# Start DBus
echo "Starting DBus..."
dbus-daemon --system --fork
sleep 2

# Method 1: Start Xvfb + x11vnc (most reliable)
echo "Starting Xvfb on display :99..."
Xvfb :99 -screen 0 1360x768x24 -ac +extension GLX +render -noreset &
export DISPLAY=:99
sleep 2

echo "Starting x11vnc on port 5900..."
x11vnc -display :99 -forever -shared -nopw -listen 0.0.0.0 -xkb &
sleep 2

# Start XFCE desktop
echo "Starting XFCE desktop..."
startxfce4 &
sleep 3

# Create desktop shortcuts
mkdir -p /root/Desktop
cat > /root/Desktop/chromium.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Name=Chromium Browser
Comment=Access the Internet
Exec=chromium --no-sandbox --disable-dev-shm-usage --start-maximized
Icon=chromium
Terminal=false
Type=Application
Categories=Network;WebBrowser;
EOF

chmod +x /root/Desktop/chromium.desktop

# Start noVNC on port 8900
echo "Starting noVNC web interface on port 8900..."
websockify --web=/usr/share/novnc 0.0.0.0:8900 localhost:5900 &

# Display connection info
echo ""
echo "=========================================="
echo "   VNC Desktop is Ready!"
echo "=========================================="
echo ""
echo "🌐 Access URL: https://$(hostname):8900/vnc.html"
echo "   Or use: https://$(hostname):8900"
echo ""
echo "🔑 No password required for this setup"
echo ""
echo "🖥️  Desktop includes:"
echo "   • Chromium Browser (double-click on desktop)"
echo "   • Firefox Browser"
echo "   • XFCE Desktop"
echo "=========================================="
echo ""
echo "Server Status:"
echo "Xvfb: :99"
echo "x11vnc: port 5900"
echo "noVNC: port 8900"
echo ""

# Keep container running
tail -f /dev/null
