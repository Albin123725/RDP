FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    VNC_PORT=5901 \
    WEB_PORT=8080 \
    RESOLUTION=1360x768x24 \
    VNC_PASSWORD=Albin4242

# Install all dependencies including vncserver
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
    tightvncserver \
    tightvncpasswd \
    tigervnc-standalone-server \
    tigervnc-common \
    tigervnc-xorg-extension \
    tigervnc-viewer \
    fonts-wqy-zenhei \
    xfonts-base \
    xfonts-terminus \
    htop \
    nano \
    vim \
    x11-utils \
    x11-xserver-utils \
    xinit \
    xserver-xorg-core \
    xserver-xorg-video-dummy \
    xterm \
    && apt-get clean && \
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

# Set up VNC password using x11vnc (which is already installed)
RUN mkdir -p /home/appuser/.vnc && \
    echo "$VNC_PASSWORD" > /tmp/vncpasswd_input && \
    x11vnc -storepasswd $(cat /tmp/vncpasswd_input) /home/appuser/.vnc/passwd && \
    rm /tmp/vncpasswd_input && \
    chmod 600 /home/appuser/.vnc/passwd && \
    chown appuser:appuser /home/appuser/.vnc/passwd

# Alternative: Create password file manually (simpler)
RUN mkdir -p /home/appuser/.vnc && \
    echo -e "#!/bin/sh\nunset SESSION_MANAGER\nunset DBUS_SESSION_BUS_ADDRESS\nexec /usr/bin/startxfce4" > /home/appuser/.vnc/xstartup && \
    chmod +x /home/appuser/.vnc/xstartup && \
    echo "$VNC_PASSWORD" | vncpasswd -f > /home/appuser/.vnc/passwd 2>/dev/null || \
    echo "$VNC_PASSWORD" > /home/appuser/.vnc/passwd && \
    chmod 600 /home/appuser/.vnc/passwd && \
    chown -R appuser:appuser /home/appuser/.vnc

# Create xstartup script for VNC
RUN echo '#!/bin/bash\n\
unset SESSION_MANAGER\n\
unset DBUS_SESSION_BUS_ADDRESS\n\
export PULSE_SERVER=tcp:localhost:4713\n\
export DISPLAY=:1\n\
/usr/bin/startxfce4 &\n\
' > /home/appuser/.vnc/xstartup && \
    chmod +x /home/appuser/.vnc/xstartup && \
    chown -R appuser:appuser /home/appuser/.vnc

# Copy configuration files
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY nginx.conf /etc/nginx/sites-available/default
COPY start.sh /start.sh

# Create xfce4 configuration directory if needed
RUN mkdir -p /home/appuser/.config/xfce4/xfconf/xfce-perchannel-xml && \
    echo '<?xml version="1.0" encoding="UTF-8"?>\n\
<channel name="xfce4-desktop" version="1.0">\n\
  <property name="backdrop" type="empty">\n\
    <property name="screen0" type="empty">\n\
      <property name="monitor0" type="empty">\n\
        <property name="workspace0" type="empty">\n\
          <property name="last-image" type="string" value="/usr/share/backgrounds/xfce/xfce-verticals.png"/>\n\
        </property>\n\
      </property>\n\
    </property>\n\
  </property>\n\
</channel>' > /home/appuser/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml && \
    chown -R appuser:appuser /home/appuser/.config

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
