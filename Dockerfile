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

# Install MINIMAL packages
RUN apt update && apt install -y \
    # Core XFCE (minimal)
    xfce4 \
    xfce4-terminal \
    thunar \
    xfce4-panel \
    xfwm4 \
    xfdesktop4 \
    xfsettingsd \
    # VNC
    tightvncserver \
    # Browser - Use Firefox ESR (more stable)
    firefox-esr \
    # Terminal already installed (xfce4-terminal)
    # Essential system libraries
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
    --no-install-recommends && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Remove unnecessary components to save memory
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

# Start XFCE components
xfwm4 &
xfsettingsd --daemon
xfce4-panel &
xfdesktop &

# Start Thunar file manager in background
thunar --daemon &

# Set Firefox as default browser
update-alternatives --set x-www-browser /usr/bin/firefox-esr
update-alternatives --set gnome-www-browser /usr/bin/firefox-esr

# Launch xfce4-terminal
xfce4-terminal &
EOF

RUN chmod +x /root/.vnc/xstartup

# Configure Firefox to work in VNC environment
RUN mkdir -p /root/.mozilla/firefox-esr/default && \
    echo 'user_pref("browser.shell.checkDefaultBrowser", false);' > /root/.mozilla/firefox-esr/default/prefs.js && \
    echo 'user_pref("browser.sessionstore.resume_from_crash", false);' >> /root/.mozilla/firefox-esr/default/prefs.js && \
    echo 'user_pref("browser.startup.homepage", "about:blank");' >> /root/.mozilla/firefox-esr/default/prefs.js && \
    echo 'user_pref("browser.tabs.remote.autostart", false);' >> /root/.mozilla/firefox-esr/default/prefs.js && \
    echo 'user_pref("browser.tabs.remote.autostart.2", false);' >> /root/.mozilla/firefox-esr/default/prefs.js

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

# Create browser test script
RUN cat > /test-browser.sh << 'EOF'
#!/bin/bash
echo "Testing browser setup..."
echo "1. Checking Firefox installation..."
if command -v firefox-esr >/dev/null 2>&1; then
    echo "   ✓ Firefox ESR installed"
else
    echo "   ✗ Firefox ESR not found"
fi

echo "2. Checking default browser..."
DEFAULT_BROWSER=$(update-alternatives --query x-www-browser | grep "Value:" | cut -d' ' -f2)
if [ "$DEFAULT_BROWSER" = "/usr/bin/firefox-esr" ]; then
    echo "   ✓ Firefox ESR is default browser"
else
    echo "   ✗ Default browser: $DEFAULT_BROWSER"
fi

echo "3. Testing Firefox in minimal mode..."
timeout 5 firefox-esr --headless --screenshot /tmp/test.png https://example.com 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   ✓ Firefox can render pages"
    rm -f /tmp/test.png
else
    echo "   ⚠ Firefox headless test failed (GUI may still work)"
fi

echo "4. Creating desktop launcher..."
cat > /root/Desktop/firefox.desktop << 'DESKTOP'
[Desktop Entry]
Version=1.0
Name=Firefox Browser
Comment=Browse the Internet
Exec=firefox-esr
Icon=firefox-esr
Terminal=false
Type=Application
Categories=Network;WebBrowser;
DESKTOP
chmod +x /root/Desktop/firefox.desktop
echo "   ✓ Desktop launcher created"

echo ""
echo "To open browser:"
echo "1. Double-click Firefox icon on desktop"
echo "2. Or run in terminal: firefox-esr"
echo "3. Or press Alt+F2 and type: firefox-esr"
EOF

RUN chmod +x /test-browser.sh

EXPOSE 10000

# Startup script
CMD echo "Starting VNC server..." && \
    vncserver :1 -geometry ${VNC_RESOLUTION} -depth ${VNC_DEPTH} && \
    echo "VNC started on :1" && \
    echo "Testing browser setup..." && \
    /test-browser.sh && \
    echo "Starting noVNC proxy..." && \
    /opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 --heartbeat 30 --web /opt/novnc && \
    echo "Access at: http://localhost:10000" && \
    tail -f /dev/null
