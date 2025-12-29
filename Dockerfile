# Dockerfile - WORKING VERSION
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV HOME=/root
ENV DISPLAY=:99
ENV RESOLUTION=1280x720x24
ENV VNC_PASSWORD=password123

# Install only essential packages that definitely exist
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # Core display
    xvfb x11vnc \
    # Window manager
    openbox \
    # Terminal
    xterm \
    # Browser
    firefox \
    # File manager
    pcmanfm \
    # Utilities
    wget curl netcat-openbsd \
    # Basic fonts
    fonts-liberation fonts-dejavu-core \
    # Firefox dependencies
    libgtk-3-0 libdbus-glib-1-2 \
    libnss3 libxss1 libasound2 \
    # Video support
    libavcodec58 libavformat58 libavutil56 libswscale5 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/*

# Install noVNC from release (more reliable than git)
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt && \
    mv /opt/noVNC-1.4.0 /opt/noVNC && \
    wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O /tmp/websockify.tar.gz && \
    tar -xzf /tmp/websockify.tar.gz -C /opt/noVNC/utils && \
    mv /opt/noVNC/utils/websockify-0.11.0 /opt/noVNC/utils/websockify && \
    rm /tmp/*.tar.gz

# Create startup script
RUN echo '#!/bin/bash\n\
# Set up virtual display\n\
Xvfb $DISPLAY -screen 0 ${RESOLUTION} -ac +extension GLX +render -noreset > /dev/null 2>&1 &\n\
\n\
# Start VNC server\n\
x11vnc -display $DISPLAY -forever -shared -rfbport 5900 -passwd $VNC_PASSWORD -noxdamage > /dev/null 2>&1 &\n\
\n\
# Start noVNC\n\
/opt/noVNC/utils/novnc_proxy --vnc localhost:5900 --listen 8080 --web /opt/noVNC > /dev/null 2>&1 &\n\
\n\
# Wait a moment\n\
sleep 2\n\
\n\
# Start Openbox window manager\n\
openbox --config-file /etc/xdg/openbox/rc.xml > /dev/null 2>&1 &\n\
\n\
# Start file manager as desktop\n\
pcmanfm --desktop > /dev/null 2>&1 &\n\
\n\
# Create simple web page for health checks\n\
mkdir -p /opt/www\n\
echo "<html><body><h1>VNC Ready</h1><p>Access at: <a href=\"/vnc.html\">/vnc.html</a></p><p>Password: $VNC_PASSWORD</p></body></html>" > /opt/www/index.html\n\
\n\
# Start a simple web server on port 10000 for Render health checks\n\
while true; do\n\
    echo -e "HTTP/1.1 200 OK\\nContent-Length: $(wc -c < /opt/www/index.html)\\nContent-Type: text/html\\n\\n$(cat /opt/www/index.html)" | nc -l -p 10000 -q 1\n\
done > /dev/null 2>&1 &\n\
\n\
echo "=========================================="\n\
echo "   Novnc RDP is Ready!"\n\
echo "=========================================="\n\
echo "Access URL: Your Render URL/vnc.html"\n\
echo "Password: $VNC_PASSWORD"\n\
echo "Applications: Firefox, Terminal, File Manager"\n\
echo "=========================================="\n\
\n\
# Keep container running\n\
tail -f /dev/null' > /start.sh && chmod +x /start.sh

# Create health check script for Render
RUN echo '#!/bin/bash\n\
# Check if VNC is running\n\
if pgrep -x "x11vnc" > /dev/null && pgrep -x "Xvfb" > /dev/null; then\n\
    exit 0\n\
else\n\
    exit 1\n\
fi' > /healthcheck.sh && chmod +x /healthcheck.sh

EXPOSE 8080
EXPOSE 10000

CMD ["/start.sh"]
