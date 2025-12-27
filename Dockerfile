FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV USER=root
ENV HOME=/root
ENV VNC_PASSWD=password123
ENV VNC_RESOLUTION=800x600
ENV VNC_DEPTH=16

# Install packages with proper fonts
RUN apt update && apt install -y \
    tightvncserver \
    xserver-xorg-core \
    xinit \
    novnc \
    websockify \
    openbox \
    chromium-browser \
    libnss3 \
    libasound2 \
    libgtk-3-0 \
    # Install X11 fonts
    xfonts-base \
    xfonts-100dpi \
    xfonts-75dpi \
    xfonts-cyrillic \
    xfonts-scalable \
    fonts-liberation \
    fonts-noto \
    fonts-noto-cjk \
    --no-install-recommends && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

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
sleep 2
chromium-browser --no-sandbox --disable-dev-shm-usage --window-size=800,600 about:blank
EOF

RUN chmod +x /root/.vnc/xstartup

# Create font directories that vncserver expects
RUN mkdir -p /usr/share/fonts/X11/misc && \
    mkdir -p /usr/share/fonts/X11/75dpi && \
    mkdir -p /usr/share/fonts/X11/100dpi && \
    # Update font cache
    fc-cache -fv

# Alternative: Fix vncserver to not require specific font paths
RUN sed -i "s|if (.*fontPath.*)|if (0)|" /usr/bin/vncserver && \
    sed -i "s|\$fontPath = \".*\"|\$fontPath = \"\"|" /usr/bin/vncserver

EXPOSE 6080

# Startup script with font debugging
CMD echo "=== Starting VNC Desktop ===" && \
    echo "Checking fonts..." && \
    ls -la /usr/share/fonts/X11/ && \
    echo "Starting VNC server..." && \
    vncserver :1 -geometry ${VNC_RESOLUTION} -depth ${VNC_DEPTH} && \
    echo "VNC server started on :1" && \
    echo "Starting noVNC..." && \
    websockify --web /usr/share/novnc/ 6080 localhost:5901 && \
    echo "=== Ready ===" && \
    tail -f /dev/null
