FROM ubuntu:22.04

# Install git and all dependencies first
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    xfce4 \
    xfce4-goodies \
    tigervnc-standalone-server \
    novnc \
    websockify \
    && apt-get clean

# Setup VNC
RUN mkdir -p /root/.vnc && \
    echo "password123" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create xstartup
RUN echo 'startxfce4' > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# Clone noVNC (git is now installed)
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc

# Start command
CMD vncserver :1 -geometry 1280x720 -localhost no && \
    /opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 --web /opt/novnc && \
    tail -f /dev/null

EXPOSE 10000
