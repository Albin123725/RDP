FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    VNC_PASSWD=password123 \
    RESOLUTION=1024x768

# Install minimal packages
RUN apt-get update && apt-get install -y \
    x11vnc \
    xvfb \
    fluxbox \
    xterm \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Download noVNC
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt && \
    mv /opt/noVNC-1.4.0 /opt/novnc && \
    rm /tmp/novnc.tar.gz

EXPOSE 8080

# Create a single startup script
CMD echo "Starting VNC Desktop..." && \
    # Start X virtual framebuffer
    Xvfb :1 -screen 0 ${RESOLUTION}x24 & \
    sleep 2 && \
    # Set display
    export DISPLAY=:1 && \
    # Start window manager
    fluxbox & \
    sleep 2 && \
    # Start terminal
    xterm -geometry 80x24+10+10 & \
    sleep 2 && \
    # Start VNC server AND noVNC in the same process
    x11vnc -display :1 -forever -shared -nopw -localhost no -rfbport 5901 & \
    sleep 2 && \
    # Use websockify to proxy VNC to web
    websockify --web /opt/novnc 8080 localhost:5901
