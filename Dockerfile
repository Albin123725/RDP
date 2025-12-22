FROM ubuntu:22.04

# Use Render's PORT environment variable
ARG RENDER_PORT=10000
ENV RENDER_EXTERNAL_PORT=${RENDER_PORT}
ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV RESOLUTION=1280x720
ENV VNC_PASSWORD=vncpassword

# Critical: Match Render's internal port
ENV PORT=10000

# Install packages
RUN apt-get update && apt-get install -y \
    xfce4 \
    xfce4-goodies \
    tigervnc-standalone-server \
    novnc \
    websockify \
    supervisor \
    curl \
    wget \
    x11-xserver-utils \
    && rm -rf /var/lib/apt/lists/*

# Setup VNC
RUN mkdir -p /root/.vnc && \
    echo "${VNC_PASSWORD}" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create xstartup
RUN echo '#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4' > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# Clone noVNC
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc && \
    git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify && \
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# Create startup script for Render
COPY start-render.sh /start-render.sh
RUN chmod +x /start-render.sh

# Create health check endpoint
RUN mkdir -p /opt/novnc/health && \
    echo "OK" > /opt/novnc/health/index.html

# Expose the Render port
EXPOSE ${PORT}

CMD ["/start-render.sh"]
