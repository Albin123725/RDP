FROM debian:bullseye-slim

RUN apt-get update && \
    apt-get install -y \
    xfce4 xfce4-goodies xfce4-terminal \
    chromium chromium-sandbox \
    firefox-esr \
    wget curl \
    tightvncserver novnc websockify \
    dbus-x11 x11-utils \
    && rm -rf /var/lib/apt/lists/*

# Set up VNC
RUN mkdir -p /root/.vnc && \
    echo 'Albin4242' | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create xstartup for XFCE
RUN echo '#!/bin/bash' > /root/.vnc/xstartup && \
    echo 'unset SESSION_MANAGER' >> /root/.vnc/xstartup && \
    echo 'unset DBUS_SESSION_BUS_ADDRESS' >> /root/.vnc/xstartup && \
    echo 'export DISPLAY=:1' >> /root/.vnc/xstartup && \
    echo 'export CHROMIUM_FLAGS="--no-sandbox --disable-dev-shm-usage"' >> /root/.vnc/xstartup && \
    echo 'startxfce4 &' >> /root/.vnc/xstartup && \
    chmod 755 /root/.vnc/xstartup

# Copy start.sh script
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8900

CMD ["/start.sh"]
