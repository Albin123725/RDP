FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Kolkata
ENV USER=root
ENV HOME=/root
ENV DISPLAY=:1
ENV VNC_PASSWD=albin4242
ENV VNC_RESOLUTION=1024x576
# Reduced from 24 to save memory
ENV VNC_DEPTH=16

# Set timezone
RUN ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo "Asia/Kolkata" > /etc/timezone

# Install minimal required packages and clean up aggressively
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
    # Clipboard support for copy-paste
    autocutsel \
    xclip \
    --no-install-recommends && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    # Remove unnecessary documentation and locales
    rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/locale/* && \
    # Remove Xfce components that aren't essential
    apt purge -y xfce4-screensaver xfce4-power-manager xscreensaver* && \
    apt autoremove -y && \
    apt autoclean

# Setup VNC password with less memory-intensive settings
RUN mkdir -p /root/.vnc && \
    printf "${VNC_PASSWD}\n${VNC_PASSWD}\nn\n" | vncpasswd && \
    chmod 600 /root/.vnc/passwd

# Create optimized xstartup with memory-saving options AND clipboard support
RUN cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
xsetroot -solid grey
vncconfig -iconic &
# Start clipboard synchronization for copy-paste support
autocutsel -fork &
autocutsel -s CLIPBOARD -fork &
# Disable composite manager to save memory
xfwm4 --compositor=off &
# Start with minimal Xfce components
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

# Create cleanup script for periodic memory management
RUN cat > /cleanup.sh << 'EOF'
#!/bin/bash
while true; do
    # Clean up temporary files
    find /tmp -type f -atime +1 -delete 2>/dev/null || true
    find /var/tmp -type f -atime +1 -delete 2>/dev/null || true
    # Kill any zombie processes
    ps aux | grep "defunct" | grep -v grep | awk "{print \$2}" | xargs -r kill -9 2>/dev/null || true
    # Restart clipboard sync if it dies
    if ! pgrep -x "autocutsel" > /dev/null; then
        autocutsel -fork &
        autocutsel -s CLIPBOARD -fork &
    fi
    sleep 300
done
EOF

RUN chmod +x /cleanup.sh

# Create clipboard test script
RUN cat > /clipboard-test.sh << 'EOF'
#!/bin/bash
echo "Clipboard Test Script"
echo "===================="
echo ""
echo "To test copy-paste:"
echo "1. Copy this text from VNC: VNC_TO_LOCAL_TEST"
echo "2. Paste it outside VNC (in your local machine)"
echo "3. Copy this from local: LOCAL_TO_VNC_TEST" 
echo "4. Paste it inside VNC terminal with Ctrl+Shift+V"
echo ""
echo "Clipboard status:"
if pgrep -x "autocutsel" > /dev/null; then
    echo "✓ Clipboard sync is running"
else
    echo "✗ Clipboard sync is NOT running"
    echo "Starting it now..."
    autocutsel -fork &
    autocutsel -s CLIPBOARD -fork &
fi
EOF

RUN chmod +x /clipboard-test.sh

# Copy noVNC HTML files to serve as health check endpoint
RUN cp /opt/novnc/vnc_lite.html /opt/novnc/index.html

# Fix the vncserver configuration more carefully
RUN sed -i '/^\s*\$fontPath\s*=/{s/.*/\$fontPath = "";/}' /usr/bin/vncserver

EXPOSE 10000

# Simple startup script that works with clipboard support
CMD echo "Starting VNC server..." && \
    /cleanup.sh & \
    # Start VNC server without the problematic -fp option
    vncserver :1 -geometry ${VNC_RESOLUTION} -depth ${VNC_DEPTH} && \
    echo "VNC started successfully on display :1" && \
    echo "Starting clipboard synchronization..." && \
    autocutsel -fork & \
    autocutsel -s CLIPBOARD -fork & \
    echo "Clipboard sync started - you can now copy-paste between VNC and local machine" && \
    echo "Starting noVNC proxy..." && \
    # Start noVNC proxy
    /opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 --heartbeat 30 --web /opt/novnc && \
    echo "noVNC started on port 10000" && \
    echo "" && \
    echo "=== Clipboard Instructions ===" && \
    echo "Copy from LOCAL to VNC: Ctrl+C local → Ctrl+V in VNC" && \
    echo "Copy from VNC to LOCAL: Ctrl+C in VNC → Ctrl+V local" && \
    echo "Run /clipboard-test.sh to verify" && \
    tail -f /dev/null
