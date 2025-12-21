#!/bin/bash

# ========== SET ENVIRONMENT ==========
export USER=root
export HOME=/root
export DISPLAY=:99
export XDG_RUNTIME_DIR=/run/user/0
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/0/bus
export PULSE_SERVER=unix:/run/user/0/pulse/native

# Fix for Firefox sandbox
export MOZ_DISABLE_CONTENT_SANDBOX=1
export MOZ_FAKE_NO_SANDBOX=1

# ========== CREATE DIRECTORIES ==========
echo "Creating necessary directories..."
mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix
mkdir -p /run/user/0 && chmod 700 /run/user/0
mkdir -p /var/run/dbus
mkdir -p /run/user/0/pulse && chmod 755 /run/user/0/pulse
mkdir -p /root/.config/autostart

# ========== START SYSTEM SERVICES ==========
echo "Starting DBus system bus..."
dbus-daemon --system --fork
sleep 2

echo "Starting DBus session bus..."
dbus-daemon --session --fork --address=unix:path=/run/user/0/bus
sleep 2

echo "Starting PolicyKit authentication agent..."
/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 &
sleep 2

# ========== START VIRTUAL DISPLAY ==========
echo "Starting Xvfb on display :99..."
Xvfb :99 -screen 0 1024x768x24 -ac +extension GLX +render -noreset &
sleep 3

# ========== START DESKTOP SESSION ==========
echo "Starting XFCE4 with proper session..."

# Create a minimal session file
cat > /root/.xsession << 'EOF'
#!/bin/bash
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/0/bus
/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 &
xfce4-session
EOF
chmod +x /root/.xsession

# Start XFCE within DBus session
dbus-launch --exit-with-session /root/.xsession &
sleep 5

# ========== START VNC SERVER ==========
echo "Starting x11vnc server..."
x11vnc -display :99 -forever -shared -nopw -listen 0.0.0.0 -xkb -bg -rfbport 5900 -noxdamage
sleep 3

# ========== START NOVNC WEB INTERFACE ==========
echo "Starting noVNC on port 8080..."
websockify --web=/usr/share/novnc 0.0.0.0:8080 localhost:5900 &

# ========== VERIFY SERVICES ==========
echo "Verifying services are running..."
if pgrep -x "xfce4-session" >/dev/null; then
    echo "✓ XFCE session is running"
else
    echo "✗ XFCE session failed to start"
fi

if pgrep -x "polkit" >/dev/null; then
    echo "✓ PolicyKit agent is running"
else
    echo "✗ PolicyKit agent failed to start"
fi

# ========== DISPLAY CONNECTION INFO ==========
echo ""
echo "=========================================="
echo "   ✅ FULLY FUNCTIONAL VNC DESKTOP READY"
echo "=========================================="
echo ""
echo "🌐 Access URL:"
echo "   https://$(hostname):8080/vnc.html"
echo ""
echo "🖥️  Applications included:"
echo "   • Firefox Browser (fully functional)"
echo "   • XFCE Terminal"
echo "   • Complete XFCE Desktop"
echo ""
echo "🔧 Services running:"
echo "   • DBus System & Session"
echo "   • PolicyKit Authentication"
echo "   • XFCE4 Desktop Environment"
echo "=========================================="
echo ""
echo "Desktop should be fully functional. Double-click on Firefox icon to test."

# ========== KEEP CONTAINER RUNNING ==========
# Monitor and restart failed services
while true; do
    if ! pgrep -x "xfce4-session" >/dev/null; then
        echo "XFCE session stopped, restarting..."
        dbus-launch --exit-with-session /root/.xsession &
    fi
    sleep 30
done
