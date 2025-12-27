FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Kolkata
ENV USER=root
ENV HOME=/root
ENV DISPLAY=:1
ENV VNC_PASSWD=password123
ENV VNC_RESOLUTION=800x600
ENV VNC_DEPTH=16

# Set timezone
RUN ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo "Asia/Kolkata" > /etc/timezone

# Install BARE minimum
RUN apt update && apt install -y \
    tightvncserver \
    xserver-xorg-core \
    xinit \
    novnc \
    websockify \
    wget \
    dbus-x11 \
    xfonts-base \
    openbox \
    chromium-browser \
    chromium-codecs-ffmpeg \
    libnss3 \
    libasound2 \
    libgtk-3-0 \
    --no-install-recommends && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /usr/share/man/*

# VNC setup
RUN mkdir -p /root/.vnc && \
    echo "${VNC_PASSWD}" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Simple xstartup - browser starts directly
RUN cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
xsetroot -solid grey
vncconfig -iconic &
openbox-session &

# Start browser directly
sleep 1
chromium-browser \
  --disable-dev-shm-usage \
  --no-sandbox \
  --disable-gpu \
  --window-size=800,600 \
  --start-fullscreen \
  https://colab.research.google.com/
EOF

RUN chmod +x /root/.vnc/xstartup

# Fix font path
RUN sed -i 's/\$fontPath = ".*"/\$fontPath = ""/' /usr/bin/vncserver && \
    touch /root/.Xauthority

# Get noVNC - FIXED: removed problematic rm command
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt/ && \
    mv /opt/noVNC-1.4.0 /opt/novnc && \
    rm /tmp/novnc.tar.gz && \
    wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O /tmp/websockify.tar.gz && \
    tar -xzf /tmp/websockify.tar.gz -C /opt/novnc/utils/ && \
    mv /opt/novnc/utils/websockify-0.11.0 /opt/novnc/utils/websockify && \
    rm /tmp/websockify.tar.gz

# Copy noVNC HTML
RUN cp /opt/novnc/vnc_lite.html /opt/novnc/index.html

# Add swap file
RUN fallocate -l 1G /swapfile && \
    chmod 600 /swapfile && \
    mkswap /swapfile

# Browser memory optimization
RUN mkdir -p /etc/chromium-browser && \
    echo 'CHROMIUM_FLAGS="--disable-dev-shm-usage --no-sandbox --disable-gpu --max_old_space_size=384"' > /etc/chromium-browser/default

EXPOSE 10000

# Startup script
CMD echo "=== Starting Browser-Only VNC ===" && \
    swapon /swapfile && \
    echo "Swap enabled (1GB)" && \
    vncserver :1 -geometry ${VNC_RESOLUTION} -depth ${VNC_DEPTH} && \
    echo "VNC started on :1" && \
    echo "Starting noVNC..." && \
    /opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 --heartbeat 30 --web /opt/novnc && \
    echo "=== Ready ===" && \
    echo "Access at: https://your-app.onrender.com/vnc_lite.html" && \
    echo "Password: ${VNC_PASSWD}" && \
    tail -f /dev/null
