# Dockerfile
FROM ubuntu:22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV HOME=/root
ENV DISPLAY=:99
ENV RESOLUTION=1280x720x24

# Install core system components
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
    # Core GUI and RDP
    xvfb x11vnc xdotool \
    # Window manager (minimal)
    openbox obconf menu \
    # Terminal
    xterm \
    # Browser
    firefox \
    # File manager
    pcmanfm \
    # Utilities
    wget curl git unzip software-properties-common \
    # Fonts
    fonts-liberation fonts-noto fonts-ubuntu fonts-noto-cjk \
    # Audio
    pulseaudio pavucontrol \
    # Video codecs (updated package names)
    libavcodec-extra libx264-dev libx265-dev gstreamer1.0-libav \
    # WebRTC and media support
    libgstreamer-plugins-base1.0-0 libgstreamer1.0-0 \
    gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly gstreamer1.0-gl \
    # Firefox dependencies
    libavcodec58 libavformat58 libavutil56 libswscale5 \
    libgtk-3-0 libdbus-glib-1-2 libxt6 \
    # Additional dependencies
    libnss3 libxss1 libasound2 libpango1.0-0 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install noVNC
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/noVNC && \
    git clone --depth 1 https://github.com/novnc/websockify /opt/noVNC/utils/websockify && \
    ln -s /opt/noVNC/vnc.html /opt/noVNC/index.html

# Create startup script
RUN echo '#!/bin/bash\n\
\n\
# Set up display\n\
Xvfb $DISPLAY -screen 0 ${RESOLUTION} -ac +extension GLX +render -noreset & \n\
\n\
# Start VNC server\n\
x11vnc -display $DISPLAY -noxdamage -forever -shared -rfbport 5900 -passwd ${VNC_PASSWORD:-password123} & \n\
\n\
# Start noVNC\n\
/opt/noVNC/utils/novnc_proxy --vnc localhost:5900 --listen 8080 --web /opt/noVNC & \n\
\n\
# Wait for Xvfb\n\
sleep 2\n\
\n\
# Set up Openbox\n\
openbox --config-file /etc/xdg/openbox/rc.xml & \n\
\n\
# Create Firefox profile directory\n\
mkdir -p ~/.mozilla/firefox\n\
\n\
# Set Firefox preferences for better performance\n\
cat > ~/.mozilla/firefox/profiles.ini << "EOF"\n\
[General]\n\
StartWithLastProfile=1\n\
\n\
[Profile0]\n\
Name=default\n\
IsRelative=1\n\
Path=default.default\n\
Default=1\n\
EOF\n\
\n\
mkdir -p ~/.mozilla/firefox/default.default\n\
cat > ~/.mozilla/firefox/default.default/user.js << "EOF"\n\
user_pref("browser.cache.disk.enable", true);\n\
user_pref("browser.cache.memory.enable", true);\n\
user_pref("browser.sessionstore.interval", 15000);\n\
user_pref("browser.startup.homepage", "about:blank");\n\
user_pref("dom.ipc.processCount", 8);\n\
user_pref("media.autoplay.default", 0);\n\
user_pref("media.ffmpeg.vaapi.enabled", true);\n\
user_pref("media.hardware-video-decoding.enabled", true);\n\
user_pref("media.navigator.enabled", true);\n\
user_pref("media.webrtc.hw.h264.enabled", true);\n\
user_pref("network.http.use-cache", true);\n\
user_pref("privacy.trackingprotection.enabled", false);\n\
user_pref("webgl.disabled", false);\n\
user_pref("layers.acceleration.force-enabled", true);\n\
user_pref("gfx.webrender.all", true);\n\
user_pref("gfx.webrender.enabled", true);\n\
EOF\n\
\n\
# Create desktop shortcuts\n\
mkdir -p ~/Desktop\n\
cat > ~/Desktop/firefox.desktop << "EOF"\n\
[Desktop Entry]\n\
Version=1.0\n\
Type=Application\n\
Name=Firefox\n\
Comment=Web Browser\n\
Exec=firefox\n\
Icon=firefox\n\
Terminal=false\n\
Categories=Network;WebBrowser;\n\
EOF\n\
\n\
cat > ~/Desktop/terminal.desktop << "EOF"\n\
[Desktop Entry]\n\
Version=1.0\n\
Type=Application\n\
Name=Terminal\n\
Comment=Terminal Emulator\n\
Exec=xterm\n\
Icon=utilities-terminal\n\
Terminal=false\n\
Categories=System;TerminalEmulator;\n\
EOF\n\
\n\
cat > ~/Desktop/pcmanfm.desktop << "EOF"\n\
[Desktop Entry]\n\
Version=1.0\n\
Type=Application\n\
Name=File Manager\n\
Comment=File Manager\n\
Exec=pcmanfm\n\
Icon=system-file-manager\n\
Terminal=false\n\
Categories=System;FileTools;\n\
EOF\n\
\n\
chmod +x ~/Desktop/*.desktop\n\
\n\
# Create Openbox menu\n\
mkdir -p ~/.config/openbox\n\
cat > ~/.config/openbox/menu.xml << "EOF"\n\
<?xml version="1.0" encoding="UTF-8"?>\n\
<openbox_menu xmlns="http://openbox.org/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://openbox.org/ menu.xsd">\n\
<menu id="root-menu" label="Applications">\n\
  <item label="Firefox">\n\
    <action name="Execute">\n\
      <execute>firefox</execute>\n\
    </action>\n\
  </item>\n\
  <item label="Terminal">\n\
    <action name="Execute">\n\
      <execute>xterm</execute>\n\
    </action>\n\
  </item>\n\
  <item label="File Manager">\n\
    <action name="Execute">\n\
      <execute>pcmanfm</execute>\n\
    </action>\n\
  </item>\n\
  <separator/>\n\
  <menu id="exit-menu" label="Exit">\n\
    <item label="Log Out">\n\
      <action name="Exit">\n\
        <prompt>yes</prompt>\n\
      </action>\n\
    </item>\n\
  </menu>\n\
</menu>\n\
</openbox_menu>\n\
EOF\n\
\n\
# Start applications\n\
pcmanfm --desktop & \n\
\n\
# Wait a bit for everything to initialize\n\
sleep 3\n\
\n\
# Start Firefox (optional - you can remove this line if you don'\''t want it to auto-start)\n\
# firefox --display=$DISPLAY &\n\
\n\
# Health check endpoint\n\
while true; do\n\
    echo -e "HTTP/1.1 200 OK\\n\\nOK" | nc -l -p 8081 -q 1\n\
done & \n\
\n\
# Keep container running\n\
tail -f /dev/null' > /start.sh && chmod +x /start.sh

# Create a simple health check script
RUN echo '#!/bin/bash\n\
curl -f http://localhost:8081/ || exit 1' > /healthcheck.sh && chmod +x /healthcheck.sh

# Set working directory
WORKDIR /root

# Expose ports
EXPOSE 8080  # noVNC
EXPOSE 8081  # Health check

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD /healthcheck.sh

# Start the service
CMD ["/start.sh"]
