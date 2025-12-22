#!/bin/bash

echo "=== Starting XFCE VNC Desktop ==="

# Generate password if not set
if [ -z "$VNC_PASSWORD" ]; then
    VNC_PASSWORD=$(openssl rand -base64 12)
    echo "Generated VNC password: $VNC_PASSWORD"
    echo "$VNC_PASSWORD" | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
fi

# Clean up previous sessions
vncserver -kill $DISPLAY 2>/dev/null || true
rm -f /tmp/.X${DISPLAY:1}-lock /tmp/.X11-unix/X${DISPLAY:1} 2>/dev/null || true

# Start VNC server
echo "Starting VNC server on $DISPLAY..."
vncserver $DISPLAY \
    -geometry "$RESOLUTION" \
    -depth 24 \
    -localhost no \
    -SecurityTypes VncAuth \
    -rfbauth /root/.vnc/passwd

# Wait for VNC to start
sleep 3

# Start noVNC web interface
echo "Starting noVNC web interface on port $PORT..."
/opt/novnc/utils/novnc_proxy \
    --vnc localhost:5901 \
    --listen 0.0.0.0:"$PORT" \
    --web /opt/novnc &

echo ""
echo "=========================================="
echo "✅ XFCE Desktop is READY!"
echo "🌐 Access URL: https://your-service.onrender.com"
echo "🔑 VNC Password: $VNC_PASSWORD"
echo "=========================================="
echo ""

# Keep container running
tail -f /dev/null
