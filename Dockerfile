FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV VNC_PASSWORD=vncpassword
ENV RESOLUTION=1280x720

# Install packages with proper ordering
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository ppa:mozillateam/ppa \
    && apt-get update && \
    apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-goodies \
    tightvncserver \
    wget \
    curl \
    net-tools \
    python3 \
    python3-numpy \
    websockify \
    supervisor \
    firefox \
    xfce4-terminal \
    thunar \
    htop \
    nano \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create VNC directory and password
RUN mkdir -p /root/.vnc && \
    echo "$VNC_PASSWORD" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create xstartup file
RUN echo '#!/bin/bash\n\
unset SESSION_MANAGER\n\
unset DBUS_SESSION_BUS_ADDRESS\n\
exec startxfce4' > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# Clone noVNC
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc && \
    git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify && \
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 5901 6080 8080

CMD ["/start.sh"]
