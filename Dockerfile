FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Kolkata
ENV USER=root
ENV HOME=/root
ENV DISPLAY=:1
ENV VNC_PASSWD=password123
# Lower resolution to save memory
ENV VNC_RESOLUTION=800x600
ENV VNC_DEPTH=16

# Set timezone
RUN ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo "Asia/Kolkata" > /etc/timezone

# Install ONLY essentials - prioritize memory
RUN apt update && apt install -y \
    tightvncserver \
    xserver-xorg-core \
    xinit \
    novnc \
    websockify \
    wget \
    dbus-x11 \
    xfonts-base \
    # Openbox is very lightweight
    openbox \
    # Chromium for heavy sites
    chromium-browser \
    # Minimal dependencies
    libnss3 \
    libasound2 \
    libgtk-3-0 \
    --no-install-recommends && \
    # Clean up aggressively
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /usr/share/man/* /usr/share/locale/*

# Setup VNC password
RUN mkdir -p /root/.vnc && \
    echo "${VNC_PASSWD}" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create minimal xstartup
RUN cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
xsetroot -solid grey
vncconfig -iconic &
# Start Openbox in background
openbox &
# Start Chromium with memory optimizations
sleep 1
chromium-browser \
  --disable-dev-shm-usage \
  --no-sandbox \
  --disable-gpu \
  --disable-software-rasterizer \
  --max_old_space_size=256 \
  --window-size=800,600 \
  --start-fullscreen \
  about:blank
EOF

RUN chmod +x /root/.vnc/xstartup

# Fix vncserver font path
RUN sed -i 's/\$fontPath = ".*"/\$fontPath = ""/' /usr/bin/vncserver && \
    touch /root/.Xauthority

# Browser optimization config
RUN mkdir -p /etc/chromium-browser && \
    echo 'CHROMIUM_FLAGS="--disable-dev-shm-usage --no-sandbox --disable-gpu --max_old_space_size=256 --disable-software-rasterizer"' > /etc/chromium-browser/default

EXPOSE 10000

# Memory-optimized startup - NO SWAP on Render
CMD echo "=== Starting Browser VNC (Memory Optimized) ===" && \
    echo "Available memory: $(free -h)" && \
    # Start VNC server
    vncserver :1 -geometry ${VNC_RESOLUTION} -depth ${VNC_DEPTH} && \
    echo "VNC started on display :1" && \
    # Start noVNC proxy
    /opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 --heartbeat 30 --web /opt/novnc && \
    echo "noVNC proxy started on port 10000" && \
    echo "=== Ready ===" && \
    echo "Access: https://$(hostname).onrender.com/vnc_lite.html" && \
    echo "Password: ${VNC_PASSWD}" && \
    # Keep container running
    tail -f /dev/null
