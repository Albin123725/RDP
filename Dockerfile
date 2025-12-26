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

# Update package lists first
RUN apt update && apt upgrade -y

# Install core desktop and VNC components first
RUN apt install -y \
    xfce4 \
    xfce4-goodies \
    tightvncserver \
    wget \
    sudo \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    xfonts-base \
    xfonts-100dpi \
    xfonts-75dpi \
    --no-install-recommends

# Install noVNC components
RUN apt install -y \
    novnc \
    websockify \
    python3-numpy \
    --no-install-recommends

# Install Firefox browser with minimal dependencies
RUN apt install -y \
    firefox \
    fonts-liberation \
    libasound2 \
    libdbus-glib-1-2 \
    libgtk-3-0 \
    --no-install-recommends

# Clean up in separate steps to avoid issues
RUN apt clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* /var/tmp/*

# Remove unnecessary documentation and locales (but keep some for Firefox)
RUN find /usr/share/doc -depth -type f ! -name copyright -delete && \
    find /usr/share/man -type f -delete && \
    find /usr/share/locale -type f -name '*.mo' -delete

# Remove unnecessary Xfce components
RUN apt purge -y xfce4-screensaver xfce4-power-manager xscreensaver* && \
    apt autoremove -y --purge && \
    apt autoclean

# Setup VNC password with less memory-intensive settings
RUN mkdir -p /root/.vnc && \
    printf "${VNC_PASSWD}\n${VNC_PASSWD}\nn\n" | vncpasswd && \
    chmod 600 /root/.vnc/passwd

# Create optimized xstartup with Firefox properly integrated
RUN cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export DISPLAY=:1
export HOME=/root

[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources

xsetroot -solid grey
vncconfig -iconic &

# Disable composite manager to save memory
xfwm4 --compositor=off &

# Start Xfce desktop components
xfsettingsd --daemon
xfce4-panel &

# Start desktop
xfdesktop &

# Create Applications directory structure for Firefox
mkdir -p /root/.local/share/applications
cat > /root/.local/share/applications/firefox.desktop << 'DESKTOP'
[Desktop Entry]
Version=1.0
Name=Firefox Web Browser
Name[en]=Firefox Web Browser
Comment=Browse the World Wide Web
Comment[en]=Browse the World Wide Web
Exec=firefox %u
Terminal=false
Type=Application
Icon=firefox
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/vnd.mozilla.xul+xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;
StartupNotify=true
StartupWMClass=Firefox
DESKTOP

update-desktop-database /root/.local/share/applications

EOF

RUN chmod +x /root/.vnc/xstartup

# Create desktop shortcut for Firefox
RUN mkdir -p /root/Desktop && \
    cat > /root/Desktop/firefox.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Firefox Browser
Comment=Open Firefox Browser
Exec=firefox
Icon=firefox
Terminal=false
StartupNotify=true
Categories=Network;WebBrowser;
EOF

RUN chmod +x /root/Desktop/firefox.desktop

# Create a simple test script to verify Firefox works
RUN cat > /root/test-firefox.sh << 'EOF'
#!/bin/bash
export DISPLAY=:1
export HOME=/root
if command -v firefox &> /dev/null; then
    echo "Firefox is installed at: $(which firefox)"
    echo "Firefox version: $(firefox --version 2>/dev/null || echo "Could not get version")"
else
    echo "Firefox is not installed or not in PATH"
fi
EOF

RUN chmod +x /root/test-firefox.sh

# Get noVNC (manual installation to ensure latest version)
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
    echo "Firefox installation check:" && \
    /root/test-firefox.sh && \
    echo "Starting noVNC proxy..." && \
    # Start noVNC proxy
    /opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 --heartbeat 30 --web /opt/novnc && \
    echo "noVNC started on port 10000" && \
    tail -f /dev/null
