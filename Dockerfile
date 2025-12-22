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
    && apt clean && \
    rm -rf /var/lib/apt/lists/*

# Setup VNC password (echo password twice for confirmation, then 'n' for view-only access)
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

EXPOSE 10000

# Start command
CMD echo "Starting VNC server..." && \
    vncserver :1 -geometry 1280x720 -depth 24 && \
    echo "VNC started successfully on display :1" && \
    /opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 && \
    tail -f /dev/null
