FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    VNC_PASSWD=password123 \
    RESOLUTION=800x600

# Install packages
RUN apt-get update && apt-get install -y \
    tigervnc-standalone-server \
    xterm \
    firefox \
    wget \
    python3 \
    python3-websockify \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Setup VNC
RUN mkdir -p /root/.vnc && \
    echo "$VNC_PASSWD" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# xstartup with xterm that can launch Firefox
RUN echo '#!/bin/bash' > /root/.vnc/xstartup && \
    echo 'echo "Desktop started"' >> /root/.vnc/xstartup && \
    echo 'echo "To start Firefox, type: firefox --no-sandbox &"' >> /root/.vnc/xstartup && \
    echo 'echo "Then press Enter to start firefox in background"' >> /root/.vnc/xstartup && \
    echo 'xterm -geometry 80x24+10+10 -title "VNC Desktop" -e bash' >> /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# Download noVNC
RUN wget -qO- https://github.com/novnc/noVNC/archive/v1.4.0.tar.gz | tar xz -C /opt && \
    mv /opt/noVNC-1.4.0 /opt/novnc

EXPOSE 8080

CMD echo "=== Starting VNC Desktop ===" && \
    echo "Password: $VNC_PASSWD" && \
    echo "" && \
    echo "Starting VNC server..." && \
    vncserver :1 \
        -geometry $RESOLUTION \
        -depth 16 \
        -localhost no \
        -SecurityTypes VncAuth \
        -I-KNOW-THIS-IS-INSECURE \
        -xstartup /root/.vnc/xstartup && \
    echo "VNC Server started successfully!" && \
    echo "Starting noVNC proxy..." && \
    websockify --web /opt/novnc 8080 localhost:5901
