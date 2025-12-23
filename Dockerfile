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

# Install packages
RUN apt update && apt install -y \
    fluxbox \
    xterm \
    thunar \
    firefox \
    x11vnc \
    xvfb \
    wget \
    net-tools \
    x11-xserver-utils \
    xfonts-base \
    python3 \
    python3-numpy \
    dbus-x11 \
    novnc \
    websockify \
    --no-install-recommends && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create VNC password file
RUN mkdir -p /root/.vnc && \
    echo "$VNC_PASSWD" > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Configure Firefox
RUN mkdir -p /root/.mozilla/firefox/default && \
    cat > /root/.mozilla/firefox/default/prefs.js << 'EOF'
user_pref("app.update.auto", false);
user_pref("app.update.enabled", false);
user_pref("browser.startup.page", 0);
user_pref("dom.ipc.processCount", 1);
EOF

# Create fluxbox menu
RUN mkdir -p /root/.fluxbox && \
    cat > /root/.fluxbox/menu << 'EOF'
[begin] (Applications)
  [exec] (Terminal) {xterm}
  [exec] (File Manager) {thunar}
  [exec] (Firefox) {firefox}
  [separator]
  [exit] (Exit)
[end]
EOF

# Create simple fluxbox startup file
RUN cat > /root/.fluxbox/startup << 'EOF'
#!/bin/sh
# fluxbox startup script

# Start applications
xterm -geometry 80x24+10+10 &
thunar &
firefox &
EOF

RUN chmod +x /root/.fluxbox/startup

# Link novnc files for easy access
RUN ln -s /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html

# Create startup script with proper error handling and port management
RUN cat > /start.sh << 'EOF'
#!/bin/bash

# Clean up all X11 and VNC related files
echo "Cleaning up old processes and lock files..."
rm -rf /tmp/.X11-unix/X99 /tmp/.X99-lock 2>/dev/null || true
rm -rf /tmp/.X11-unix/X1 /tmp/.X1-lock 2>/dev/null || true

# Kill any existing processes
pkill -9 x11vnc 2>/dev/null || true
pkill -9 Xvfb 2>/dev/null || true
pkill -9 fluxbox 2>/dev/null || true
pkill -9 websockify 2>/dev/null || true

# Kill any process on port 5901 and 10000
fuser -k 5901/tcp 2>/dev/null || true
fuser -k 10000/tcp 2>/dev/null || true

# Set DISPLAY
export DISPLAY=:99

# Start Xvfb
echo "Starting Xvfb on display :99"
Xvfb :99 -screen 0 ${VNC_RESOLUTION}x${VNC_DEPTH} &
XVFB_PID=$!

# Wait for Xvfb to start
sleep 3

# Verify Xvfb is running
if ! ps -p $XVFB_PID > /dev/null; then
    echo "ERROR: Xvfb failed to start"
    exit 1
fi

# Start fluxbox
echo "Starting Fluxbox"
fluxbox &
FLUXBOX_PID=$!

sleep 2

# Check if fluxbox is running
if ! ps -p $FLUXBOX_PID > /dev/null; then
    echo "WARNING: Fluxbox may have issues, but continuing..."
fi

# Start x11vnc with proper cleanup first
echo "Clearing any existing VNC processes..."
pkill -9 x11vnc 2>/dev/null || true
fuser -k 5901/tcp 2>/dev/null || true
sleep 1

echo "Starting x11vnc on port 5901"
# Use -localhost no to allow connections from websockify
x11vnc -display :99 -forever -shared -rfbauth /root/.vnc/passwd -bg -rfbport 5901 -localhost no -noxdamage -nowf -noscr -cursor arrow

sleep 2

# Check if x11vnc is running
if ! pgrep -x "x11vnc" > /dev/null; then
    echo "ERROR: x11vnc failed to start"
    echo "Trying alternative x11vnc startup..."
    x11vnc -display :99 -forever -shared -rfbauth /root/.vnc/passwd -rfbport 5901 -localhost no &
    sleep 2
fi

# Verify x11vnc is listening on port 5901
if netstat -tuln | grep -q ":5901"; then
    echo "SUCCESS: x11vnc is listening on port 5901"
else
    echo "WARNING: x11vnc may not be listening on port 5901"
    echo "Checking x11vnc process..."
    pgrep -a x11vnc
fi

# Start noVNC using system package
echo "Starting noVNC on port 10000"
# Clear port 10000 first
fuser -k 10000/tcp 2>/dev/null || true
sleep 1

websockify --web /usr/share/novnc 0.0.0.0:10000 localhost:5901 &
NOVNC_PID=$!

sleep 3

# Check if noVNC is running
if ! ps -p $NOVNC_PID > /dev/null 2>&1; then
    echo "Trying alternative noVNC startup..."
    # Alternative method with 127.0.0.1 instead of localhost
    /usr/bin/websockify --web /usr/share/novnc 0.0.0.0:10000 127.0.0.1:5901 &
    NOVNC_PID=$!
    sleep 2
fi

echo "=========================================="
echo "VNC Desktop is ready!"
echo "Access at: https://${RENDER_EXTERNAL_HOSTNAME:-localhost}/vnc_lite.html"
echo "Password: $VNC_PASSWD"
echo "=========================================="

# Test if port 10000 is listening
if netstat -tuln | grep -q ":10000"; then
    echo "SUCCESS: noVNC is listening on port 10000"
else
    echo "WARNING: Port 10000 is not listening"
    echo "Checking websockify process..."
    ps aux | grep -E "(websockify|novnc)" | grep -v grep
fi

# Test if port 5901 is listening
if netstat -tuln | grep -q ":5901"; then
    echo "SUCCESS: x11vnc is listening on port 5901"
else
    echo "ERROR: x11vnc is NOT listening on port 5901"
    echo "This is likely why noVNC shows 'loading'"
    echo "Trying emergency restart of x11vnc..."
    pkill -9 x11vnc 2>/dev/null || true
    x11vnc -display :99 -forever -shared -rfbauth /root/.vnc/passwd -rfbport 5901 &
    sleep 2
fi

echo "Current network status:"
netstat -tuln | grep -E "(5901|10000)"

# Keep running
tail -f /dev/null
EOF

RUN chmod +x /start.sh

EXPOSE 10000

CMD ["/start.sh"]
