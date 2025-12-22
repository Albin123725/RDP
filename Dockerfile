FROM debian:latest

# Install required packages
RUN apt update && apt install -y \
    wget \
    tar \
    curl \
    git \
    dbus \
    dbus-x11 \
    xfce4 \
    xfce4-terminal \
    tigervnc-standalone-server \
    tigervnc-common \
    firefox-esr \
    python3 \
    python3-websockify \
    net-tools \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Install wine
RUN dpkg --add-architecture i386 && \
    apt update && \
    DEBIAN_FRONTEND=noninteractive apt install -y \
    wine \
    wine32 \
    && rm -rf /var/lib/apt/lists/*

# Download and extract noVNC
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.2.0.tar.gz && \
    tar -xzf v1.2.0.tar.gz && \
    rm v1.2.0.tar.gz && \
    mv /noVNC-1.2.0 /noVNC

# Setup VNC
RUN mkdir -p /root/.vnc && \
    echo "admin123@a" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create xstartup file
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
    echo '# Clean up any previous locks' >> /start.sh && \
    echo 'rm -f /tmp/.X1-lock' >> /start.sh && \
    echo 'rm -f /tmp/.X11-unix/X1' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Kill any existing VNC servers' >> /start.sh && \
    echo 'vncserver -kill :1 2>/dev/null || true' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start DBus' >> /start.sh && \
    echo 'dbus-daemon --system --fork' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start VNC server' >> /start.sh && \
    echo 'vncserver :1 -geometry 1360x768 -depth 24 -localhost no' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Wait for VNC to start' >> /start.sh && \
    echo 'sleep 3' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start noVNC proxy' >> /start.sh && \
    echo 'cd /noVNC' >> /start.sh && \
    echo 'python3 ./utils/novnc_proxy --vnc localhost:5901 --listen 8080' >> /start.sh && \
    chmod +x /start.sh

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

CMD ["/bin/bash", "/start.sh"]
