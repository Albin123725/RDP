FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV VNC_PASSWORD=password123
ENV DISPLAY=:1

# Install minimal packages
RUN apt update && apt install -y \
    x11vnc \
    xvfb \
    fluxbox \
    firefox \
    --no-install-recommends && \
    apt clean

# Set VNC password
RUN mkdir -p ~/.vnc && \
    x11vnc -storepasswd ${VNC_PASSWORD} ~/.vnc/passwd

EXPOSE 5900

# Start everything - DISABLE WebSocket support
CMD echo "==========================================" && \
    echo "  🖥️  UBUNTU VNC DESKTOP (DIRECT TCP)" && \
    echo "==========================================" && \
    echo "" && \
    echo "  📍 CONNECT WITH VNC CLIENT:" && \
    echo "" && \
    echo "  Host: rdp-quyu.onrender.com" && \
    echo "  Port: 5900" && \
    echo "  Password: ${VNC_PASSWORD}" && \
    echo "" && \
    echo "==========================================" && \
    echo "" && \
    echo "Starting desktop environment..." && \
    # Start virtual display
    Xvfb :1 -screen 0 1024x768x16 & \
    sleep 3 && \
    # Start window manager
    fluxbox & \
    sleep 2 && \
    # Start Firefox
    firefox about:blank & \
    sleep 2 && \
    # Start VNC server on port 5900 - DISABLE WebSocket
    echo "Starting VNC server (TCP only, no WebSocket)..." && \
    x11vnc -display :1 -forever -shared -rfbauth ~/.vnc/passwd -rfbport 5900 -nosel -noshm -nowf -noscr
