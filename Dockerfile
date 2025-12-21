FROM debian:bullseye-slim

# Set environment to automatically select English/US during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV USER=root
ENV HOME=/root
ENV DISPLAY=:1

# Set keyboard layout configuration
RUN echo 'keyboard-configuration keyboard-configuration/layoutcode string us' > /tmp/debconf.txt && \
    echo 'keyboard-configuration keyboard-configuration/variantcode string' >> /tmp/debconf.txt && \
    echo 'keyboard-configuration keyboard-configuration/modelcode string pc105' >> /tmp/debconf.txt

# Apply keyboard configuration
RUN debconf-set-selections /tmp/debconf.txt && \
    rm /tmp/debconf.txt

# Update and install all packages without prompts
RUN apt-get update && \
    apt-get install -y \
    locales \
    keyboard-configuration \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 && \
    apt-get install -y \
    xfce4 xfce4-goodies xfce4-terminal \
    chromium chromium-sandbox \
    firefox-esr \
    wget curl \
    tightvncserver novnc websockify \
    dbus-x11 x11-utils \
    xserver-xorg-core xserver-xorg-video-dummy \
    x11-xserver-utils \
    xauth \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create directories and set permissions
RUN mkdir -p /root/.vnc && \
    mkdir -p /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix

# Set up VNC password
RUN echo 'Albin4242' | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create xstartup for XFCE
RUN echo '#!/bin/bash' > /root/.vnc/xstartup && \
    echo 'unset SESSION_MANAGER' >> /root/.vnc/xstartup && \
    echo 'unset DBUS_SESSION_BUS_ADDRESS' >> /root/.vnc/xstartup && \
    echo 'export DISPLAY=:1' >> /root/.vnc/xstartup && \
    echo 'export LANG=en_US.UTF-8' >> /root/.vnc/xstartup && \
    echo 'export LANGUAGE=en_US:en' >> /root/.vnc/xstartup && \
    echo 'export LC_ALL=en_US.UTF-8' >> /root/.vnc/xstartup && \
    echo 'export CHROMIUM_FLAGS="--no-sandbox --disable-dev-shm-usage"' >> /root/.vnc/xstartup && \
    echo 'xsetroot -solid grey' >> /root/.vnc/xstartup && \
    echo 'xhost +' >> /root/.vnc/xstartup && \
    echo 'exec startxfce4' >> /root/.vnc/xstartup && \
    chmod 755 /root/.vnc/xstartup

# Create Xauthority file
RUN touch /root/.Xauthority && \
    chmod 600 /root/.Xauthority

# Copy start.sh script
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8900

CMD ["/start.sh"]
