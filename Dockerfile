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
    # Add lightweight browser alternatives
    firefox \
    # Clipboard support tools
    autocutsel \
    xclip \
    # For proper browser integration
    xdg-utils \
    xdg-user-dirs \
    --no-install-recommends && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    # Remove unnecessary documentation and locales
    rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/locale/* && \
    # Remove Xfce components that aren't essential
    apt purge -y xfce4-screensaver xfce4-power-manager xscreensaver* && \
    # Clean up Firefox to reduce size (keep minimal)
    rm -rf /usr/lib/firefox/distribution/extensions \
           /usr/share/doc/firefox* \
           /usr/share/locale/*/firefox* \
           /usr/share/locale/*/thunderbird* && \
    apt autoremove -y && \
    apt autoclean

# Setup VNC password with less memory-intensive settings
RUN mkdir -p /root/.vnc && \
    printf "${VNC_PASSWD}\n${VNC_PASSWD}\nn\n" | vncpasswd && \
    chmod 600 /root/.vnc/passwd

# Configure default web browser and fix desktop integration
RUN update-alternatives --set x-www-browser /usr/bin/firefox && \
    update-alternatives --set gnome-www-browser /usr/bin/firefox && \
    # Create proper mime type associations
    echo "[Added Associations]" > /etc/xfce4/defaults.list && \
    echo "x-scheme-handler/http=firefox.desktop" >> /etc/xfce4/defaults.list && \
    echo "x-scheme-handler/https=firefox.desktop" >> /etc/xfce4/defaults.list && \
    echo "text/html=firefox.desktop" >> /etc/xfce4/defaults.list && \
    echo "application/xhtml+xml=firefox.desktop" >> /etc/xfce4/defaults.list && \
    # Configure Firefox to run in headless-friendly mode
    mkdir -p /root/.mozilla/firefox/default && \
    echo 'user_pref("browser.tabs.remote.autostart", false);' > /root/.mozilla/firefox/default/prefs.js && \
    echo 'user_pref("browser.tabs.remote.autostart.2", false);' >> /root/.mozilla/firefox/default/prefs.js && \
    echo 'user_pref("browser.sessionstore.resume_from_crash", false);' >> /root/.mozilla/firefox/default/prefs.js && \
    echo 'user_pref("browser.shell.checkDefaultBrowser", false);' >> /root/.mozilla/firefox/default/prefs.js && \
    echo 'user_pref("browser.startup.homepage", "about:blank");' >> /root/.mozilla/firefox/default/prefs.js

# Create optimized xstartup with memory-saving options and clipboard support
RUN cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
xsetroot -solid grey
vncconfig -iconic &
# Start clipboard synchronization for PRIMARY selection
autocutsel -fork &
# Start clipboard synchronization for CLIPBOARD selection
autocutsel -s CLIPBOARD -fork &
# Disable composite manager to save memory
xfwm4 --compositor=off &
# Start with minimal Xfce components
xfsettingsd --daemon
xfce4-panel &
xfdesktop &
# Set environment variables for proper operation
export GDK_BACKEND=x11
export NO_AT_BRIDGE=1
export MOZ_DISABLE_RDD_SANDBOX=1
export MOZ_LAYERS_ALLOW_SOFTWARE_GL=1
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

# Create a simple browser test script
RUN cat > /test-browser.sh << 'EOF'
#!/bin/bash
echo "Testing browser configuration..."
# Test if Firefox is accessible
if command -v firefox &> /dev/null; then
    echo "✓ Firefox is installed"
    # Create a simple test HTML file
    echo '<html><body><h1>Browser Test Page</h1><p>If you see this, browser is working!</p></body></html>' > /tmp/test.html
    # Test Firefox in headless mode briefly
    timeout 5 firefox --headless --screenshot /tmp/test.png file:///tmp/test.html 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ Firefox can render pages"
    else
        echo "⚠ Firefox headless test failed, but GUI may still work"
    fi
else
    echo "✗ Firefox not found"
fi
# Check default browser configuration
if [ "$(update-alternatives --query x-www-browser | grep Value | cut -d' ' -f2)" = "/usr/bin/firefox" ]; then
    echo "✓ Firefox is set as default browser"
else
    echo "✗ Firefox is NOT default browser"
fi
EOF

RUN chmod +x /test-browser.sh

# Copy noVNC HTML files to serve as health check endpoint
RUN cp /opt/novnc/vnc_lite.html /opt/novnc/index.html

# Fix the vncserver configuration more carefully
RUN sed -i '/^\s*\$fontPath\s*=/{s/.*/\$fontPath = "";/}' /usr/bin/vncserver

EXPOSE 10000

# Startup script with clipboard support
CMD echo "Starting VNC server..." && \
    /cleanup.sh & \
    # Start VNC server
    vncserver :1 -geometry ${VNC_RESOLUTION} -depth ${VNC_DEPTH} && \
    echo "VNC started successfully on display :1" && \
    echo "Testing browser configuration..." && \
    /test-browser.sh && \
    echo "Starting noVNC proxy..." && \
    # Start noVNC proxy
    /opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 --heartbeat 30 --web /opt/novnc && \
    echo "noVNC started on port 10000" && \
    echo "Clipboard sync enabled - use Ctrl+C/Ctrl+V for copy-paste" && \
    tail -f /dev/null
