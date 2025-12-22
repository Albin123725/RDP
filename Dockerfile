FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV USER=root
ENV HOME=/root
ENV DISPLAY=:1
ENV VNC_PASSWD=albin4242
ENV VNC_RESOLUTION=1024x576
ENV VNC_DEPTH=16

# Set timezone
RUN ln -fs /usr/share/zoneinfo/UTC /etc/localtime && \
    echo "UTC" > /etc/timezone

# Install MINIMAL packages with CORRECT Ubuntu 22.04 names
RUN apt update && apt install -y \
    # Core XFCE components
    xfce4 \
    xfce4-terminal \
    thunar \
    xfce4-panel \
    xfwm4 \
    # xfsettingsd is part of xfce4-settings in Ubuntu 22.04
    xfce4-settings \
    # VNC
    tightvncserver \
    # Browser - Use regular Firefox (not ESR in Ubuntu 22.04)
    firefox \
    # Essential libraries
    libglib2.0-0 \
    libgtk-3-0 \
    libnotify4 \
    libnss3 \
    libxss1 \
    libxtst6 \
    xdg-utils \
    wget \
    # X11 essentials
    x11-xserver-utils \
    xauth \
    xinit \
    # D-Bus for Firefox
    dbus-x11 \
    # PolicyKit for Firefox
    policykit-1 \
    --no-install-recommends && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Remove unnecessary components
RUN apt purge -y \
    xfce4-screensaver \
    xfce4-power-manager \
    xscreensaver* \
    && apt autoremove -y

# Setup VNC password
RUN mkdir -p /root/.vnc && \
    printf "${VNC_PASSWD}\n${VNC_PASSWD}\nn\n" | vncpasswd && \
    chmod 600 /root/.vnc/passwd

# Create SIMPLE xstartup
RUN cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Start D-Bus for Firefox
dbus-launch --sh-syntax --exit-with-session > /tmp/dbus.env
. /tmp/dbus.env

# Start XFCE session
startxfce4 &
EOF

RUN chmod +x /root/.vnc/xstartup

# Configure Firefox preferences
RUN mkdir -p /root/.mozilla/firefox/default && \
    echo 'user_pref("browser.shell.checkDefaultBrowser", false);' > /root/.mozilla/firefox/default/prefs.js && \
    echo 'user_pref("browser.sessionstore.resume_from_crash", false);' >> /root/.mozilla/firefox/default/prefs.js && \
    echo 'user_pref("browser.startup.homepage", "about:blank");' >> /root/.mozilla/firefox/default/prefs.js && \
    echo 'user_pref("browser.tabs.remote.autostart", false);' >> /root/.mozilla/firefox/default/prefs.js

# Set Firefox as default browser
RUN update-alternatives --set x-www-browser /usr/bin/firefox && \
    update-alternatives --set gnome-www-browser /usr/bin/firefox

# Download noVNC
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt/ && \
    mv /opt/noVNC-1.4.0 /opt/novnc && \
    rm /tmp/novnc.tar.gz && \
    wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O /tmp/websockify.tar.gz && \
    tar -xzf /tmp/websockify.tar.gz -C /opt/novnc/utils/ && \
    mv /opt/novnc/utils/websockify-0.11.0 /opt/novnc/utils/websockify && \
    rm /tmp/websockify.tar.gz

# Copy noVNC HTML files
RUN cp /opt/novnc/vnc_lite.html /opt/novnc/index.html

# Fix VNC server font path issue
RUN sed -i 's|^\(.*\$fontPath =\).*$|\1 "";|' /usr/bin/vncserver

# Create desktop launcher for Firefox
RUN mkdir -p /root/Desktop && \
    echo '[Desktop Entry]' > /root/Desktop/firefox.desktop && \
    echo 'Version=1.0' >> /root/Desktop/firefox.desktop && \
    echo 'Name=Firefox Browser' >> /root/Desktop/firefox.desktop && \
    echo 'Comment=Browse the Internet' >> /root/Desktop/firefox.desktop && \
    echo 'Exec=firefox' >> /root/Desktop/firefox.desktop && \
    echo 'Icon=firefox' >> /root/Desktop/firefox.desktop && \
    echo 'Terminal=false' >> /root/Desktop/firefox.desktop && \
    echo 'Type=Application' >> /root/Desktop/firefox.desktop && \
    echo 'Categories=Network;WebBrowser;' >> /root/Desktop/firefox.desktop && \
    chmod +x /root/Desktop/firefox.desktop

# Create a simple test script
RUN cat > /test-gui.sh << 'EOF'
#!/bin/bash
echo "=== GUI Components Test ==="
echo ""
echo "Installed components:"
echo "1. Desktop: $(which startxfce4 2>/dev/null && echo '✓ XFCE4')"
echo "2. Terminal: $(which xfce4-terminal 2>/dev/null && echo '✓ xfce4-terminal')"
echo "3. File Manager: $(which thunar 2>/dev/null && echo '✓ Thunar')"
echo "4. Browser: $(which firefox 2>/dev/null && echo '✓ Firefox')"
echo ""
echo "How to use:"
echo "- Browser: Double-click Firefox icon on desktop"
echo "- Terminal: Already open or Alt+F2 → 'xfce4-terminal'"
echo "- File Manager: Alt+F2 → 'thunar'"
echo ""
EOF

RUN chmod +x /test-gui.sh

EXPOSE 10000

# Startup script
CMD echo "Starting VNC server..." && \
    vncserver :1 -geometry ${VNC_RESOLUTION} -depth ${VNC_DEPTH} && \
    echo "VNC started on display :1" && \
    echo "Running GUI test..." && \
    /test-gui.sh && \
    echo "Starting noVNC proxy..." && \
    /opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 --heartbeat 30 --web /opt/novnc && \
    echo "==========================================" && \
    echo "VNC Desktop Ready!" && \
    echo "URL: Your Render URL" && \
    echo "Password: albin4242" && \
    echo "==========================================" && \
    tail -f /dev/null
