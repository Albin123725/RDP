FROM debian:bullseye-slim

# Set environment to automatically select English/US during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LANGUAGE=C.UTF-8
ENV LC_ALL=C.UTF-8

# Set keyboard layout configuration
RUN echo 'keyboard-configuration keyboard-configuration/layoutcode string us' > /tmp/debconf.txt && \
    echo 'keyboard-configuration keyboard-configuration/variantcode string' >> /tmp/debconf.txt && \
    echo 'keyboard-configuration keyboard-configuration/modelcode string pc105' >> /tmp/debconf.txt && \
    echo 'keyboard-configuration keyboard-configuration/unsupported_layout boolean true' >> /tmp/debconf.txt && \
    echo 'keyboard-configuration keyboard-configuration/unsupported_config_options boolean true' >> /tmp/debconf.txt && \
    echo 'keyboard-configuration keyboard-configuration/store_defaults_in_debconf_db boolean true' >> /tmp/debconf.txt && \
    echo 'keyboard-configuration keyboard-configuration/ctrl_alt_bksp boolean false' >> /tmp/debconf.txt && \
    echo 'keyboard-configuration keyboard-configuration/optionscode string' >> /tmp/debconf.txt

# Apply keyboard configuration
RUN debconf-set-selections /tmp/debconf.txt && \
    rm /tmp/debconf.txt

# Update and install all packages without prompts
RUN apt-get update && \
    apt-get install -y \
    locales \
    keyboard-configuration \
    console-setup \
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
    echo 'export LANG=en_US.UTF-8' >> /root/.vnc/xstartup && \
    echo 'export LANGUAGE=en_US:en' >> /root/.vnc/xstartup && \
    echo 'export LC_ALL=en_US.UTF-8' >> /root/.vnc/xstartup && \
    echo 'export CHROMIUM_FLAGS="--no-sandbox --disable-dev-shm-usage"' >> /root/.vnc/xstartup && \
    echo 'setxkbmap us' >> /root/.vnc/xstartup && \
    echo 'startxfce4 &' >> /root/.vnc/xstartup && \
    chmod 755 /root/.vnc/xstartup

# Copy start.sh script
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8900

CMD ["/start.sh"]
