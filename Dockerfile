FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV VNC_PASSWD=password123
ENV VNC_RESOLUTION=800x600
ENV VNC_DEPTH=16

# Install packages
RUN apt update && apt install -y \
    tightvncserver \
    xserver-xorg-core \
    xinit \
    wget \
    python3 \
    python3-numpy \
    dbus-x11 \
    xfonts-base \
    openbox \
    chromium-browser \
    libnss3 \
    libasound2 \
    libgtk-3-0 \
    --no-install-recommends && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Setup VNC
RUN mkdir -p /root/.vnc && \
    echo "${VNC_PASSWD}" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create xstartup file
RUN echo '#!/bin/bash' > /root/.vnc/xstartup && \
    echo 'unset SESSION_MANAGER' >> /root/.vnc/xstartup && \
    echo 'unset DBUS_SESSION_BUS_ADDRESS' >> /root/.vnc/xstartup && \
    echo 'xsetroot -solid grey' >> /root/.vnc/xstartup && \
    echo 'vncconfig -iconic &' >> /root/.vnc/xstartup && \
    echo 'openbox &' >> /root/.vnc/xstartup && \
    echo 'sleep 2' >> /root/.vnc/xstartup && \
    echo 'chromium-browser --disable-dev-shm-usage --no-sandbox --disable-gpu --window-size=800,600 about:blank' >> /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# Fix vncserver font path
RUN sed -i 's/\$fontPath = ".*"/\$fontPath = ""/' /usr/bin/vncserver

# Install noVNC manually
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt/ && \
    mv /opt/noVNC-1.4.0 /opt/novnc && \
    rm /tmp/novnc.tar.gz && \
    wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O /tmp/websockify.tar.gz && \
    tar -xzf /tmp/websockify.tar.gz -C /opt/novnc/utils/ && \
    mv /opt/novnc/utils/websockify-0.11.0 /opt/novnc/utils/websockify && \
    rm /tmp/websockify.tar.gz

# Create index.html for health check
RUN cp /opt/novnc/vnc_lite.html /opt/novnc/index.html

EXPOSE 8080

# Startup script
CMD echo "=== Starting VNC Desktop ===" && \
    vncserver :1 -geometry ${VNC_RESOLUTION} -depth ${VNC_DEPTH} && \
    echo "VNC server started on :1" && \
    echo "Starting noVNC on port 8080..." && \
    /opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:8080 --web /opt/novnc && \
    echo "=== Ready ===" && \
    tail -f /dev/null
