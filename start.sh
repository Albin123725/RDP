#!/bin/bash

# Set VNC password from env or generate one
if [ -z "$VNC_PASSWORD" ]; then
    export VNC_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
    echo "Generated VNC password: $VNC_PASSWORD"
fi

echo "$VNC_PASSWORD" | vncpasswd -f > /root/.vnc/passwd
chmod 600 /root/.vnc/passwd

# Kill any existing VNC session
vncserver -kill :1 2>/dev/null || true

# Start VNC server
echo "Starting VNC server..."
vncserver :1 \
    -geometry $RESOLUTION \
    -depth 24 \
    -localhost no \
    -SecurityTypes VncAuth \
    -rfbauth /root/.vnc/passwd

# Wait for VNC to start
sleep 2

# Start noVNC on Render's port
echo "Starting noVNC on port $PORT..."
/opt/novnc/utils/novnc_proxy \
    --vnc localhost:5901 \
    --listen 0.0.0.0:$PORT \
    --web /opt/novnc &

# Keep container running
echo "VNC Desktop is ready!"
echo "Web access: https://your-service.onrender.com"
echo "VNC password: $VNC_PASSWORD"

tail -f /dev/null
