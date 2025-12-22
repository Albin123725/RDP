#!/data/data/com.termux/files/usr/bin/bash

echo "Installing VNC Desktop for Termux..."

# Install Ubuntu-like environment
pkg install -y x11-repo tur-repo
pkg update

# Install VNC and XFCE packages (Termux versions)
pkg install -y \
    xfce4 \
    tightvncserver \
    novnc \
    websockify \
    wget \
    x11-utils \
    xterm

# Setup VNC
mkdir -p ~/.vnc
echo "password123" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

# Create xstartup for Termux
echo '#!/data/data/com.termux/files/usr/bin/bash
export DISPLAY=:1
export PULSE_SERVER=127.0.0.1
xsetroot -solid grey
vncconfig -iconic &
startxfce4 &' > ~/.vnc/xstartup
chmod +x ~/.vnc/xstartup

# Setup noVNC
mkdir -p ~/novnc
wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O novnc.tar.gz
tar -xzf novnc.tar.gz -C ~/novnc --strip-components=1
rm novnc.tar.gz

echo "Installation complete!"
