FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    VNC_PASSWD=password123 \
    VNC_RESOLUTION=800x600 \
    DISPLAY=:1

# Install minimal packages
RUN apt-get update && apt-get install -y \
    tigervnc-standalone-server \
    fluxbox \
    xterm \
    wget \
    net-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Setup VNC with password
RUN mkdir -p /root/.vnc && \
    echo "$VNC_PASSWD" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create minimal xstartup for Fluxbox
RUN echo '#!/bin/bash' > /root/.vnc/xstartup && \
    echo 'fluxbox &' >> /root/.vnc/xstartup && \
    echo 'xterm -geometry 80x24+10+10 -ls &' >> /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# Download noVNC
RUN wget -qO- https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz | tar xz -C /opt && \
    mv /opt/noVNC-1.4.0 /opt/novnc

RUN wget -qO- https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz | tar xz -C /opt/novnc/utils && \
    mv /opt/novnc/utils/websockify-0.11.0 /opt/novnc/utils/websockify

EXPOSE 8080

# FIXED: Added --I-KNOW-THIS-IS-INSECURE flag
CMD vncserver :1 \
    -geometry $VNC_RESOLUTION \
    -depth 16 \
    -localhost no \
    -SecurityTypes VncAuth \
    -I-KNOW-THIS-IS-INSECURE \
    -xstartup /root/.vnc/xstartup && \
    echo "VNC server started on :1" && \
    echo "Starting noVNC on port 8080..." && \
    /opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:8080 --web /opt/novnc && \
    tail -f /dev/null
