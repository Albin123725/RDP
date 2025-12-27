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

# Start everything
CMD echo "==========================================" && \
    echo "  🖥️  UBUNTU VNC DESKTOP" && \
    echo "==========================================" && \
    echo "" && \
    echo "  📍 CONNECT WITH VNC CLIENT:" && \
    echo "" && \
    echo "  Host: rdp-quyu.onrender.com" && \
    echo "  Port: 5900" && \
    echo "  Password: ${VNC_PASSWORD}" && \
    echo "" && \
    echo "  🔗 Download VNC Viewer:" && \
    echo "  https://www.realvnc.com/en/connect/download/viewer/" && \
    echo "" && \
    echo "==========================================" && \
    echo "" && \
    echo "Starting desktop environment..." && \
    # Start virtual display (1024x768, 16-bit color)
    Xvfb :1 -screen 0 1024x768x16 & \
    sleep 3 && \
    # Start window manager
    fluxbox & \
    sleep 2 && \
    # Start Firefox
    firefox about:blank & \
    sleep 2 && \
    # Start VNC server on port 5900
    echo "VNC server listening on port 5900..." && \
    x11vnc -display :1 -forever -shared -rfbauth ~/.vnc/passwd -rfbport 5900 -noxdamage
