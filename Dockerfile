FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV VNC_PASSWORD=password123
ENV DISPLAY=:1

# Install TigerVNC with HTTP server
RUN apt update && apt install -y \
    tigervnc-standalone-server \
    tigervnc-common \
    tigervnc-scraping-server \
    xvfb \
    fluxbox \
    firefox \
    --no-install-recommends && \
    apt clean

# Setup VNC password
RUN mkdir -p ~/.vnc && \
    echo ${VNC_PASSWORD} | vncpasswd -f > ~/.vnc/passwd && \
    chmod 600 ~/.vnc/passwd

# Create xstartup
RUN echo '#!/bin/bash' > ~/.vnc/xstartup && \
    echo 'fluxbox &' >> ~/.vnc/xstartup && \
    echo 'sleep 2' >> ~/.vnc/xstartup && \
    echo 'firefox about:blank' >> ~/.vnc/xstartup && \
    chmod +x ~/.vnc/xstartup

EXPOSE 80

# Use TigerVNC's built-in HTTP server
CMD echo "==========================================" && \
    echo "  🖥️  VNC DESKTOP (Free Tier)" && \
    echo "==========================================" && \
    echo "" && \
    # Start virtual display
    Xvfb :1 -screen 0 1024x768x24 & \
    sleep 3 && \
    # Start window manager
    fluxbox & \
    sleep 2 && \
    # Start Firefox
    firefox about:blank & \
    sleep 2 && \
    # Start TigerVNC with HTTP interface on port 80
    echo "Starting TigerVNC HTTP server on port 80..." && \
    vncserver :1 -geometry 1024x768 -depth 24 -localhost no -rfbport 5900 -httpport 80 -alwaysshared && \
    echo "==========================================" && \
    echo "  Access at: https://$(hostname)" && \
    echo "  Password: ${VNC_PASSWORD}" && \
    echo "==========================================" && \
    # Keep running
    tail -f /dev/null
