#!/data/data/com.termux/files/usr/bin/bash

echo "Starting VNC on Termux..."

# Kill existing VNC
vncserver -kill :1 2>/dev/null

# Start VNC server
vncserver :1 -geometry 800x600 -depth 16 -localhost

# Start noVNC proxy
~/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 127.0.0.1:8080 &

echo ""
echo "✅ VNC Server Started!"
echo "========================"
echo "1. For local connection:"
echo "   VNC Viewer → localhost:5901"
echo "   Password: password123"
echo ""
echo "2. For web access:"
echo "   Open browser → http://localhost:8080/vnc.html"
echo ""
echo "3. For network access (if supported):"
echo "   Your IP: $(ifconfig wlan0 | grep 'inet ' | awk '{print $2}')"
echo "   Access: http://YOUR_IP:8080/vnc.html"
echo "========================"
echo ""
echo "Press Ctrl+C to stop"

# Keep running
wait
