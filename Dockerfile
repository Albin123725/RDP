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
    # Add Epiphany (GNOME Web) lightweight browser
    epiphany-browser \
    # Add xdg-utils for proper browser integration
    xdg-utils \
    --no-install-recommends && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    # Remove unnecessary documentation and locales
    rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/locale/* && \
    # Remove Xfce components that aren't essential
    apt purge -y xfce4-screensaver xfce4-power-manager xscreensaver* && \
    # Remove unnecessary Epiphany docs to save space
    rm -rf /usr/share/doc/epiphany* && \
    apt autoremove -y && \
    apt autoclean

# Setup VNC password with less memory-intensive settings
RUN mkdir -p /root/.vnc && \
    printf "${VNC_PASSWD}\n${VNC_PASSWD}\nn\n" | vncpasswd && \
    chmod 600 /root/.vnc/passwd

# Configure default web browser and fix desktop integration
RUN update-alternatives --set x-www-browser /usr/bin/epiphany-browser && \
    update-alternatives --set gnome-www-browser /usr/bin/epiphany-browser && \
    # Create proper desktop file for Epiphany
    echo "[Desktop Entry]" > /usr/share/applications/epiphany.desktop && \
    echo "Name=Epiphany Web Browser" >> /usr/share/applications/epiphany.desktop && \
    echo "GenericName=Web Browser" >> /usr/share/applications/epiphany.desktop && \
    echo "Comment=Browse the Web" >> /usr/share/applications/epiphany.desktop && \
    echo "Exec=epiphany-browser %U" >> /usr/share/applications/epiphany.desktop && \
    echo "Icon=epiphany" >> /usr/share/applications/epiphany.desktop && \
    echo "Terminal=false" >> /usr/share/applications/epiphany.desktop && \
    echo "Type=Application" >> /usr/share/applications/epiphany.desktop && \
    echo "Categories=Network;WebBrowser;" >> /usr/share/applications/epiphany.desktop && \
    echo "MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/vnd.mozilla.xul+xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;x-scheme-handler/chrome;video/webm;application/x-xpinstall;" >> /usr/share/applications/epiphany.desktop && \
    echo "StartupNotify=true" >> /usr/share/applications/epiphany.desktop && \
    # Also create a simpler default browser configuration
    echo "#!/bin/sh" > /usr/local/bin/default-browser && \
    echo "exec epiphany-browser \"\$@\"" >> /usr/local/bin/default-browser && \
    chmod +x /usr/local/bin/default-browser

# Create optimized xstartup with memory-saving options
RUN cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
xsetroot -solid grey
vncconfig -iconic &
# Disable composite manager to save memory
xfwm4 --compositor=off &
# Start with minimal Xfce components
xfsettingsd --daemon
xfce4-panel &
xfdesktop &
# Set some environment variables for proper browser operation
export GDK_BACKEND=x11
export NO_AT_BRIDGE=1
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
    sleep 300
done
EOF

RUN chmod +x /cleanup.sh

# Create a simple test script to verify browser works
RUN cat > /test-browser.sh << 'EOF'
#!/bin/bash
# Test if browser can open a simple page
timeout 10 epiphany-browser --version
if [ $? -eq 0 ]; then
    echo "Browser test passed: Epiphany is working"
else
    echo "Browser test failed: Epiphany may have issues"
fi
EOF

RUN chmod +x /test-browser.sh

# Copy noVNC HTML files to serve as health check endpoint
RUN cp /opt/novnc/vnc_lite.html /opt/novnc/index.html

# Fix the vncserver configuration more carefully
RUN sed -i '/^\s*\$fontPath\s*=/{s/.*/\$fontPath = "";/}' /usr/bin/vncserver

EXPOSE 10000

# Simple startup script that works
CMD echo "Starting VNC server..." && \
    /cleanup.sh & \
    # Start VNC server without the problematic -fp option
    vncserver :1 -geometry ${VNC_RESOLUTION} -depth ${VNC_DEPTH} && \
    echo "VNC started successfully on display :1" && \
    echo "Testing browser..." && \
    /test-browser.sh && \
    echo "Starting noVNC proxy..." && \
    # Start noVNC proxy
    /opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 --heartbeat 30 --web /opt/novnc && \
    echo "noVNC started on port 10000" && \
    tail -f /dev/null
