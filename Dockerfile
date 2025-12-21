FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV USER=root
ENV HOME=/root
ENV DISPLAY=:99
ENV DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/0/bus

# Install all necessary packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # Core desktop
    xfce4 xfce4-goodies xfce4-terminal \
    # Applications
    firefox-esr \
    xterm \
    # VNC and display
    novnc websockify \
    xvfb x11vnc \
    # System services
    dbus dbus-x11 \
    policykit-1-gnome \
    lxsession \
    # Fixes for missing components
    consolekit2 \
    udisks2 \
    pulseaudio \
    # Required libraries
    libglib2.0-bin \
    libnotify-bin \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /run/user/0 /run/dbus /var/run/dbus && \
    chmod 755 /run/user/0 && \
    ln -sf /run/user/0 /run/user/$(id -u)

# Create desktop shortcuts
RUN mkdir -p /root/Desktop && \
    echo '[Desktop Entry]\nVersion=1.0\nName=Firefox\nExec=firefox-esr\nIcon=firefox-esr\nTerminal=false\nType=Application' > /root/Desktop/firefox.desktop && \
    echo '[Desktop Entry]\nVersion=1.0\nName=Terminal\nExec=xfce4-terminal\nIcon=utilities-terminal\nTerminal=false\nType=Application' > /root/Desktop/terminal.desktop && \
    chmod +x /root/Desktop/*.desktop

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
