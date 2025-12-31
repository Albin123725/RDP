#!/data/data/com.termux/files/usr/bin/bash

# Update packages
pkg update -y
pkg upgrade -y

# Install required packages
pkg install -y x11-repo
pkg install -y \
    tigervnc \
    xfce4 \
    xfce4-terminal \
    netsurf \
    termux-x11-nightly

# Create VNC config directory
mkdir -p ~/.vnc

# Set VNC password (default: password123)
echo "password123" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

# Create xstartup file
cat > ~/.vnc/xstartup << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
xfce4-session &
EOF

chmod +x ~/.vnc/xstartup

# Create startup script
cat > ~/start-vnc.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
echo "Starting VNC server..."
vncserver :1 -geometry 1024x576 -depth 16 -localhost no
echo "VNC is running on port 5901"
echo "Connect with a VNC viewer using:"
echo "localhost:5901"
echo "Password: password123"
echo ""
echo "To stop VNC server, run: vncserver -kill :1"
EOF

chmod +x ~/start-vnc.sh

echo "Installation complete!"
echo "Run './start-vnc.sh' to start the VNC server"
echo "Install a VNC viewer app from Play Store to connect"
