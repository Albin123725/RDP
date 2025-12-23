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

# Install core packages - using x11vnc which is simpler
RUN apt update && apt install -y \
    xfce4 \
    xfce4-terminal \
    xfce4-panel \
    xfdesktop4 \
    thunar \
    firefox \
    x11vnc \
    xvfb \
    wget \
    net-tools \
    x11-xserver-utils \
    xfonts-base \
    xfonts-100dpi \
    xfonts-75dpi \
    --no-install-recommends && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Remove unnecessary packages
RUN apt purge -y \
    xfce4-screensaver \
    xfce4-power-manager \
    parole \
    ristretto \
    xfburn \
    2>/dev/null || true && \
    apt autoremove -y && \
    apt autoclean

# Install noVNC from source
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt/ && \
    mv /opt/noVNC-1.4.0 /opt/novnc && \
    rm /tmp/novnc.tar.gz && \
    wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O /tmp/websockify.tar.gz && \
    tar -xzf /tmp/websockify.tar.gz -C /opt/novnc/utils/ && \
    mv /opt/novnc/utils/websockify-0.11.0 /opt/novnc/utils/websockify && \
    rm /tmp/websockify.tar.gz

# Create VNC password file for x11vnc
RUN mkdir -p /root/.vnc && \
    x11vnc -storepasswd "$VNC_PASSWD" /root/.vnc/passwd 2>/dev/null || echo "$VNC_PASSWD" > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Configure Firefox for low memory
RUN mkdir -p /root/.mozilla/firefox/default && \
    cat > /root/.mozilla/firefox/default/prefs.js << 'EOF'
user_pref("app.update.auto", false);
user_pref("app.update.enabled", false);
user_pref("browser.startup.page", 0);
user_pref("dom.ipc.processCount", 1);
EOF

# Copy noVNC HTML files
RUN cp /opt/novnc/vnc_lite.html /opt/novnc/index.html

# Create startup script for x11vnc
RUN cat > /start.sh << 'EOF'
#!/bin/bash

# Set DISPLAY variable
export DISPLAY=:99

# Start Xvfb (virtual framebuffer)
echo "Starting Xvfb on display :99"
Xvfb :99 -screen 0 ${VNC_RESOLUTION}x${VNC_DEPTH} &
XVFB_PID=$!

# Wait for Xvfb to start
sleep 2

# Start Xfce
echo "Starting Xfce desktop"
export DISPLAY=:99
startxfce4 &
XFCE_PID=$!

# Wait for Xfce to start
sleep 3

# Start x11vnc
echo "Starting x11vnc server"
x11vnc -display :99 -forever -shared -rfbauth /root/.vnc/passwd -bg -rfbport 5901 -logfile /var/log/x11vnc.log &
X11VNC_PID=$!

# Start noVNC
echo "Starting noVNC on port 10000"
/opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 --web /opt/novnc &
NOVNC_PID=$!

# Check if services are running
if ps -p $XVFB_PID > /dev/null && ps -p $X11VNC_PID > /dev/null; then
    echo "=========================================="
    echo "VNC Desktop is ready!"
    echo "Access at: https://${RENDER_EXTERNAL_HOSTNAME:-localhost}/vnc_lite.html"
    echo "Password: $VNC_PASSWD"
    echo "=========================================="
else
    echo "ERROR: Some services failed to start"
    exit 1
fi

# Keep container running and monitor processes
while true; do
    if ! ps -p $XVFB_PID > /dev/null; then
        echo "Xvfb died, restarting..."
        Xvfb :99 -screen 0 ${VNC_RESOLUTION}x${VNC_DEPTH} &
        XVFB_PID=$!
        sleep 2
    fi
    if ! ps -p $X11VNC_PID > /dev/null; then
        echo "x11vnc died, restarting..."
        x11vnc -display :99 -forever -shared -rfbauth /root/.vnc/passwd -bg -rfbport 5901 &
        X11VNC_PID=$!
    fi
    sleep 10
done
EOF

RUN chmod +x /start.sh

EXPOSE 10000

CMD ["/start.sh"]
