FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV VNC_PASSWORD=password123
ENV DISPLAY=:1
ENV RESOLUTION=1024x768x16

# Install packages - avoid snap for chromium
RUN apt update && apt install -y \
    x11vnc \
    xvfb \
    fluxbox \
    wget \
    python3 \
    python3-pip \
    # Install chromium-browser from deb package, not snap
    chromium-browser \
    chromium-chromedriver \
    # X11 utilities
    x11-utils \
    xterm \
    # Fonts
    xfonts-base \
    fonts-liberation \
    --no-install-recommends && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

# Install websockify via pip
RUN pip3 install websockify numpy

# Download noVNC 1.2.0 (stable)
RUN wget -q https://github.com/novnc/noVNC/archive/v1.2.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt/ && \
    mv /opt/noVNC-1.2.0 /opt/novnc && \
    rm /tmp/novnc.tar.gz

# Set VNC password
RUN mkdir -p ~/.vnc && \
    x11vnc -storepasswd ${VNC_PASSWORD} ~/.vnc/passwd

# Create fluxbox config to suppress warnings
RUN mkdir -p ~/.fluxbox && \
    echo 'session.screen0.workspaces: 1' > ~/.fluxbox/init && \
    echo 'session.screen0.toolbar.visible: false' >> ~/.fluxbox/init && \
    echo 'session.screen0.toolbar.alpha: 255' >> ~/.fluxbox/init

# Create startup script
RUN cat > /start.sh << 'EOF'
#!/bin/bash

echo "=== Starting VNC Desktop ==="

# Start Xvfb
echo "Starting X virtual framebuffer..."
Xvfb ${DISPLAY} -screen 0 ${RESOLUTION} &
XVFB_PID=$!
sleep 3

# Start fluxbox
echo "Starting window manager..."
fluxbox &
sleep 2

# Start x11vnc
echo "Starting VNC server..."
x11vnc -display ${DISPLAY} -forever -shared -rfbauth ~/.vnc/passwd -bg

# Start browser
echo "Starting browser..."
# Use --no-sandbox flag for Chrome in containers
chromium-browser --no-sandbox --disable-dev-shm-usage --window-size=1024,768 about:blank &
sleep 3

# Start noVNC
echo "Starting noVNC web interface..."
cd /opt/novnc
websockify --web=. 8080 localhost:5900

wait $XVFB_PID
EOF

RUN chmod +x /start.sh

EXPOSE 8080

CMD /start.sh
