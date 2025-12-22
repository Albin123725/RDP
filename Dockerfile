FROM debian:latest

# Install all required dependencies in one go
RUN apt update && apt install -y \
    wget \
    tar \
    curl \
    git \
    dbus \
    dbus-x11 \
    xfce4 \
    xfce4-terminal \
    tightvncserver \
    firefox-esr \
    net-tools \
    procps \
    sudo \
    x11-xserver-utils \
    xvfb \
    x11vnc \
    fluxbox \
    xterm \
    python3 \
    python3-numpy \
    && rm -rf /var/lib/apt/lists/*

# Install wine and i386 architecture
RUN dpkg --add-architecture i386 && \
    apt update && \
    DEBIAN_FRONTEND=noninteractive apt install -y \
    wine \
    wine32 \
    && rm -rf /var/lib/apt/lists/*

# Download and setup noVNC
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.2.0.tar.gz && \
    tar -xzf v1.2.0.tar.gz && \
    rm v1.2.0.tar.gz && \
    # Install websockify dependencies
    apt update && apt install -y python3-websockify && \
    rm -rf /var/lib/apt/lists/*

# Create VNC directory and setup
RUN mkdir -p /root/.vnc && \
    echo "admin123@a" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create xstartup for VNC
RUN echo '#!/bin/bash' > /root/.vnc/xstartup && \
    echo 'export USER=root' >> /root/.vnc/xstartup && \
    echo 'export HOME=/root' >> /root/.vnc/xstartup && \
    echo 'unset SESSION_MANAGER' >> /root/.vnc/xstartup && \
    echo 'unset DBUS_SESSION_BUS_ADDRESS' >> /root/.vnc/xstartup && \
    echo 'exec startxfce4' >> /root/.vnc/xstartup && \
    chmod 755 /root/.vnc/xstartup

# Create startup script
RUN echo '#!/bin/bash' > /start.sh && \
    echo '' >> /start.sh && \
    echo '# Set environment variables' >> /start.sh && \
    echo 'export USER=root' >> /start.sh && \
    echo 'export HOME=/root' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start DBus' >> /start.sh && \
    echo 'mkdir -p /var/run/dbus' >> /start.sh && \
    echo 'dbus-daemon --system --fork' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Prepare X11 directory' >> /start.sh && \
    echo 'mkdir -p /tmp/.X11-unix' >> /start.sh && \
    echo 'chmod 1777 /tmp/.X11-unix' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start Xvfb in background' >> /start.sh && \
    echo 'Xvfb :99 -screen 0 1360x768x24 -ac +extension GLX +render -noreset &' >> /start.sh && \
    echo 'export DISPLAY=:99' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Wait for Xvfb' >> /start.sh && \
    echo 'sleep 2' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start xfce4 session in background' >> /start.sh && \
    echo 'startxfce4 &' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Wait for desktop to start' >> /start.sh && \
    echo 'sleep 3' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start x11vnc server' >> /start.sh && \
    echo 'x11vnc -display :99 -forever -shared -rfbport 5900 -passwd admin123@a -bg -noxdamage' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start noVNC' >> /start.sh && \
    echo 'cd /noVNC-1.2.0' >> /start.sh && \
    echo 'python3 ./utils/novnc_proxy --vnc localhost:5900 --listen 8080 --web ./' >> /start.sh && \
    chmod +x /start.sh

# Alternative simpler startup script
RUN echo '#!/bin/bash' > /start-simple.sh && \
    echo '' >> /start-simple.sh && \
    echo '# Set environment variables' >> /start-simple.sh && \
    echo 'export USER=root' >> /start-simple.sh && \
    echo 'export HOME=/root' >> /start-simple.sh && \
    echo '' >> /start-simple.sh && \
    echo '# Start DBus' >> /start-simple.sh && \
    echo 'mkdir -p /var/run/dbus' >> /start-simple.sh && \
    echo 'dbus-daemon --system --fork' >> /start-simple.sh && \
    echo '' >> /start-simple.sh && \
    echo '# Start VNC server directly' >> /start-simple.sh && \
    echo 'vncserver :1 -geometry 1360x768 -depth 24' >> /start-simple.sh && \
    echo '' >> /start-simple.sh && \
    echo '# Start noVNC' >> /start-simple.sh && \
    echo 'cd /noVNC-1.2.0' >> /start-simple.sh && \
    echo 'python3 ./utils/novnc_proxy --vnc localhost:5901 --listen 8080 --web ./' >> /start-simple.sh && \
    chmod +x /start-simple.sh

EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

CMD ["/bin/bash", "/start-simple.sh"]
