FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    VNC_PASSWD=password123 \
    VNC_RESOLUTION=1024x768 \
    DISPLAY=:1 \
    LANG=en_US.UTF-8

# Install minimal desktop environment and TigerVNC (more reliable than TightVNC)
RUN apt-get update && apt-get install -y \
    tigervnc-standalone-server \
    tigervnc-common \
    xfce4 \
    xfce4-goodies \
    firefox \
    xterm \
    wget \
    supervisor \
    net-tools \
    locales \
    && rm -rf /var/lib/apt/lists/*

# Generate locale
RUN locale-gen en_US.UTF-8

# Create .vnc directory and set password
RUN mkdir -p /root/.vnc && \
    echo "$VNC_PASSWD" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create xstartup for XFCE
RUN echo '#!/bin/bash\nunset SESSION_MANAGER\nunset DBUS_SESSION_BUS_ADDRESS\nexec startxfce4' > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# Download and install noVNC
RUN wget -qO- https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz | tar xz -C /tmp && \
    mv /tmp/noVNC-1.4.0 /opt/novnc

RUN wget -qO- https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz | tar xz -C /tmp && \
    mv /tmp/websockify-0.11.0 /opt/novnc/utils/websockify

# Create a simple index page
RUN cp /opt/novnc/vnc_lite.html /opt/novnc/index.html

# Create Firefox desktop shortcut
RUN mkdir -p /root/Desktop && \
    echo '[Desktop Entry]\nType=Application\nName=Firefox\nExec=firefox --no-sandbox\nIcon=firefox\nTerminal=false' > /root/Desktop/firefox.desktop && \
    chmod +x /root/Desktop/firefox.desktop

# Create terminal desktop shortcut
RUN echo '[Desktop Entry]\nType=Application\nName=Terminal\nExec=xfce4-terminal\nIcon=utilities-terminal\nTerminal=false' > /root/Desktop/terminal.desktop && \
    chmod +x /root/Desktop/terminal.desktop

# Create startup script
RUN cat > /start.sh << 'EOF'
#!/bin/bash
set -e

echo "=== Starting VNC Desktop ==="
echo "VNC Password: $VNC_PASSWD"
echo "Resolution: $VNC_RESOLUTION"

# Clean up old X server locks
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

# Start TigerVNC server
echo "Starting VNC server..."
vncserver :1 \
    -geometry $VNC_RESOLUTION \
    -depth 24 \
    -localhost no \
    -SecurityTypes VncAuth \
    -fg \
    -xstartup /root/.vnc/xstartup &

# Wait for VNC server to start
sleep 3

# Start noVNC WebSocket proxy
echo "Starting noVNC websocket proxy on port 8080..."
/opt/novnc/utils/novnc_proxy \
    --vnc localhost:5901 \
    --listen 0.0.0.0:8080 \
    --heartbeat 30 \
    --web /opt/novnc &

echo "========================================="
echo "VNC Server is running!"
echo "Connect via: http://localhost:8080/vnc.html"
echo "VNC Password: $VNC_PASSWD"
echo "========================================="

# Keep container running
tail -f /dev/null
EOF

RUN chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
