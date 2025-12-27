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

# Install packages
RUN apt update && apt install -y \
    tightvncserver \
    xserver-xorg-core \
    xinit \
    # Install novnc and websockify from apt
    novnc \
    websockify \
    wget \
    dbus-x11 \
    xfonts-base \
    openbox \
    chromium-browser \
    libnss3 \
    libasound2 \
    libgtk-3-0 \
    --no-install-recommends && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /usr/share/man/* /usr/share/locale/*

# Setup VNC password
RUN mkdir -p /root/.vnc && \
    echo "${VNC_PASSWD}" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create xstartup
RUN cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
xsetroot -solid grey
vncconfig -iconic &
openbox &
sleep 1
chromium-browser \
  --disable-dev-shm-usage \
  --no-sandbox \
  --disable-gpu \
  --max_old_space_size=256 \
  --window-size=800,600 \
  about:blank
EOF

RUN chmod +x /root/.vnc/xstartup

# Fix vncserver font path
RUN sed -i 's/\$fontPath = ".*"/\$fontPath = ""/' /usr/bin/vncserver && \
    touch /root/.Xauthority

# Create symbolic links for novnc (apt installs in different locations)
RUN ln -sf /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html && \
    ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/vnc_lite.html

# Browser optimization
RUN mkdir -p /etc/chromium-browser && \
    echo 'CHROMIUM_FLAGS="--disable-dev-shm-usage --no-sandbox --disable-gpu --max_old_space_size=256"' > /etc/chromium-browser/default

EXPOSE 6080  # novnc default port

# Startup script using apt-installed novnc
CMD echo "=== Starting Browser VNC ===" && \
    echo "Starting VNC server..." && \
    vncserver :1 -geometry ${VNC_RESOLUTION} -depth ${VNC_DEPTH} && \
    echo "VNC started on display :1" && \
    echo "Starting noVNC on port 6080..." && \
    # Start websockify proxy (novnc from apt)
    websockify --web /usr/share/novnc/ 6080 localhost:5901 && \
    echo "=== Ready ===" && \
    echo "Access: https://$(hostname).onrender.com" && \
    echo "Password: ${VNC_PASSWD}" && \
    tail -f /dev/null
