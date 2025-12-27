FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Kolkata
ENV USER=root
ENV HOME=/root
ENV DISPLAY=:1
ENV VNC_PASSWD=password123
ENV VNC_RESOLUTION=1024x768
ENV VNC_DEPTH=16
ENV BROWSER=chromium-browser

# Set timezone
RUN ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo "Asia/Kolkata" > /etc/timezone

# Install ONLY the absolute minimum for browser + VNC
RUN apt update && apt install -y \
    # VNC server essentials
    tightvncserver \
    xserver-xorg-core \
    xinit \
    # noVNC for web access
    novnc \
    websockify \
    wget \
    # X11 minimal
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    xfonts-base \
    # Window manager (lightest possible)
    openbox \
    # Browser ONLY - choose ONE
    chromium-browser \
    chromium-codecs-ffmpeg \
    # OR firefox (choose one)
    # firefox \
    # Essential browser libraries
    fonts-liberation \
    fonts-noto \
    fonts-noto-cjk \
    libnss3 \
    libxss1 \
    libasound2 \
    libgbm1 \
    libgtk-3-0 \
    --no-install-recommends && \
    # Remove ALL unnecessary packages
    apt purge -y '*xfce*' '*gnome*' '*kde*' '*office*' '*terminal*' '*xterm*' || true && \
    apt purge -y man-db info install-info || true && \
    # Clean aggressively
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/locale/* && \
    find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name "en*" -exec rm -rf {} \; 2>/dev/null || true && \
    apt autoremove -y && \
    apt autoclean

# Setup VNC password
RUN mkdir -p /root/.vnc && \
    echo "${VNC_PASSWD}" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create ultra-minimal xstartup - ONLY browser
RUN cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
xsetroot -solid grey
vncconfig -iconic &
openbox-session &

# Wait a moment
sleep 1

# Start browser directly (no desktop, no menus)
# Use Chromium with memory-saving flags for heavy sites
chromium-browser \
  --disable-dev-shm-usage \
  --no-sandbox \
  --disable-gpu \
  --disable-software-rasterizer \
  --disable-background-timer-throttling \
  --disable-renderer-backgrounding \
  --disable-backgrounding-occluded-windows \
  --disable-breakpad \
  --disable-component-update \
  --disable-features=TranslateUI \
  --max_old_space_size=384 \
  --window-size=1024,768 \
  --start-fullscreen \
  https://colab.research.google.com/
EOF

RUN chmod +x /root/.vnc/xstartup

# Fix vncserver font path issue
RUN sed -i 's/\$fontPath = ".*"/\$fontPath = ""/' /usr/bin/vncserver && \
    touch /root/.Xauthority

# Get noVNC (lightweight version)
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt/ && \
    mv /opt/noVNC-1.4.0 /opt/novnc && \
    rm /tmp/novnc.tar.gz && \
    wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O /tmp/websockify.tar.gz && \
    tar -xzf /tmp/websockify.tar.gz -C /opt/novnc/utils/ && \
    mv /opt/novnc/utils/websockify-0.11.0 /opt/novnc/utils/websockify && \
    rm /tmp/websockify.tar.gz && \
    # Remove noVNC extras we don't need
    rm -rf /opt/novnc/.* /opt/novnc/*.md /opt/novnc/tests /opt/novnc/vendor

# Copy only essential noVNC files
RUN cp /opt/novnc/vnc_lite.html /opt/novnc/index.html

# Add LARGE swap file (1GB) for heavy websites
RUN fallocate -l 1G /swapfile && \
    chmod 600 /swapfile && \
    mkswap /swapfile

# Browser memory optimization config
RUN mkdir -p /etc/chromium-browser && \
    echo 'CHROMIUM_FLAGS="--disable-dev-shm-usage --no-sandbox --disable-gpu --disable-software-rasterizer --max_old_space_size=384 --single-process --disable-features=TranslateUI,BlinkGenPropertyTrees"' > /etc/chromium-browser/default

EXPOSE 10000

# Startup script with memory monitoring
CMD echo "=== Starting Browser-Only VNC ===" && \
    echo "Memory before start: $(free -h)" && \
    # Enable swap
    swapon /swapfile && \
    echo "Swap enabled (1GB)" && \
    # Start VNC with minimal options
    vncserver :1 -geometry ${VNC_RESOLUTION} -depth ${VNC_DEPTH} && \
    echo "VNC started on :1" && \
    echo "Starting noVNC proxy..." && \
    # Start noVNC
    /opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 --heartbeat 30 --web /opt/novnc && \
    echo "=== Ready ===" && \
    echo "Access at: https://your-app.onrender.com/vnc_lite.html" && \
    echo "Password: ${VNC_PASSWD}" && \
    echo "Memory status: $(free -h)" && \
    # Keep container running
    tail -f /dev/null
