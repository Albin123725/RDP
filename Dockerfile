FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Kolkata
ENV USER=root
ENV HOME=/root
ENV DISPLAY=:1
ENV VNC_PASSWD=password123
ENV VNC_RESOLUTION=1024x576
ENV VNC_DEPTH=16

# Set timezone
RUN ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo "Asia/Kolkata" > /etc/timezone

# Install packages
RUN apt update && apt install -y \
    fluxbox \
    xterm \
    thunar \
    firefox \
    x11vnc \
    xvfb \
    wget \
    net-tools \
    x11-xserver-utils \
    xfonts-base \
    python3 \
    python3-numpy \
    dbus-x11 \
    --no-install-recommends && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install noVNC
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt/ && \
    mv /opt/noVNC-1.4.0 /opt/novnc && \
    rm /tmp/novnc.tar.gz

# Install websockify
RUN wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O /tmp/websockify.tar.gz && \
    tar -xzf /tmp/websockify.tar.gz -C /opt/ && \
    mv /opt/websockify-0.11.0 /opt/websockify && \
    rm /tmp/websockify.tar.gz

# Create VNC password file
RUN mkdir -p /root/.vnc && \
    echo "$VNC_PASSWD" > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Configure Firefox
RUN mkdir -p /root/.mozilla/firefox/default && \
    cat > /root/.mozilla/firefox/default/prefs.js << 'EOF'
user_pref("app.update.auto", false);
user_pref("app.update.enabled", false);
user_pref("browser.startup.page", 0);
user_pref("dom.ipc.processCount", 1);
EOF

# Create fluxbox menu
RUN mkdir -p /root/.fluxbox && \
    cat > /root/.fluxbox/menu << 'EOF'
[begin] (Applications)
  [exec] (Terminal) {xterm}
  [exec] (File Manager) {thunar}
  [exec] (Firefox) {firefox}
  [separator]
  [exit] (Exit)
[end]
EOF

# Create simple fluxbox startup file
RUN cat > /root/.fluxbox/startup << 'EOF'
#!/bin/sh
# fluxbox startup script

# Start applications
xterm -geometry 80x24+10+10 &
thunar &
firefox &
EOF

RUN chmod +x /root/.fluxbox/startup

# Copy noVNC HTML files
RUN cp /opt/novnc/vnc_lite.html /opt/novnc/index.html

# Create Python script for noVNC with IP address instead of localhost
RUN cat > /opt/novnc/start-novnc.py << 'EOF'
#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, '/opt/websockify')
from websockify.websocketproxy import WebSocketProxy

if __name__ == '__main__':
    # Use 127.0.0.1 instead of localhost to avoid DNS resolution issues
    sys.argv = ['websockify', '--web', '/opt/novnc', '0.0.0.0:10000', '127.0.0.1:5901']
    WebSocketProxy().start_server()
EOF

RUN chmod +x /opt/novnc/start-novnc.py

# Create startup script with better error handling
RUN cat > /start.sh << 'EOF'
#!/bin/bash

# Clean up
rm -rf /tmp/.X11-unix/X99 /tmp/.X99-lock 2>/dev/null || true

# Set DISPLAY
export DISPLAY=:99

# Start Xvfb
echo "Starting Xvfb on display :99"
Xvfb :99 -screen 0 ${VNC_RESOLUTION}x${VNC_DEPTH} &
XVFB_PID=$!

# Wait for Xvfb
sleep 3

# Verify Xvfb is running
if ! ps -p $XVFB_PID > /dev/null; then
    echo "ERROR: Xvfb failed to start"
    exit 1
fi

# Start fluxbox
echo "Starting Fluxbox"
fluxbox &
FLUXBOX_PID=$!

sleep 2

# Start x11vnc
echo "Starting x11vnc on port 5901"
x11vnc -display :99 -forever -shared -rfbauth /root/.vnc/passwd -bg -rfbport 5901 -noxdamage -nowf -noscr -cursor arrow

sleep 2

# Check if x11vnc is running
if ! pgrep -x "x11vnc" > /dev/null; then
    echo "ERROR: x11vnc failed to start"
    exit 1
fi

# Start noVNC
echo "Starting noVNC on port 10000"
cd /opt/novnc
python3 start-novnc.py &
NOVNC_PID=$!

sleep 3

# Check if noVNC is running
if ! ps -p $NOVNC_PID > /dev/null 2>&1; then
    echo "WARNING: noVNC may have issues, trying alternative method..."
    # Try running websockify directly
    cd /opt/websockify
    python3 -m websockify.websocketproxy --web /opt/novnc 0.0.0.0:10000 127.0.0.1:5901 &
    NOVNC_PID=$!
    sleep 2
fi

echo "=========================================="
echo "VNC Desktop is ready!"
echo "Access at: https://${RENDER_EXTERNAL_HOSTNAME:-localhost}/vnc_lite.html"
echo "or: https://${RENDER_EXTERNAL_HOSTNAME:-localhost}/"
echo "Password: $VNC_PASSWD"
echo "=========================================="

# Test if port 10000 is listening
if netstat -tuln | grep -q ":10000"; then
    echo "noVNC is listening on port 10000"
else
    echo "WARNING: Port 10000 is not listening"
fi

# Keep running
tail -f /dev/null
EOF

RUN chmod +x /start.sh

EXPOSE 10000

CMD ["/start.sh"]
