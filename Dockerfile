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

# Install minimal packages
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

# Install noVNC properly - using the websockify package
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt/ && \
    mv /opt/noVNC-1.4.0 /opt/novnc && \
    rm /tmp/novnc.tar.gz

# Install websockify separately
RUN wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O /tmp/websockify.tar.gz && \
    tar -xzf /tmp/websockify.tar.gz -C /opt/ && \
    mv /opt/websockify-0.11.0 /opt/websockify && \
    rm /tmp/websockify.tar.gz

# Create VNC password file
RUN mkdir -p /root/.vnc && \
    echo "$VNC_PASSWD" > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Configure Firefox for low memory
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

# Copy noVNC HTML files
RUN cp /opt/novnc/vnc_lite.html /opt/novnc/index.html

# Create a simple Python script to run websockify
RUN cat > /opt/novnc/start-novnc.py << 'EOF'
#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, '/opt/websockify')
from websockify.websocketproxy import WebSocketProxy

if __name__ == '__main__':
    sys.argv = ['websockify', '--web', '/opt/novnc', '0.0.0.0:10000', 'localhost:5901']
    WebSocketProxy().start_server()
EOF

RUN chmod +x /opt/novnc/start-novnc.py

# Create startup script
RUN cat > /start.sh << 'EOF'
#!/bin/bash

# Kill any existing processes
pkill -f "x11vnc" 2>/dev/null || true
pkill -f "Xvfb" 2>/dev/null || true
pkill -f "websockify" 2>/dev/null || true
pkill -f "fluxbox" 2>/dev/null || true
pkill -f "start-novnc" 2>/dev/null || true

# Set DISPLAY variable
export DISPLAY=:99

# Start Xvfb
echo "Starting Xvfb on display :99"
Xvfb :99 -screen 0 ${VNC_RESOLUTION}x${VNC_DEPTH} &

# Wait for Xvfb to start
sleep 3

# Start fluxbox
echo "Starting Fluxbox"
fluxbox &

# Start applications
echo "Starting applications"
sleep 2
xterm -geometry 80x24+10+10 &
thunar &
firefox &

# Start x11vnc
echo "Starting x11vnc server on port 5901"
x11vnc -display :99 -forever -shared -rfbauth /root/.vnc/passwd -bg -rfbport 5901 -noxdamage -nowf -noscr -cursor arrow

# Start noVNC using our Python script
echo "Starting noVNC on port 10000"
cd /opt/novnc
python3 start-novnc.py &

# Wait a bit
sleep 3

echo "=========================================="
echo "VNC Desktop is ready!"
echo "Access at: https://${RENDER_EXTERNAL_HOSTNAME:-localhost}/vnc_lite.html"
echo "Password: $VNC_PASSWD"
echo "=========================================="

# Keep container running
tail -f /dev/null
EOF

RUN chmod +x /start.sh

EXPOSE 10000

CMD ["/start.sh"]
