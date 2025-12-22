FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Kolkata
ENV USER=root
ENV HOME=/root
ENV DISPLAY=:1
ENV VNC_PASSWD=password123
ENV VNC_RESOLUTION=1024x576
ENV VNC_DEPTH=16

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
    xfonts-base \
    xfonts-100dpi \
    xfonts-75dpi \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Setup VNC
RUN mkdir -p /root/.vnc && \
    printf "${VNC_PASSWD}\n${VNC_PASSWD}\nn\n" | vncpasswd && \
    chmod 600 /root/.vnc/passwd

# Create xstartup with clipboard support
RUN cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
xsetroot -solid grey
# Start vncconfig for VNC clipboard
vncconfig -nowin &
# Disable composite manager
xfwm4 --compositor=off &
xfsettingsd --daemon
xfce4-panel &
xfdesktop &
EOF

RUN chmod +x /root/.vnc/xstartup

# Get noVNC
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt/ && \
    mv /opt/noVNC-1.4.0 /opt/novnc && \
    rm /tmp/novnc.tar.gz && \
    wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O /tmp/websockify.tar.gz && \
    tar -xzf /tmp/websockify.tar.gz -C /opt/novnc/utils/ && \
    mv /opt/novnc/utils/websockify-0.11.0 /opt/novnc/utils/websockify && \
    rm /tmp/websockify.tar.gz

# Install CopyQ - Modern clipboard manager with icon
RUN apt update && apt install -y \
    copyq \
    xclip \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Configure CopyQ to start with icon and enable VNC clipboard
RUN mkdir -p /root/.config/copyq && \
    cat > /root/.config/copyq/copyq.conf << 'EOF'
[General]
autostart=true
check_clipboard=true
check_selection=true
maxitems=50
show_tray=true
tab_names=clipboard
tray_commands=show
tray_items=10
EOF

# Create a simple clipboard sync script
RUN cat > /usr/local/bin/sync-clipboard << 'EOF'
#!/bin/bash
# Simple clipboard sync for VNC
while true; do
    # Keep vncconfig running
    if ! pgrep -x "vncconfig" > /dev/null; then
        vncconfig -nowin &
    fi
    sleep 5
done
EOF

RUN chmod +x /usr/local/bin/sync-clipboard

# Add clipboard startup to xstartup
RUN cat >> /root/.vnc/xstartup << 'EOF'

# Start CopyQ with icon
copyq &
sleep 2

# Start clipboard sync
/usr/local/bin/sync-clipboard &
EOF

# Create a test file to verify
RUN echo "echo 'Clipboard test successful! Copy this text and try to paste.'" > /test-clip.sh && \
    chmod +x /test-clip.sh

# Copy noVNC HTML files
RUN cp /opt/novnc/vnc_lite.html /opt/novnc/index.html

# Fix vncserver
RUN sed -i '/^\s*\$fontPath\s*=/{s/.*/\$fontPath = "";/}' /usr/bin/vncserver

EXPOSE 10000

# Startup
CMD echo "Starting VNC server..." && \
    vncserver :1 -geometry ${VNC_RESOLUTION} -depth ${VNC_DEPTH} && \
    echo "VNC started on display :1" && \
    echo "Starting noVNC..." && \
    /opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 --heartbeat 30 --web /opt/novnc && \
    echo "Ready! CopyQ icon should appear in system tray." && \
    echo "Test: Run /test-clip.sh in terminal" && \
    tail -f /dev/null
