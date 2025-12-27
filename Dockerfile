FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV VNC_PASSWORD=password123

RUN apt update && apt install -y \
    x11vnc \
    xvfb \
    fluxbox \
    firefox \
    wget \
    python3 \
    --no-install-recommends && \
    apt clean

RUN mkdir -p ~/.vnc && \
    x11vnc -storepasswd ${VNC_PASSWORD} ~/.vnc/passwd

# Download and run noVNC's simple server
RUN wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O /tmp/websockify.tar.gz && \
    tar -xzf /tmp/websockify.tar.gz -C /tmp/ && \
    mv /tmp/websockify-0.11.0 /websockify && \
    rm /tmp/websockify.tar.gz

EXPOSE 8080

# Simple one-command startup
CMD Xvfb :1 -screen 0 1024x768x16 & \
    sleep 2 && \
    fluxbox & \
    sleep 1 && \
    firefox about:blank & \
    sleep 1 && \
    x11vnc -display :1 -forever -shared -rfbauth ~/.vnc/passwd -localhost & \
    cd /websockify && python3 -m websockify --web=/usr/share/novnc/ 8080 localhost:5900
