FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:99 \
    VNC_PASSWORD=password123 \
    RESOLUTION=1280x720x24 \
    HOME=/root \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Update and install minimal packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # Core display
    xvfb \
    # VNC server
    x11vnc \
    # Window manager (minimal)
    fluxbox \
    # Applications
    firefox \
    xterm \
    pcmanfm \
    # Utilities
    wget \
    curl \
    netcat-openbsd \
    # Dependencies
    libgl1-mesa-dri \
    libgl1-mesa-glx \
    libgtk-3-0 \
    libnss3 \
    libasound2 \
    libxss1 \
    # Fonts
    fonts-liberation \
    # Audio (optional)
    pulseaudio \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install noVNC (simpler method)
WORKDIR /tmp
RUN wget -q https://github.com/novnc/noVNC/archive/v1.4.0.tar.gz && \
    tar -xzf v1.4.0.tar.gz && \
    mv noVNC-1.4.0 /opt/noVNC && \
    wget -q https://github.com/novnc/websockify/archive/v0.11.0.tar.gz && \
    tar -xzf v0.11.0.tar.gz && \
    mv websockify-0.11.0 /opt/noVNC/utils/websockify && \
    rm -f *.tar.gz

# Create a simple startup script
RUN echo '#!/bin/bash\n\
\n\
# Kill any existing processes\n\
pkill -9 Xvfb 2>/dev/null\n\
pkill -9 x11vnc 2>/dev/null\n\
\n\
# Start X virtual framebuffer\n\
echo "Starting Xvfb..."\n\
Xvfb $DISPLAY -screen 0 ${RESOLUTION} -ac +extension GLX +render -noreset > /dev/null 2>&1 &\n\
sleep 2\n\
\n\
# Start VNC server\n\
echo "Starting VNC server..."\n\
x11vnc -display $DISPLAY -forever -shared -rfbport 5900 -passwd $VNC_PASSWORD -noxdamage -bg > /dev/null 2>&1\n\
sleep 2\n\
\n\
# Start noVNC\n\
echo "Starting noVNC web interface..."\n\
cd /opt/noVNC\n\
./utils/novnc_proxy --vnc localhost:5900 --listen 8080 > /dev/null 2>&1 &\n\
sleep 2\n\
\n\
# Start window manager\n\
echo "Starting Fluxbox..."\n\
fluxbox > /dev/null 2>&1 &\n\
sleep 1\n\
\n\
# Start file manager as desktop\n\
echo "Starting desktop..."\n\
pcmanfm --desktop > /dev/null 2>&1 &\n\
sleep 1\n\
\n\
# Create simple index.html\n\
mkdir -p /opt/www\n\
cat > /opt/www/index.html << EOF\n\
<!DOCTYPE html>\n\
<html>\n\
<head>\n\
    <title>VNC Remote Desktop</title>\n\
    <style>\n\
        body { font-family: Arial, sans-serif; margin: 40px; }\n\
        .container { max-width: 800px; margin: 0 auto; }\n\
        .btn { display: inline-block; padding: 12px 24px; background: #007bff; color: white; text-decoration: none; border-radius: 4px; margin: 10px; }\n\
        .btn:hover { background: #0056b3; }\n\
    </style>\n\
</head>\n\
<body>\n\
    <div class="container">\n\
        <h1>🎮 Remote Desktop Ready!</h1>\n\
        <p>Your VNC remote desktop is running and ready to use.</p>\n\
        \n\
        <h2>📱 Access Options:</h2>\n\
        <p>\n\
            <a href="/vnc.html" class="btn">Launch VNC Client</a>\n\
            <a href="/vnc.html?autoconnect=true" class="btn">Auto-connect VNC</a>\n\
        </p>\n\
        \n\
        <h2>🔑 Connection Details:</h2>\n\
        <ul>\n\
            <li><strong>Password:</strong> password123</li>\n\
            <li><strong>Resolution:</strong> 1280x720</li>\n\
            <li><strong>Applications:</strong> Firefox, Terminal, File Manager</li>\n\
        </ul>\n\
        \n\
        <h2>⚠️ Important Notes:</h2>\n\
        <ul>\n\
            <li>First connection may take 30-60 seconds (Render free tier cold start)</li>\n\
            <li>If VNC doesn't load, wait 1 minute and refresh</li>\n\
            <li>For best performance, close unused browser tabs</li>\n\
        </ul>\n\
        \n\
        <h2>🔧 Troubleshooting:</h2>\n\
        <p>If you see "Bad Gateway":</p>\n\
        <ol>\n\
            <li>Wait 2-3 minutes for full startup</li>\n\
            <li>Refresh the page</li>\n\
            <li>Clear browser cache</li>\n\
            <li>Try direct link: <a href="/vnc.html?host=\$(hostname)&port=443&path=vnc.html">Direct Connect</a></li>\n\
        </ol>\n\
    </div>\n\
</body>\n\
</html>\n\
EOF\n\
\n\
# Start a simple web server on port 10000\n\
echo "Starting web server..."\n\
while true; do\n\
    cd /opt/www\n\
    echo -e "HTTP/1.1 200 OK\\r\\nContent-Type: text/html\\r\\n\\r\\n" | cat - index.html | nc -l -p 10000 -q 1\n\
done > /dev/null 2>&1 &\n\
\n\
echo "=========================================="\n\
echo "✅ VNC Service Started Successfully!"\n\
echo "🌐 Access at: https://your-domain.onrender.com/"\n\
echo "🔗 VNC Client: /vnc.html"\n\
echo "🔑 Password: $VNC_PASSWORD"\n\
echo "💻 Apps: Firefox, Terminal, File Manager"\n\
echo "=========================================="\n\
\n\
# Keep container alive\n\
while true; do\n\
    sleep 3600\n\
done' > /start.sh && chmod +x /start.sh

# Expose ports
EXPOSE 8080
EXPOSE 10000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:10000/ || exit 1

CMD ["/start.sh"]
