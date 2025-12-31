#!/data/data/com.termux/files/usr/bin/bash

echo "=========================================="
echo "   VNC Desktop for Termux - All-in-One   "
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if package is installed
check_pkg() {
    if ! dpkg -s "$1" &>/dev/null; then
        return 1
    fi
    return 0
}

# Update packages
echo -e "${YELLOW}[1/6] Updating packages...${NC}"
pkg update -y && pkg upgrade -y

# Install X11 repo and required packages
echo -e "${YELLOW}[2/6] Installing X11 and VNC packages...${NC}"
pkg install -y x11-repo
pkg install -y \
    tigervnc \
    xfce4 \
    xfce4-terminal \
    netsurf \
    termux-x11-nightly \
    htop \
    neofetch

# Setup VNC directory
echo -e "${YELLOW}[3/6] Setting up VNC configuration...${NC}"
mkdir -p ~/.vnc

# Set VNC password (default: password123)
echo -e "${GREEN}Setting VNC password to 'password123'${NC}"
echo "password123" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

# Create minimal xstartup for Xfce
cat > ~/.vnc/xstartup << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

# Clean up old sessions
rm -rf /tmp/.X11-unix/X1
rm -rf /tmp/.X1-lock

# Start Xfce desktop
export DISPLAY=:1
export PULSE_SERVER=127.0.0.1
startxfce4 &
EOF

chmod +x ~/.vnc/xstartup

# Create control script with all functions
cat > ~/vnc-control << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

case "$1" in
    start)
        echo "Starting VNC server on display :1 (1024x576)"
        vncserver :1 -geometry 1024x576 -depth 16 -localhost no -xstartup ~/.vnc/xstartup
        echo "VNC is running on port 5901"
        echo "Password: password123"
        ;;
    stop)
        echo "Stopping VNC server..."
        vncserver -kill :1
        ;;
    restart)
        vncserver -kill :1 2>/dev/null
        sleep 2
        vncserver :1 -geometry 1024x576 -depth 16 -localhost no -xstartup ~/.vnc/xstartup
        echo "VNC restarted"
        ;;
    status)
        echo "VNC Server Status:"
        vncserver -list
        ;;
    info)
        echo "=== VNC Connection Info ==="
        echo "Port: 5901"
        echo "Display: :1"
        echo "Password: password123"
        echo "Resolution: 1024x576"
        echo ""
        echo "=== How to Connect ==="
        echo "1. Install 'bVNC' from Play Store"
        echo "2. Create new connection:"
        echo "   Host: localhost"
        echo "   Port: 5901"
        echo "3. Connect with password: password123"
        ;;
    *)
        echo "Usage: ./vnc-control {start|stop|restart|status|info}"
        echo ""
        echo "Examples:"
        echo "  ./vnc-control start   # Start VNC desktop"
        echo "  ./vnc-control stop    # Stop VNC desktop"
        echo "  ./vnc-control status  # Check if running"
        echo "  ./vnc-control info    # Show connection info"
        ;;
esac
EOF

chmod +x ~/vnc-control

echo -e "${YELLOW}[4/6] Creating cleanup script...${NC}"

# Create cleanup script
cat > ~/cleanup-vnc.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
echo "Cleaning up VNC temporary files..."
rm -rf /tmp/.X11-unix/*
rm -rf /tmp/.X*-lock
rm -rf ~/.vnc/*.log
rm -rf ~/.vnc/*.pid
echo "Cleanup complete!"
EOF

chmod +x ~/cleanup-vnc.sh

echo -e "${YELLOW}[5/6] Setting up Termux storage...${NC}"
# Setup storage permission
termux-setup-storage

echo -e "${YELLOW}[6/6] Finalizing installation...${NC}"

# Display system info
echo ""
echo -e "${GREEN}=== Installation Complete! ===${NC}"
echo ""
neofetch
echo ""
echo -e "${GREEN}=== Available Commands ===${NC}"
echo "1. Start VNC:        ./vnc-control start"
echo "2. Stop VNC:         ./vnc-control stop"
echo "3. Check status:     ./vnc-control status"
echo "4. Connection info:  ./vnc-control info"
echo "5. Cleanup files:    ./cleanup-vnc.sh"
echo ""
echo -e "${GREEN}=== Quick Start ===${NC}"
echo "Run this command to start your VNC desktop:"
echo -e "${YELLOW}./vnc-control start${NC}"
echo ""
echo "Then install 'bVNC' from Play Store and connect to:"
echo "Host: localhost"
echo "Port: 5901"
echo "Password: password123"
echo ""
echo "=========================================="
EOF
