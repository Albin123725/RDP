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

# Install core packages
RUN apt update && apt install -y \
    xfce4 \
    xfce4-terminal \
    xfce4-panel \
    xfdesktop4 \
    thunar \
    firefox \
    tightvncserver \
    wget \
    net-tools \
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

# Setup VNC - create passwd file first
RUN mkdir -p /root/.vnc && \
    echo "$VNC_PASSWD" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create proper xstartup for Xfce
RUN cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
xsetroot -solid grey
vncconfig -iconic &
startxfce4 &
EOF

RUN chmod +x /root/.vnc/xstartup

# Create a simple .Xresources file
RUN echo "Xft.dpi: 96" > /root/.Xresources

# Fix the font path issue in vncserver
RUN sed -i 's|^.*\$fontPath.*=.*|$fontPath = "";|' /usr/bin/vncserver

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

# Create startup script
RUN cat > /start.sh << 'EOF'
#!/bin/bash

# Kill any existing VNC server
vncserver -kill :1 2>/dev/null || true
rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

# Generate .Xauthority file
touch /root/.Xauthority
xauth generate :1 . trusted 2>/dev/null || true

# Start VNC server with correct options
echo "Starting VNC server with resolution: ${VNC_RESOLUTION}"
# First run to create config
vncserver :1 -geometry ${VNC_RESOLUTION} -depth ${VNC_DEPTH} 2>&1 | tee /tmp/vnc-start.log

# Kill and restart with proper settings
vncserver -kill :1 2>/dev/null || true
sleep 2

# Start final VNC server
vncserver :1 -geometry ${VNC_RESOLUTION} -depth ${VNC_DEPTH} -localhost no 2>&1 | tee /tmp/vnc-final.log

# Check if VNC is running
if netstat -tuln | grep -q ":5901"; then
    echo "VNC server is running on port 5901"
else
    echo "ERROR: VNC server failed to start"
    cat /tmp/vnc-start.log
    cat /tmp/vnc-final.log
    exit 1
fi

# Start noVNC
echo "Starting noVNC on port 10000"
/opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 --web /opt/novnc &

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
