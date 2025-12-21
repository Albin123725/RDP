#!/bin/bash

# Set environment
export DISPLAY=:99
export LANG=C.UTF-8
export CHROMIUM_FLAGS="--no-sandbox --disable-dev-shm-usage"
export MOZ_DISABLE_CONTENT_SANDBOX=1

# Create necessary directories
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

echo "=== Starting VNC Desktop ==="

# Method 1: Simple Xvfb + x11vnc + Firefox (most reliable)
echo "1. Starting Xvfb..."
Xvfb :99 -screen 0 1360x768x24 -ac +extension GLX +render -noreset &
sleep 3

echo "2. Starting x11vnc..."
x11vnc -display :99 -forever -shared -nopw -listen 0.0.0.0 -bg
sleep 2

echo "3. Starting XFCE..."
startxfce4 &
sleep 5

# Create desktop shortcuts
mkdir -p /root/Desktop

# Chromium shortcut
cat > /root/Desktop/chromium.desktop << EOF
[Desktop Entry]
Version=1.0
Name=Chromium Browser
Comment=Web Browser
Exec=chromium --no-sandbox --disable-dev-shm-usage
Icon=chromium
Terminal=false
Type=Application
EOF

# Firefox shortcut  
cat > /root/Desktop/firefox.desktop << EOF
[Desktop Entry]
Version=1.0
Name=Firefox Browser
Comment=Web Browser
Exec=firefox-esr
Icon=firefox-esr
Terminal=false
Type=Application
EOF

chmod +x /root/Desktop/*.desktop

echo "4. Starting noVNC web interface..."
# Start noVNC - THIS MUST BE THE LAST COMMAND (foreground process)
echo "=========================================="
echo "✅ VNC Desktop is READY!"
echo "=========================================="
echo ""
echo "🌐 Access URL:"
echo "   https://$(hostname):8080/vnc.html"
echo ""
echo "🔑 No password required"
echo ""
echo "🖥️  Features:"
echo "   • Firefox Browser"
echo "   • Chromium Browser"  
echo "   • XFCE Desktop"
echo "=========================================="
echo ""
echo "Starting noVNC on port 8080..."

# Start noVNC in foreground (important for Render)
websockify --web=/usr/share/novnc 0.0.0.0:8080 localhost:5900
