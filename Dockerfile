FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FONTEND=noninteractive \
    TZ=Asia/Kolkata \
    USER=root \
    HOME=/root \
    DISPLAY=:1 \
    PORT=10000

# Set timezone
RUN ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo "Asia/Kolkata" > /etc/timezone

# Install minimal packages (using fluxbox instead of xfce4 for lower memory usage)
RUN apt update && apt install -y \
    fluxbox \
    tightvncserver \
    novnc \
    websockify \
    wget \
    sudo \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    xterm \
    net-tools \
    && apt clean && \
    rm -rf /var/lib/apt/lists/*

# Setup VNC password
RUN mkdir -p /root/.vnc && \
    printf "password123\npassword123\nn\n" | vncpasswd && \
    chmod 600 /root/.vnc/passwd

# Create xstartup with fluxbox (lighter than xfce4)
RUN echo '#!/bin/bash\n\
unset SESSION_MANAGER\n\
unset DBUS_SESSION_BUS_ADDRESS\n\
xsetroot -solid grey\n\
xterm -geometry 80x24+10+10 -ls -title "$VNCDESKTOP Desktop" &\n\
vncconfig -iconic &\n\
fluxbox &' > /root/.vnc/xstartup && \
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

# Create a simple index.html for easier access
RUN echo '<!DOCTYPE html>\n\
<html>\n\
<head>\n\
    <title>noVNC Desktop</title>\n\
    <meta charset="utf-8">\n\
    <style>\n\
        body { font-family: Arial, sans-serif; margin: 50px; text-align: center; }\n\
        .container { max-width: 600px; margin: 0 auto; padding: 30px; border: 1px solid #ddd; border-radius: 10px; }\n\
        .btn { display: inline-block; padding: 15px 30px; background: #007bff; color: white; text-decoration: none; border-radius: 5px; font-size: 18px; margin: 20px 0; }\n\
        .btn:hover { background: #0056b3; }\n\
        .info { background: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0; }\n\
    </style>\n\
</head>\n\
<body>\n\
    <div class="container">\n\
        <h2>Remote Desktop Access</h2>\n\
        <p>Click the button below to access your desktop environment.</p>\n\
        <a href="/vnc.html" class="btn">Launch VNC Viewer</a>\n\
        <div class="info">\n\
            <p><strong>Default password:</strong> password123</p>\n\
            <p>If connection fails, wait 30 seconds and refresh this page.</p>\n\
        </div>\n\
        <p>Direct link: <a href="/vnc.html">/vnc.html</a></p>\n\
    </div>\n\
</body>\n\
</html>' > /opt/novnc/index.html

EXPOSE 10000

# Create startup script that properly handles port binding and process management
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "=== Starting VNC Desktop Service ==="\n\
echo "Using port: ${PORT:-10000}"\n\
\n\
# Start VNC server\n\
echo "Starting VNC server on display :1..."\n\
vncserver :1 -geometry 1024x768 -depth 16\n\
echo "VNC server started successfully"\n\
\n\
# Start noVNC proxy\n\
echo "Starting noVNC proxy on port ${PORT:-10000}..."\n\
/opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:${PORT:-10000} &\n\
NOVNC_PID=$!\n\
\n\
echo "============================================="\n\
echo "Service is ready!"\n\
echo "Access your desktop at: http://$(hostname -i):${PORT:-10000}/vnc.html"\n\
echo "Default VNC password: password123"\n\
echo "============================================="\n\
\n\
# Monitor the noVNC process\n\
wait $NOVNC_PID\n\
' > /root/startup.sh && chmod +x /root/startup.sh

# Start command
CMD ["/root/startup.sh"]
