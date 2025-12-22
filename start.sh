#!/bin/bash

# Kill any existing VNC session
vncserver -kill :1 2>/dev/null || true
rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

# Start VNC server first
echo "Starting VNC server on :1"
vncserver :1 \
  -geometry ${RESOLUTION:-1280x720} \
  -depth 24 \
  -dpi 96 \
  -localhost no \
  -alwaysshared \
  -SecurityTypes VncAuth \
  -rfbauth /root/.vnc/passwd

# Wait for VNC to start
sleep 2

# Check if VNC is running
if ! nc -z localhost 5901; then
    echo "ERROR: VNC server failed to start on port 5901"
    echo "Trying alternative method..."
    /usr/bin/Xtigervnc :1 \
        -geometry ${RESOLUTION:-1280x720} \
        -depth 24 \
        -rfbport 5901 \
        -SecurityTypes VncAuth \
        -rfbauth /root/.vnc/passwd \
        -dpi 96 \
        -desktop "XFCE Desktop" \
        -alwaysshared \
        -localhost no \
        -fg &
    sleep 3
fi

# Clone noVNC if not exists
if [ ! -d "/opt/novnc" ]; then
    echo "Setting up noVNC..."
    git clone https://github.com/novnc/noVNC.git /opt/novnc
    git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html
fi

# Start noVNC proxy
echo "Starting noVNC on port 6080"
/opt/novnc/utils/novnc_proxy \
    --vnc localhost:5901 \
    --listen 0.0.0.0:6080 \
    --web /opt/novnc &

# Start health endpoint
echo "Starting health endpoint on port 8080"
python3 -m http.server 8080 --directory /opt/novnc/health &

# Keep container alive
echo "All services started successfully!"
echo "VNC Port: 5901"
echo "noVNC Web: http://localhost:6080/vnc.html"
echo "Health: http://localhost:8080"

tail -f /dev/null
