FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Kolkata \
    USER=root \
    HOME=/root \
    VNC_PASSWD=password123 \
    VNC_RESOLUTION=800x600 \
    VNC_DEPTH=16

# Set timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install packages
RUN apt-get update && apt-get install -y \
    xfce4 \
    xfce4-goodies \
    tightvncserver \
    firefox \
    novnc \
    websockify \
    net-tools \
    wget \
    xterm \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Set VNC password
RUN mkdir -p ~/.vnc && \
    echo "$VNC_PASSWD" | vncpasswd -f > ~/.vnc/passwd && \
    chmod 600 ~/.vnc/passwd

# Create xstartup file
RUN echo '#!/bin/bash\nunset SESSION_MANAGER\nunset DBUS_SESSION_BUS_ADDRESS\nstartxfce4 &' > ~/.vnc/xstartup && \
    chmod +x ~/.vnc/xstartup

# Copy noVNC files to web directory
RUN mkdir -p /usr/share/novnc && \
    cp -r /usr/share/novnc/* /usr/share/novnc/ 2>/dev/null || true

# Create a simple index.html for noVNC
RUN echo '<html><head><meta http-equiv="refresh" content="0; url=/vnc.html" /></head></html>' > /usr/share/novnc/index.html

# Create startup script
RUN cat > /start.sh << 'EOF'
#!/bin/bash

echo "=== Starting VNC Desktop ==="
echo "Resolution: $VNC_RESOLUTION"
echo "Password: $VNC_PASSWD"

# Kill any existing VNC session
vncserver -kill :1 2>/dev/null || true
rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1

# Start VNC server
echo "Starting VNC server on :1..."
vncserver :1 \
  -geometry $VNC_RESOLUTION \
  -depth $VNC_DEPTH \
  -localhost no \
  -AlwaysShared \
  -AcceptKeyEvents \
  -AcceptPointerEvents \
  -AcceptSetDesktopSize \
  -SendCutText \
  -AcceptCutText \
  -rfbauth ~/.vnc/passwd

echo "VNC server started on port 5901"

# Wait for VNC to be ready
sleep 2

# Start noVNC websocket proxy
echo "Starting noVNC on port 8080..."
websockify --web /usr/share/novnc 8080 localhost:5900 &

# Alternative: Use python websockify if available
# python3 -m websockify --web /usr/share/novnc 8080 localhost:5900 &

echo "=========================================="
echo "VNC Desktop is ready!"
echo "Connect via: http://$(hostname -i):8080/vnc.html"
echo "Password: $VNC_PASSWD"
echo "=========================================="

# Keep container running
tail -f /dev/null
EOF

RUN chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
