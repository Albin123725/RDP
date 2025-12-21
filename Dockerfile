FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV USER=root
ENV HOME=/root
ENV DISPLAY=:99
ENV CHROMIUM_FLAGS="--no-sandbox --disable-dev-shm-usage --disable-setuid-sandbox --disable-gpu"

# Install all required packages
RUN apt-get update && \
    apt-get install -y \
    locales \
    xfce4 xfce4-goodies xfce4-terminal \
    chromium chromium-sandbox \
    firefox-esr \
    wget curl \
    novnc websockify \
    dbus-x11 x11-utils \
    xvfb x11vnc \
    netcat-openbsd \
    xfonts-base xfonts-100dpi xfonts-75dpi xfonts-cyrillic \
    && rm -rf /var/lib/apt/lists/*

# Generate locales
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8

# Create desktop directory
RUN mkdir -p /root/Desktop

# Create desktop shortcuts
RUN echo '[Desktop Entry]' > /root/Desktop/chromium.desktop && \
    echo 'Version=1.0' >> /root/Desktop/chromium.desktop && \
    echo 'Name=Chromium Browser' >> /root/Desktop/chromium.desktop && \
    echo 'Comment=Browse the web' >> /root/Desktop/chromium.desktop && \
    echo 'Exec=chromium --no-sandbox --disable-dev-shm-usage --disable-setuid-sandbox --disable-gpu' >> /root/Desktop/chromium.desktop && \
    echo 'Icon=chromium' >> /root/Desktop/chromium.desktop && \
    echo 'Terminal=false' >> /root/Desktop/chromium.desktop && \
    echo 'Type=Application' >> /root/Desktop/chromium.desktop && \
    chmod +x /root/Desktop/chromium.desktop

RUN echo '[Desktop Entry]' > /root/Desktop/firefox.desktop && \
    echo 'Version=1.0' >> /root/Desktop/firefox.desktop && \
    echo 'Name=Firefox Browser' >> /root/Desktop/firefox.desktop && \
    echo 'Comment=Browse the web' >> /root/Desktop/firefox.desktop && \
    echo 'Exec=firefox-esr' >> /root/Desktop/firefox.desktop && \
    echo 'Icon=firefox-esr' >> /root/Desktop/firefox.desktop && \
    echo 'Terminal=false' >> /root/Desktop/firefox.desktop && \
    echo 'Type=Application' >> /root/Desktop/firefox.desktop && \
    chmod +x /root/Desktop/firefox.desktop

# Create startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8900

CMD ["/start.sh"]
