FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV USER=root
ENV HOME=/root
ENV DISPLAY=:99

# Install all required packages including locales
RUN apt-get update && \
    apt-get install -y \
    locales \
    xfce4 xfce4-goodies xfce4-terminal \
    chromium chromium-sandbox \
    firefox-esr \
    wget curl \
    tightvncserver novnc websockify \
    dbus-x11 x11-utils \
    xvfb x11vnc \
    netcat-openbsd \
    xfonts-base xfonts-100dpi xfonts-75dpi xfonts-cyrillic \
    && rm -rf /var/lib/apt/lists/*

# Generate locales
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8

# Set up VNC
RUN mkdir -p /root/.vnc && \
    echo 'Albin4242' | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create simple xstartup
RUN echo '#!/bin/bash' > /root/.vnc/xstartup && \
    echo 'unset SESSION_MANAGER' >> /root/.vnc/xstartup && \
    echo 'unset DBUS_SESSION_BUS_ADDRESS' >> /root/.vnc/xstartup && \
    echo 'xrdb $HOME/.Xresources' >> /root/.vnc/xstartup && \
    echo 'startxfce4 &' >> /root/.vnc/xstartup && \
    chmod 755 /root/.vnc/xstartup

# Create .Xresources
RUN echo 'Xft.dpi: 96' > /root/.Xresources && \
    echo 'Xft.antialias: true' >> /root/.Xresources && \
    echo 'Xft.hinting: true' >> /root/.Xresources && \
    echo 'Xft.rgba: rgb' >> /root/.Xresources && \
    echo 'Xft.hintstyle: hintslight' >> /root/.Xresources

# Create startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8900

CMD ["/start.sh"]
