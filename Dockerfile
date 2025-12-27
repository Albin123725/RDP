FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV VNC_PASSWORD=password123
ENV DISPLAY=:1

# Install packages
RUN apt update && apt install -y \
    x11vnc \
    xvfb \
    fluxbox \
    firefox \
    wget \
    python3 \
    python3-pip \
    --no-install-recommends && \
    apt clean

# Install websockify
RUN pip3 install websockify

# Download noVNC 1.1.0 (very stable, no ES6 issues)
RUN wget -q https://github.com/novnc/noVNC/archive/v1.1.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt/ && \
    mv /opt/noVNC-1.1.0 /opt/novnc && \
    rm /tmp/novnc.tar.gz

# Set VNC password
RUN mkdir -p ~/.vnc && \
    x11vnc -storepasswd ${VNC_PASSWORD} ~/.vnc/passwd

EXPOSE 8080

# Simple startup
CMD Xvfb :1 -screen 0 1024x768x16 & \
    sleep 3 && \
    fluxbox & \
    sleep 2 && \
    x11vnc -display :1 -forever -shared -rfbauth ~/.vnc/passwd -bg & \
    sleep 2 && \
    firefox about:blank & \
    sleep 3 && \
    cd /opt/novnc && websockify --web=. 8080 localhost:5900
