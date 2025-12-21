FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    VNC_PORT=5901 \
    WEB_PORT=8080 \
    RESOLUTION=1360x768x24 \
    VNC_PASSWORD=Albin4242

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    sudo \
    curl \
    wget \
    git \
    unzip \
    net-tools \
    xvfb \
    x11vnc \
    xfce4 \
    xfce4-terminal \
    xfce4-goodies \
    firefox \
    novnc \
    websockify \
    supervisor \
    nginx \
    dbus-x11 \
    pulseaudio \
    tigervnc-standalone-server \
    tigervnc-common \
    tigervnc-xorg-extension \
    fonts-wqy-zenhei \
    xfonts-base \
    xfonts-terminus \
    htop \
    nano \
    vim && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash appuser && \
    echo "appuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p /home/appuser/.vnc && \
    mkdir -p /home/appuser/.config/xfce4/xfconf/xfce-perchannel-xml && \
    chown -R appuser:appuser /home/appuser

# Install noVNC
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /usr/share/ && \
    mv /usr/share/noVNC-1.4.0 /usr/share/novnc && \
    ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html && \
    rm /tmp/novnc.tar.gz

# Install websockify for noVNC
RUN wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O /tmp/websockify.tar.gz && \
    tar -xzf /tmp/websockify.tar.gz -C /usr/share/novnc/utils/ && \
    mv /usr/share/novnc/utils/websockify-0.11.0 /usr/share/novnc/utils/websockify && \
    rm /tmp/websockify.tar.gz

# Set up VNC password
RUN echo "$VNC_PASSWORD" | vncpasswd -f > /home/appuser/.vnc/passwd && \
    chmod 600 /home/appuser/.vnc/passwd && \
    chown appuser:appuser /home/appuser/.vnc/passwd

# Create xstartup script for VNC
RUN echo '#!/bin/bash\n\
unset SESSION_MANAGER\n\
unset DBUS_SESSION_BUS_ADDRESS\n\
export PULSE_SERVER=tcp:localhost:4713\n\
export DISPLAY=:1\n\
startxfce4 &\n\
' > /home/appuser/.vnc/xstartup && \
    chmod +x /home/appuser/.vnc/xstartup && \
    chown -R appuser:appuser /home/appuser/.vnc

# Copy configuration files
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY nginx.conf /etc/nginx/sites-available/default
COPY start.sh /start.sh

# Set up xfce4 configuration
COPY xfce4-desktop.xml /home/appuser/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
RUN chown -R appuser:appuser /home/appuser/.config

# Create directory for X11
RUN mkdir -p /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix && \
    chown root:root /tmp/.X11-unix

# Set up nginx
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Expose ports
EXPOSE 8080
EXPOSE 80

# Set permissions
RUN chmod +x /start.sh

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Start command
CMD ["/start.sh"]
