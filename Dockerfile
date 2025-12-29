FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:99
ENV VNC_PASSWORD=password123
ENV DISPLAY_WIDTH=1280
ENV DISPLAY_HEIGHT=720
ENV LANG=en_US.UTF-8

# Install core packages
RUN apt-get update && apt-get install -y \
    sudo wget curl gnupg2 software-properties-common \
    && apt-get clean

# Add Firefox repository for latest version
RUN add-apt-repository -y ppa:mozillateam/ppa && \
    echo 'Package: *\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001' > /etc/apt/preferences.d/mozilla-firefox

# Install all packages
RUN apt-get update && apt-get install -y \
    # Display
    xvfb x11vnc \
    # Window manager
    openbox obconf \
    # Apps
    firefox xterm pcmanfm \
    # Utilities
    netcat-openbsd xdotool wmctrl \
    # Fonts
    fonts-liberation fonts-ubuntu fonts-noto \
    # Dependencies
    libgl1-mesa-dri libgl1-mesa-glx \
    libgtk-3-0 libdbus-glib-1-2 \
    libnss3 libxss1 libasound2 \
    pulseaudio pavucontrol \
    # Video
    libavcodec58 libavformat58 libavutil56 libswscale5 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install noVNC
WORKDIR /opt
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O novnc.tar.gz && \
    tar -xzf novnc.tar.gz && \
    mv noVNC-1.4.0 noVNC && \
    rm novnc.tar.gz

RUN wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O websockify.tar.gz && \
    tar -xzf websockify.tar.gz && \
    mv websockify-0.11.0 /opt/noVNC/utils/websockify && \
    rm websockify.tar.gz

# Create startup script
RUN echo '#!/bin/bash\n\
\n\
echo "Starting Xvfb on display $DISPLAY..."\n\
Xvfb $DISPLAY -screen 0 ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x24 -ac +extension GLX +render -noreset &\n\
sleep 2\n\
\n\
echo "Starting VNC server..."\n\
x11vnc -display $DISPLAY -forever -shared -rfbport 5900 -passwd $VNC_PASSWORD -noxdamage -bg\n\
sleep 2\n\
\n\
echo "Starting noVNC..."\n\
/opt/noVNC/utils/novnc_proxy --vnc localhost:5900 --listen 8080 --web /opt/noVNC &\n\
sleep 2\n\
\n\
echo "Starting Openbox..."\n\
openbox &\n\
sleep 1\n\
\n\
echo "Starting desktop..."\n\
pcmanfm --desktop &\n\
sleep 1\n\
\n\
# Create desktop shortcuts\n\
mkdir -p ~/Desktop\n\
cat > ~/Desktop/firefox.desktop <<EOF\n\
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
cat > ~/Desktop/terminal.desktop <<EOF\n\
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
cat > ~/Desktop/filemanager.desktop <<EOF\n\
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
# Set Firefox preferences for better performance\n\
mkdir -p ~/.mozilla/firefox/default\n\
echo '\''{\n\
  "browser.cache.disk.enable": true,\n\
  "browser.cache.memory.enable": true,\n\
  "browser.startup.homepage": "about:blank",\n\
  "media.autoplay.default": 0,\n\
  "media.ffmpeg.vaapi.enabled": true,\n\
  "media.hardware-video-decoding.enabled": true\n\
}'\'' > ~/.mozilla/firefox/default/prefs.js\n\
\n\
echo "=========================================="\n\
echo "VNC Server is running!"\n\
echo "Connect to: http://$(hostname -i):8080/vnc.html"\n\
echo "Password: $VNC_PASSWORD"\n\
echo "=========================================="\n\
\n\
# Start a simple web server on port 10000 for health checks\n\
while true; do\n\
    printf "HTTP/1.1 200 OK\\r\\nContent-Length: 12\\r\\n\\r\\nVNC Ready\\n" | nc -l -p 10000 -q 1\n\
done &\n\
\n\
# Keep container running\n\
tail -f /dev/null' > /start.sh && chmod +x /start.sh

EXPOSE 8080
EXPOSE 10000

CMD ["/start.sh"]
