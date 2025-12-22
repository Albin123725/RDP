FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Kolkata \
    USER=root \
    HOME=/root \
    DISPLAY=:1

# Set timezone
RUN ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo "Asia/Kolkata" > /etc/timezone

# Install packages
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
    && apt clean && \
    rm -rf /var/lib/apt/lists/*

# Setup VNC password
RUN mkdir -p /root/.vnc && \
    printf "password123\npassword123\nn\n" | vncpasswd && \
    chmod 600 /root/.vnc/passwd

# Create xstartup
RUN echo '#!/bin/bash\n\
unset SESSION_MANAGER\n\
unset DBUS_SESSION_BUS_ADDRESS\n\
xsetroot -solid grey\n\
xterm -geometry 80x24+10+10 -ls -title "$VNCDESKTOP Desktop" &\n\
vncconfig -iconic &\n\
fluxbox &' > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# Get noVNC and create proper configuration
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt/ && \
    mv /opt/noVNC-1.4.0 /opt/novnc && \
    rm /tmp/novnc.tar.gz && \
    wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O /tmp/websockify.tar.gz && \
    tar -xzf /tmp/websockify.tar.gz -C /opt/novnc/utils/ && \
    mv /opt/novnc/utils/websockify-0.11.0 /opt/novnc/utils/websockify && \
    rm /tmp/websockify.tar.gz

# Create a simple index.html with correct VNC URL
RUN echo '<!DOCTYPE html>\n\
<html>\n\
<head>\n\
    <title>noVNC</title>\n\
    <meta charset="utf-8">\n\
</head>\n\
<body>\n\
    <div style="text-align: center; margin-top: 100px;">\n\
        <h2>VNC Desktop Access</h2>\n\
        <p>Click the button below to access your desktop:</p>\n\
        <a href="/vnc.html" style="padding: 10px 20px; background: #007bff; color: white; text-decoration: none; border-radius: 5px;">Launch VNC Viewer</a>\n\
        <br><br>\n\
        <p>Or use this direct link: <a href="/vnc.html">/vnc.html</a></p>\n\
    </div>\n\
</body>\n\
</html>' > /opt/novnc/index.html

EXPOSE 10000

# Start command
CMD echo "Starting VNC server..." && \
    vncserver :1 -geometry 1024x768 -depth 16 && \
    echo "VNC server started on display :1" && \
    echo "Starting noVNC proxy..." && \
    # Start websockify with proper parameters
    /opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 && \
    echo "noVNC ready. Connect via: https://$(hostname):10000/vnc.html" && \
    tail -f /dev/null
