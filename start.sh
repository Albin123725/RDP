#!/bin/bash

# Set VNC password
echo "$VNC_PASSWORD" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

# Set xstartup
cat > ~/.vnc/xstartup << EOF
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF
chmod +x ~/.vnc/xstartup

# Kill existing VNC sessions
vncserver -kill $DISPLAY 2>/dev/null || true

# Start VNC server
vncserver $DISPLAY \
  -geometry $RESOLUTION \
  -depth 24 \
  -dpi 96 \
  -localhost no \
  -SecurityTypes VncAuth \
  -rfbauth ~/.vnc/passwd

# Start noVNC
/opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:6080 &

# Keep container running
tail -f /dev/null
