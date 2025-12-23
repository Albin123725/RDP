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

# Install noVNC from source
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt/ && \
    mv /opt/noVNC-1.4.0 /opt/novnc && \
    rm /tmp/novnc.tar.gz && \
    wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O /tmp/websockify.tar.gz && \
    tar -xzf /tmp/websockify.tar.gz -C /opt/novnc/utils/ && \
    mv /opt/novnc/utils/websockify-0.11.0 /opt/novnc/utils/websockify && \
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

# Create fluxbox menu with our apps
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

# Create startup script
RUN cat > /start.sh << 'EOF'
#!/bin/bash

# Kill any existing processes on port 5901 and 10000
fuser -k 5901/tcp 2>/dev/null || true
fuser -k 10000/tcp 2>/dev/null || true

# Set DISPLAY variable
export DISPLAY=:99

# Start Xvfb (virtual framebuffer)
echo "Starting Xvfb on display :99"
Xvfb :99 -screen 0 ${VNC_RESOLUTION}x${VNC_DEPTH} &
XVFB_PID=$!

# Wait for Xvfb to start
sleep 3

# Start fluxbox (lightweight window manager)
echo "Starting Fluxbox"
startfluxbox &
FLUXBOX_PID=$!

# Start applications
echo "Starting applications"
sleep 2
xterm -geometry 80x24+10+10 &
sleep 1
thunar &
sleep 1
firefox &

# Start x11vnc
echo "Starting x11vnc server on port 5901"
x11vnc -display :99 -forever -shared -rfbauth /root/.vnc/passwd -bg -rfbport 5901 -noxdamage -nowf -noscr -cursor arrow

# Start noVNC with explicit Python 3
echo "Starting noVNC on port 10000"
cd /opt/novnc/utils/websockify
python3 run --vnc localhost:5901 --listen 0.0.0.0:10000 --web /opt/novnc &
NOVNC_PID=$!

# Wait for noVNC to start
sleep 3

echo "=========================================="
echo "VNC Desktop is ready!"
echo "Access at: https://${RENDER_EXTERNAL_HOSTNAME:-localhost}/vnc_lite.html"
echo "Password: $VNC_PASSWD"
echo "=========================================="

# Keep container running and monitor processes
while true; do
    # Check if noVNC is running
    if ! ps -p $NOVNC_PID > /dev/null 2>&1; then
        echo "noVNC died, restarting..."
        cd /opt/novnc/utils/websockify
        python3 run --vnc localhost:5901 --listen 0.0.0.0:10000 --web /opt/novnc &
        NOVNC_PID=$!
    fi
    
    # Check if x11vnc is running
    if ! pgrep -x "x11vnc" > /dev/null; then
        echo "x11vnc died, restarting..."
        x11vnc -display :99 -forever -shared -rfbauth /root/.vnc/passwd -bg -rfbport 5901 -noxdamage -nowf -noscr -cursor arrow
    fi
    
    sleep 10
done
EOF

RUN chmod +x /start.sh

EXPOSE 10000

CMD ["/start.sh"]
