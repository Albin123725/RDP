FROM debian:latest

# Install required dependencies
RUN apt update && apt install -y \
    wget \
    tar \
    xz-utils \
    curl \
    git \
    dbus \
    dbus-x11 \
    x11-apps \
    xfce4 \
    xfce4-terminal \
    tightvncserver \
    novnc \
    websockify \
    firefox-esr \
    gnome-system-monitor \
    mate-system-monitor \
    net-tools \
    iproute2 \
    procps \
    sudo \
    xfonts-base \
    xfonts-100dpi \
    xfonts-75dpi \
    xfonts-scalable \
    x11-xserver-utils \
    xserver-xorg-video-dummy \
    xserver-xorg-core \
    && rm -rf /var/lib/apt/lists/*

# Install wine and i386 architecture
RUN dpkg --add-architecture i386 && \
    apt update && \
    DEBIAN_FRONTEND=noninteractive apt install -y \
    wine \
    wine32 \
    && rm -rf /var/lib/apt/lists/*

# Create VNC directory and setup
RUN mkdir -p /root/.vnc && \
    echo "admin123@a" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create xstartup for VNC
RUN echo '#!/bin/bash' > /root/.vnc/xstartup && \
    echo 'unset SESSION_MANAGER' >> /root/.vnc/xstartup && \
    echo 'unset DBUS_SESSION_BUS_ADDRESS' >> /root/.vnc/xstartup && \
    echo 'export PULSE_SERVER=/tmp/pulse.sock' >> /root/.vnc/xstartup && \
    echo 'exec startxfce4' >> /root/.vnc/xstartup && \
    chmod 755 /root/.vnc/xstartup

# Download and setup noVNC
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.2.0.tar.gz && \
    tar -xzf v1.2.0.tar.gz && \
    rm v1.2.0.tar.gz && \
    ln -s /noVNC-1.2.0 /usr/share/novnc

# Create startup script
RUN echo '#!/bin/bash' > /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start DBus' >> /start.sh && \
    echo 'mkdir -p /var/run/dbus' >> /start.sh && \
    echo 'dbus-daemon --system --fork' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Prepare X11 directory' >> /start.sh && \
    echo 'mkdir -p /tmp/.X11-unix' >> /start.sh && \
    echo 'chmod 1777 /tmp/.X11-unix' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Set up display' >> /start.sh && \
    echo 'export DISPLAY=:99' >> /start.sh && \
    echo 'Xvfb :99 -screen 0 1360x768x24 &' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start VNC server' >> /start.sh && \
    echo 'vncserver :2000 -geometry 1360x768 -depth 24 -SecurityTypes None -localhost no' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start noVNC' >> /start.sh && \
    echo 'cd /noVNC-1.2.0' >> /start.sh && \
    echo './utils/novnc_proxy --vnc localhost:5900 --listen 8900 &' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Keep container running' >> /start.sh && \
    echo 'tail -f /dev/null' >> /start.sh && \
    chmod +x /start.sh

# Create alternative script using xrdp
RUN echo '#!/bin/bash' > /start-xrdp.sh && \
    echo '' >> /start-xrdp.sh && \
    echo '# Install xrdp if not present' >> /start-xrdp.sh && \
    echo 'if ! command -v xrdp &> /dev/null; then' >> /start-xrdp.sh && \
    echo '    apt update && apt install -y xrdp' >> /start-xrdp.sh && \
    echo 'fi' >> /start-xrdp.sh && \
    echo '' >> /start-xrdp.sh && \
    echo '# Start DBus' >> /start-xrdp.sh && \
    echo 'mkdir -p /var/run/dbus' >> /start-xrdp.sh && \
    echo 'dbus-daemon --system --fork' >> /start-xrdp.sh && \
    echo '' >> /start-xrdp.sh && \
    echo '# Prepare X11 directory' >> /start-xrdp.sh && \
    echo 'mkdir -p /tmp/.X11-unix' >> /start-xrdp.sh && \
    echo 'chmod 1777 /tmp/.X11-unix' >> /start-xrdp.sh && \
    echo '' >> /start-xrdp.sh && \
    echo '# Start xrdp' >> /start-xrdp.sh && \
    echo '/usr/sbin/xrdp --nodaemon &' >> /start-xrdp.sh && \
    echo '/usr/sbin/xrdp-sesman --nodaemon &' >> /start-xrdp.sh && \
    echo '' >> /start-xrdp.sh && \
    echo '# Start VNC for xrdp' >> /start-xrdp.sh && \
    echo 'export DISPLAY=:10' >> /start-xrdp.sh && \
    echo 'Xvfb :10 -screen 0 1360x768x24 &' >> /start-xrdp.sh && \
    echo 'sleep 2' >> /start-xrdp.sh && \
    echo 'startxfce4 &' >> /start-xrdp.sh && \
    echo '' >> /start-xrdp.sh && \
    echo '# Start noVNC' >> /start-xrdp.sh && \
    echo 'cd /noVNC-1.2.0' >> /start-xrdp.sh && \
    echo './utils/novnc_proxy --vnc localhost:5900 --listen 8900 &' >> /start-xrdp.sh && \
    echo '' >> /start-xrdp.sh && \
    echo '# Keep container running' >> /start-xrdp.sh && \
    echo 'tail -f /dev/null' >> /start-xrdp.sh && \
    chmod +x /start-xrdp.sh

# Expose ports
EXPOSE 8900 3389 5900

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8900/ || exit 1

# Start the service
CMD ["/bin/bash", "/start.sh"]
