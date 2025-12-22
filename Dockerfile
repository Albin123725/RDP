FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Kolkata
ENV USER=root
ENV HOME=/root
ENV DISPLAY=:1
ENV VNC_PASSWD=albin4242
ENV VNC_RESOLUTION=1024x576
ENV VNC_DEPTH=16

# Set timezone
RUN ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo "Asia/Kolkata" > /etc/timezone

# Install packages with clipboard support
RUN apt update && apt install -y \
    xfce4 \
    xfce4-terminal \
    tightvncserver \
    novnc \
    websockify \
    wget \
    sudo \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    # Clipboard tools
    autocutsel \
    xclip \
    parcellite \
    copyq \
    # Terminal with better copy-paste
    terminator \
    # Utilities
    net-tools \
    curl \
    --no-install-recommends && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/locale/* && \
    apt purge -y xfce4-screensaver xfce4-power-manager xscreensaver* && \
    apt autoremove -y && \
    apt autoclean

# Setup VNC password
RUN mkdir -p /root/.vnc && \
    printf "${VNC_PASSWD}\n${VNC_PASSWD}\nn\n" | vncpasswd && \
    chmod 600 /root/.vnc/passwd

# Create xstartup with MULTIPLE clipboard solutions
RUN cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
xsetroot -solid grey
vncconfig -iconic &
# Start MULTIPLE clipboard sync solutions
# Solution 1: autocutsel (primary + clipboard)
autocutsel -fork &
autocutsel -s CLIPBOARD -fork &
# Solution 2: Parcellite (clipboard manager with GUI)
parcellite &
# Solution 3: copyq (advanced clipboard manager)
copyq &
# Start XFCE
xfwm4 --compositor=off &
xfsettingsd --daemon
xfce4-panel &
xfdesktop &
# Start Terminator (better terminal with copy-paste)
terminator &
EOF

RUN chmod +x /root/.vnc/xstartup

# Configure Terminator for easy copy-paste
RUN mkdir -p /root/.config/terminator && \
    cat > /root/.config/terminator/config << 'EOF'
[global_config]
  title_transmit_bg_color = "#d30102"
[keybindings]
  copy = <Primary><Shift>c
  paste = <Primary><Shift>v
[profiles]
  [[default]]
    background_color = "#300a24"
    cursor_color = "#aaaaaa"
    foreground_color = "#ffffff"
    palette = "#2d2d2d:#f2777a:#99cc99:#ffcc66:#6699cc:#cc99cc:#66cccc:#d3d0c8:#747369:#f2777a:#99cc99:#ffcc66:#6699cc:#cc99cc:#66cccc:#f2f0ec"
    scroll_on_output = False
    use_system_font = False
    font = Monospace 10
[layouts]
  [[default]]
    [[[child1]]]
      type = Terminal
      parent = window0
    [[[window0]]]
      type = Window
      parent = ""
[plugins]
EOF

# Configure Parcellite clipboard manager
RUN mkdir -p /root/.config/parcellite && \
    cat > /root/.config/parcellite/parcelliterc << 'EOF'
[rc]
use_copy=1
use_primary=1
synchronize=1
history_limit=50
save_history=1
hyperlinks_only=0
confirm_clear=1
item_length=50
history_key=...
primary_key=...
clipboard_key=...
actions_key=...
[hidden]
EOF

# Get noVNC
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt/ && \
    mv /opt/noVNC-1.4.0 /opt/novnc && \
    rm /tmp/novnc.tar.gz && \
    wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O /tmp/websockify.tar.gz && \
    tar -xzf /tmp/websockify.tar.gz -C /opt/novnc/utils/ && \
    mv /opt/novnc/utils/websockify-0.11.0 /opt/novnc/utils/websockify && \
    rm /tmp/websockify.tar.gz

# Create clipboard test and fix script
RUN cat > /fix-clipboard.sh << 'EOF'
#!/bin/bash
echo "=== CLIPBOARD FIX TOOL ==="
echo ""
echo "Clipboard solutions installed:"
echo "1. autocutsel - System clipboard sync"
echo "2. parcellite - Clipboard manager (tray icon)"
echo "3. copyq - Advanced clipboard (Ctrl+Shift+V)"
echo "4. Terminator terminal (Ctrl+Shift+C/V)"
echo ""
echo "Testing clipboard..."
pkill autocutsel
pkill parcellite
pkill copyq
sleep 2
autocutsel -fork &
autocutsel -s CLIPBOARD -fork &
parcellite &
copyq &
echo "Clipboard services restarted!"
echo ""
echo "=== HOW TO COPY-PASTE ==="
echo "FROM LOCAL to VNC:"
echo "1. Copy text on your computer (Ctrl+C)"
echo "2. Click inside VNC window"
echo "3. Press Ctrl+V or Ctrl+Shift+V"
echo "4. OR: Right-click → Paste"
echo "5. OR: Click Parcellite tray icon"
echo ""
echo "FROM VNC to LOCAL:"
echo "1. Select text in VNC"
echo "2. Copy with Ctrl+C or Ctrl+Shift+C"
echo "3. Click outside VNC window"
echo "4. Paste with Ctrl+V on your computer"
echo ""
echo "Terminal copy-paste:"
echo "Copy: Ctrl+Shift+C"
echo "Paste: Ctrl+Shift+V"
EOF

RUN chmod +x /fix-clipboard.sh

# Create desktop shortcuts for clipboard tools
RUN cat > /root/Desktop/Clipboard-Fix.desktop << 'EOF'
[Desktop Entry]
Name=Fix Clipboard
Comment=Restart clipboard services
Exec=/fix-clipboard.sh
Icon=edit-paste
Terminal=true
Type=Application
EOF
RUN mkdir -p /root/.local/share/applications

RUN cat > /root/Desktop/Terminal.desktop << 'EOF'
[Desktop Entry]
Name=Terminal (Better Copy-Paste)
Comment=Terminal with Ctrl+Shift+C/V
Exec=terminator
Icon=utilities-terminal
Terminal=false
Type=Application
EOF

RUN chmod +x /root/Desktop/*.desktop

# Copy noVNC HTML files
RUN cp /opt/novnc/vnc_lite.html /opt/novnc/index.html

# Fix VNC server font path
RUN sed -i '/^\s*\$fontPath\s*=/{s/.*/\$fontPath = "";/}' /usr/bin/vncserver

EXPOSE 10000

# Startup with clipboard emphasis
CMD echo "Starting VNC with clipboard support..." && \
    /fix-clipboard.sh & \
    vncserver :1 -geometry ${VNC_RESOLUTION} -depth ${VNC_DEPTH} && \
    echo "VNC started on :1" && \
    echo "" && \
    echo "=== CLIPBOARD READY ===" && \
    echo "Use Ctrl+V to paste from your computer to VNC" && \
    echo "Use Ctrl+Shift+V in Terminator terminal" && \
    echo "Click 'Clipboard-Fix' on desktop if not working" && \
    /opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 --heartbeat 30 --web /opt/novnc && \
    tail -f /dev/null
