FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    VNC_PASSWD=password123 \
    RESOLUTION=800x600

# Install packages including Firefox
RUN apt-get update && apt-get install -y \
    tigervnc-standalone-server \
    fluxbox \
    firefox \
    xterm \
    wget \
    python3 \
    python3-websockify \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Setup VNC
RUN mkdir -p /root/.vnc && \
    echo "$VNC_PASSWD" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# xstartup with Firefox icon
RUN echo '#!/bin/bash' > /root/.vnc/xstartup && \
    echo 'fluxbox &' >> /root/.vnc/xstartup && \
    echo 'sleep 2' >> /root/.vnc/xstartup && \
    echo 'firefox --no-sandbox &' >> /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# Create Firefox desktop shortcut
RUN mkdir -p /root/Desktop && \
    echo '[Desktop Entry]' > /root/Desktop/firefox.desktop && \
    echo 'Version=1.0' >> /root/Desktop/firefox.desktop && \
    echo 'Type=Application' >> /root/Desktop/firefox.desktop && \
    echo 'Name=Firefox' >> /root/Desktop/firefox.desktop && \
    echo 'Exec=firefox --no-sandbox' >> /root/Desktop/firefox.desktop && \
    echo 'Icon=firefox' >> /root/Desktop/firefox.desktop && \
    echo 'Terminal=false' >> /root/Desktop/firefox.desktop && \
    chmod +x /root/Desktop/firefox.desktop

# Download noVNC
RUN wget -qO- https://github.com/novnc/noVNC/archive/v1.4.0.tar.gz | tar xz -C /opt && \
    mv /opt/noVNC-1.4.0 /opt/novnc

EXPOSE 8080

# Start command
CMD echo "=== Starting VNC Desktop ===" && \
    echo "Password: $VNC_PASSWD" && \
    echo "Resolution: $RESOLUTION" && \
    echo "" && \
    vncserver :1 \
        -geometry $RESOLUTION \
        -depth 16 \
        -localhost no \
        -SecurityTypes VncAuth \
        -I-KNOW-THIS-IS-INSECURE \
        -xstartup /root/.vnc/xstartup && \
    echo "" && \
    echo "VNC Server is running!" && \
    echo "Starting noVNC websocket proxy..." && \
    websockify --web /opt/novnc 8080 localhost:5901
