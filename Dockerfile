FROM ubuntu:22.04

# Environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV RESOLUTION=1280x720
ENV VNC_PASSWORD=password123
ENV PORT=10000

# Install packages
RUN apt-get update && apt-get install -y \
    xfce4 \
    xfce4-goodies \
    tigervnc-standalone-server \
    novnc \
    websockify \
    && apt-get clean

# Setup VNC directory and password
RUN mkdir -p /root/.vnc
RUN echo "$VNC_PASSWORD" | vncpasswd -f > /root/.vnc/passwd
RUN chmod 600 /root/.vnc/passwd

# Create xstartup file correctly
RUN echo '#!/bin/bash' > /root/.vnc/xstartup && \
    echo 'unset SESSION_MANAGER' >> /root/.vnc/xstartup && \
    echo 'unset DBUS_SESSION_BUS_ADDRESS' >> /root/.vnc/xstartup && \
    echo 'exec startxfce4' >> /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# Setup noVNC
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc
RUN ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# Copy start script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Expose Render's port
EXPOSE 10000

# Start command
CMD ["/start.sh"]
