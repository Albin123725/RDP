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
    openbox \
    # Terminal
    xterm \
    # Browser
    firefox \
    # File manager
    pcmanfm \
    # Utilities
    wget curl git unzip software-properties-common \
    # Fonts
    fonts-liberation fonts-noto fonts-ubuntu \
    # Audio (optional for some sites)
    pulseaudio pavucontrol \
    # Video codecs
    libavcodec-extra libx264-160 gstreamer1.0-libav \
    # WebRTC support
    libgstreamer-plugins-base1.0-0 libgstreamer1.0-0 \
    # Chromium codecs for Firefox
    libavcodec58 libavformat58 libavutil56 libswscale5 \
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
# Set Firefox preferences for better performance\n\
mkdir -p ~/.mozilla/firefox/default.default/\n\
echo '\''{\n\
  "browser.cache.disk.enable": true,\n\
  "browser.cache.memory.enable": true,\n\
  "browser.sessionstore.interval": 15000,\n\
  "browser.startup.homepage": "about:blank",\n\
  "dom.ipc.processCount": 8,\n\
  "media.autoplay.default": 0,\n\
  "media.ffmpeg.vaapi.enabled": true,\n\
  "media.hardware-video-decoding.enabled": true,\n\
  "media.navigator.enabled": true,\n\
  "media.webrtc.hw.h264.enabled": true,\n\
  "network.http.use-cache": true,\n\
  "privacy.trackingprotection.enabled": false,\n\
  "webgl.disabled": false\n\
}'\'' > ~/.mozilla/firefox/default.default/prefs.js\n\
\n\
# Create desktop shortcuts\n\
mkdir -p ~/Desktop\n\
echo "[Desktop Entry]\n\
Version=1.0\n\
Type=Application\n\
Name=Firefox\n\
Comment=Web Browser\n\
Exec=firefox\n\
Icon=firefox\n\
Terminal=false\n\
Categories=Network;WebBrowser;" > ~/Desktop/firefox.desktop\n\
\n\
echo "[Desktop Entry]\n\
Version=1.0\n\
Type=Application\n\
Name=Terminal\n\
Comment=Terminal Emulator\n\
Exec=xterm\n\
Icon=utilities-terminal\n\
Terminal=false\n\
Categories=System;TerminalEmulator;" > ~/Desktop/terminal.desktop\n\
\n\
echo "[Desktop Entry]\n\
Version=1.0\n\
Type=Application\n\
Name=File Manager\n\
Comment=File Manager\n\
Exec=pcmanfm\n\
Icon=system-file-manager\n\
Terminal=false\n\
Categories=System;FileTools;" > ~/Desktop/pcmanfm.desktop\n\
\n\
chmod +x ~/Desktop/*.desktop\n\
\n\
# Start applications in background\n\
pcmanfm --desktop & \n\
firefox --display=$DISPLAY & \n\
\n\
# Health check endpoint\n\
while true; do\n\
    echo -e "HTTP/1.1 200 OK\\n\\nOK" | nc -l -p 8081 -q 1\n\
done & \n\
\n\
# Keep container running\n\
tail -f /dev/null' > /start.sh && chmod +x /start.sh

# Set working directory
WORKDIR /root

# Expose port
EXPOSE 8080
EXPOSE 8081

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8081/ || exit 1

# Start the service
CMD ["/start.sh"]
