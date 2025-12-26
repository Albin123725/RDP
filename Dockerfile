FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Kolkata
ENV USER=root
ENV HOME=/root
ENV DISPLAY=:1
ENV VNC_PASSWD=password123
ENV VNC_RESOLUTION=1024x576
ENV VNC_DEPTH=16

# Set timezone
RUN ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo "Asia/Kolkata" > /etc/timezone

# Update and install minimal packages
RUN apt update && apt install -y \
    tightvncserver \
    xfce4 \
    xfce4-goodies \
    firefox \
    novnc \
    websockify \
    wget \
    sudo \
    dbus-x11 \
    x11-utils \
    xfonts-base \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Create VNC password
RUN mkdir -p /root/.vnc && \
    echo "${VNC_PASSWD}" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create xstartup file
RUN echo '#!/bin/bash\nxrdb $HOME/.Xresources\nstartxfce4 &' > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# Download noVNC
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt && \
    mv /opt/noVNC-1.4.0 /opt/novnc && \
    rm /tmp/novnc.tar.gz

RUN wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O /tmp/websockify.tar.gz && \
    tar -xzf /tmp/websockify.tar.gz -C /opt/novnc/utils && \
    mv /opt/novnc/utils/websockify-0.11.0 /opt/novnc/utils/websockify && \
    rm /tmp/websockify.tar.gz

# Create desktop shortcut for Firefox
RUN mkdir -p /root/Desktop && \
    echo '[Desktop Entry]\nVersion=1.0\nType=Application\nName=Firefox\nExec=firefox --no-sandbox\nIcon=firefox\nTerminal=false' > /root/Desktop/firefox.desktop && \
    chmod +x /root/Desktop/firefox.desktop

EXPOSE 5901 10000

# Create startup script
RUN cat > /startup.sh << 'EOF'
#!/bin/bash

# Kill any existing VNC servers
vncserver -kill :1 2>/dev/null || true
rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1

# Start VNC server
vncserver :1 -geometry ${VNC_RESOLUTION} -depth ${VNC_DEPTH} -localhost no

# Start noVNC
/opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 --web /opt/novnc &

# Keep container alive
tail -f /dev/null
EOF

RUN chmod +x /startup.sh

CMD ["/startup.sh"]
