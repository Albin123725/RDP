FROM ubuntu:22.04

# Set environment variables (ADDED PORT variable)
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Kolkata \
    USER=root \
    HOME=/root \
    DISPLAY=:1 \
    PORT=10000  # ADDED: For Render port binding

# Set timezone
RUN ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo "Asia/Kolkata" > /etc/timezone

# Install packages (ADDED net-tools for debugging)
RUN apt update && apt install -y \
    xfce4 \
    xfce4-goodies \
    tightvncserver \
    novnc \
    websockify \
    wget \
    sudo \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    net-tools \  # ADDED: For network troubleshooting
    && apt clean && \
    rm -rf /var/lib/apt/lists/*

# Setup VNC password
RUN mkdir -p /root/.vnc && \
    printf "password123\npassword123\nn\n" | vncpasswd && \
    chmod 600 /root/.vnc/passwd

# Create xstartup with proper configuration
RUN echo '#!/bin/bash\n\
unset SESSION_MANAGER\n\
unset DBUS_SESSION_BUS_ADDRESS\n\
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup\n\
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources\n\
xsetroot -solid grey\n\
vncconfig -iconic &\n\
startxfce4 &' > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# Get noVNC
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt/ && \
    mv /opt/noVNC-1.4.0 /opt/novnc && \
    rm /tmp/novnc.tar.gz && \
    wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O /tmp/websockify.tar.gz && \
    tar -xzf /tmp/websockify.tar.gz -C /opt/novnc/utils/ && \
    mv /opt/novnc/utils/websockify-0.11.0 /opt/novnc/utils/websockify && \
    rm /tmp/websockify.tar.gz

# ADDED: Create startup script to fix process management
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "============================================="\n\
echo "Starting VNC Desktop with XFCE4"\n\
echo "Using port: ${PORT:-10000}"\n\
echo "============================================="\n\
\n\
# Start VNC server\n\
echo "1. Starting VNC server on display :1..."\n\
vncserver :1 -geometry 1280x720 -depth 24\n\
echo "✓ VNC server started on :1 (port 5901)"\n\
\n\
# Start noVNC proxy (using Render PORT variable)\n\
echo "2. Starting noVNC proxy on port ${PORT:-10000}..."\n\
/opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:${PORT:-10000} &\n\
NOVNC_PID=$!\n\
\n\
echo "3. Verifying port binding..."\n\
sleep 2\n\
netstat -tulpn | grep ${PORT:-10000} || echo "Warning: Port not detected yet"\n\
\n\
echo "============================================="\n\
echo "✅ Service is ready!"\n\
echo "Access URL: https://YOUR_SERVICE.onrender.com/vnc.html"\n\
echo "VNC Password: password123"\n\
echo "============================================="\n\
\n\
# Keep container alive\n\
wait $NOVNC_PID\n\
' > /root/start.sh && chmod +x /root/start.sh

EXPOSE 10000

# REPLACED: Use the startup script instead of inline CMD
CMD ["/root/start.sh"]
