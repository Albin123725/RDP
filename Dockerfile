FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV RESOLUTION=1920x1080
ENV VNC_PASSWORD=password123
ENV VNC_PORT=5901
ENV NOVNC_PORT=6080

# Install dependencies
RUN apt-get update && apt-get install -y \
    xfce4 \
    xfce4-goodies \
    tightvncserver \
    novnc \
    websockify \
    supervisor \
    firefox \
    xfce4-terminal \
    thunar \
    mousepad \
    ristretto \
    xarchiver \
    net-tools \
    iputils-ping \
    curl \
    wget \
    htop \
    nano \
    git \
    python3 \
    python3-pip \
    # Clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install noVNC
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc \
    && git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify

# Copy configuration files
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start.sh /start.sh

# Set permissions
RUN chmod +x /start.sh

# Create VNC password directory
RUN mkdir -p ~/.vnc \
    && echo "$VNC_PASSWORD" | vncpasswd -f > ~/.vnc/passwd \
    && chmod 600 ~/.vnc/passwd

# Create XFCE autostart directory
RUN mkdir -p /etc/xdg/autostart

# Create xstartup file
RUN echo '#!/bin/bash\n\
unset SESSION_MANAGER\n\
unset DBUS_SESSION_BUS_ADDRESS\n\
startxfce4 &\n' > ~/.vnc/xstartup \
    && chmod +x ~/.vnc/xstartup

# Expose ports
EXPOSE $VNC_PORT
EXPOSE $NOVNC_PORT

# Set working directory
WORKDIR /root

# Start command
CMD ["/start.sh"]
