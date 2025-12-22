#!/bin/bash

echo "=== Starting XFCE VNC on Render ==="
echo "Render Port: ${PORT}"
echo "Display: ${DISPLAY}"
echo "Resolution: ${RESOLUTION}"

# Generate password if not set
if [ -z "${VNC_PASSWORD}" ]; then
    export VNC_PASSWORD=$(openssl rand -base64 12)
    echo "Generated VNC password: ${VNC_PASSWORD}"
    echo "${VNC_PASSWORD}" | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
fi

# Clean up any existing X sessions
rm -rf /tmp/.X${DISPLAY#:}-lock /tmp/.X11-unix/X${DISPLAY#:} 2>/dev/null

# Start VNC server
echo "Starting VNC server on ${DISPLAY} port 5901..."
vncserver ${DISPLAY} \
    -geometry ${RESOLUTION} \
    -depth 24 \
    -localhost no \
    -SecurityTypes VncAuth \
    -rfbauth /root/.vnc/passwd \
    -dpi 96 \
    -alwaysshared

# Wait for VNC
sleep 2
echo "VNC server started"

# Start noVNC on Render's port (10000)
echo "Starting noVNC proxy on port ${PORT}..."
/opt/novnc/utils/novnc_proxy \
    --vnc localhost:5901 \
    --listen 0.0.0.0:${PORT} \
    --web /opt/novnc \
    --heartbeat 30 &

# Health check endpoint (optional, also on Render's port)
echo "Starting health endpoint..."
python3 -m http.server ${PORT} --directory /opt/novnc/health &

# Log connection info
echo ""
echo "========================================"
echo "✅ VNC Desktop is READY!"
echo ""
echo "🌐 Web Access (noVNC):"
echo "   URL: https://${RENDER_SERVICE_NAME}.onrender.com"
echo "   Password: ${VNC_PASSWORD}"
echo ""
echo "🖥️  VNC Client Access:"
echo "   Host: ${RENDER_SERVICE_NAME}.onrender.com"
echo "   Port: 5901"
echo "   Password: ${VNC_PASSWORD}"
echo ""
echo "🔧 For UptimeRobot (keep awake):"
echo "   URL: https://${RENDER_SERVICE_NAME}.onrender.com"
echo "   Interval: 5 minutes"
echo "========================================"

# Keep container running
tail -f /dev/null
