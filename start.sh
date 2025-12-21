#!/bin/bash

# Set environment
export USER=root
export HOME=/root
export DISPLAY=:99
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
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

# Start Xvfb (virtual framebuffer)
echo "Starting Xvfb on display :99..."
Xvfb :99 -screen 0 1360x768x24 -ac +extension GLX +render -noreset &
sleep 3

# Start x11vnc (VNC server)
echo "Starting x11vnc on port 5900..."
x11vnc -display :99 -forever -shared -nopw -listen 0.0.0.0 -xkb -bg &
sleep 2

# Start XFCE desktop
echo "Starting XFCE desktop..."
startxfce4 &
sleep 5

# Create desktop shortcuts
mkdir -p /root/Desktop

# Chromium shortcut
cat > /root/Desktop/chromium.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Name=Chromium Browser
Comment=Browse the web
Exec=chromium --no-sandbox --disable-dev-shm-usage --start-maximized
Icon=chromium
Terminal=false
Type=Application
Categories=Network;WebBrowser;
EOF

# Firefox shortcut
cat > /root/Desktop/firefox.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Name=Firefox Browser
Comment=Browse the web
Exec=firefox-esr
Icon=firefox-esr
Terminal=false
Type=Application
Categories=Network;WebBrowser;
EOF

# Terminal shortcut
cat > /root/Desktop/terminal.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Name=Terminal
Comment=Command line terminal
Exec=xfce4-terminal
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=System;TerminalEmulator;
EOF

chmod +x /root/Desktop/*.desktop

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
echo "📋 Alternative URL:"
echo "   https://$(hostname):8900"
echo ""
echo "🖥️  Desktop includes:"
echo "   • Chromium Browser"
echo "   • Firefox Browser" 
echo "   • Terminal"
echo "   • XFCE Desktop"
echo ""
echo "🔧 Server Status:"
echo "   Xvfb: display :99"
echo "   x11vnc: port 5900"
echo "   noVNC: port 8900"
echo "=========================================="
echo ""

# Keep container running
tail -f /dev/null
