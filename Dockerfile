FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV RESOLUTION=1280x720
ENV VNC_PASSWORD=vncpassword
ENV TZ=UTC

# Install packages
RUN apt-get update && apt-get install -y \
    xfce4 \
    xfce4-goodies \
    tigervnc-standalone-server \
    tigervnc-common \
    novnc \
    websockify \
    supervisor \
    xfce4-terminal \
    firefox-esr \
    thunar \
    curl \
    wget \
    htop \
    nano \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create VNC directory and password
RUN mkdir -p /root/.vnc
RUN echo "$VNC_PASSWORD" | vncpasswd -f > /root/.vnc/passwd
RUN chmod 600 /root/.vnc/passwd

# Create xstartup
RUN echo '#!/bin/bash\n\
unset SESSION_MANAGER\n\
unset DBUS_SESSION_BUS_ADDRESS\n\
exec startxfce4' > /root/.vnc/xstartup \
    && chmod +x /root/.vnc/xstartup

# Create health endpoint
RUN mkdir -p /opt/novnc/health
RUN echo "Desktop is running" > /opt/novnc/health/index.html

# Copy configs
COPY supervisord.conf /etc/supervisor/conf.d/
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 5901 6080 8080

CMD ["/start.sh"]
