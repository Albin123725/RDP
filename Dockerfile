FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Kolkata
ENV USER=root
ENV HOME=/root
ENV DISPLAY=:1
ENV VNC_PASSWD=password123
ENV VNC_RESOLUTION=800x600  # Lower for browser
ENV VNC_DEPTH=16

# Set timezone
RUN ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo "Asia/Kolkata" > /etc/timezone

# Install ONLY bare minimum + lightweight browser
RUN apt update && apt install -y \
    # Core X11/VNC
    xserver-xorg-core \
    xinit \
    tightvncserver \
    novnc \
    websockify \
    wget \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    xfonts-base \
    
    # Minimal window manager (replaces full XFCE)
    openbox \
    
    # Lightweight browser - choose ONE:
    # Option 1: Dillo (smallest - ~5MB)
    dillo \
    
    # OR Option 2: NetSurf (better CSS - ~15MB)
    # netsurf-gtk \
    
    # OR Option 3: Lynx (text-only - smallest)
    # lynx \
    
    # Basic file manager (optional)
    pcmanfm \
    
    # Remove terminal and unneeded packages
    --no-install-recommends && \
    
    # Clean up aggressively
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    
    # Remove ALL documentation, man pages, locales
    rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/locale/* && \
    
    # Remove XFCE completely (if any parts installed)
    apt purge -y '*xfce*' 'gnome*' 'kde*' || true && \
    
    # Remove terminal
    apt purge -y '*terminal*' 'xterm' 'gnome-terminal' 'xfce4-terminal' || true && \
    
    apt autoremove -y && \
    apt autoclean

# Setup VNC password
RUN mkdir -p /root/.vnc && \
    printf "${VNC_PASSWD}\n${VNC_PASSWD}\nn\n" | vncpasswd && \
    chmod 600 /root/.vnc/passwd

# Create minimal xstartup with Openbox (lighter than XFCE)
RUN cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
xsetroot -solid grey
vncconfig -iconic &

# Start Openbox (much lighter than XFCE)
openbox-session &

# Start Dillo browser automatically (optional)
# sleep 2 && dillo &

# Start minimal panel (optional - comment out to save more memory)
# tint2 &
EOF

RUN chmod +x /root/.vnc/xstartup

# Get noVNC
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt/ && \
    mv /opt/noVNC-1.4.0 /opt/novnc && \
    rm /tmp/novnc.tar.gz && \
    wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O /tmp/websockify.tar.gz && \
    tar -xzf /tmp/websockify.tar.gz -C /opt/novnc/utils/ && \
    mv /opt/novnc/utils/websockify-0.11.0 /opt/novnc/utils/websockify && \
    rm /tmp/websockify.tar.gz

# Copy noVNC HTML
RUN cp /opt/novnc/vnc_lite.html /opt/novnc/index.html

# Create Openbox menu without terminal entries
RUN mkdir -p /root/.config/openbox && \
    cat > /root/.config/openbox/menu.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu xmlns="http://openbox.org/3.4/menu">
<menu id="root-menu" label="Applications">
  <item label="Dillo Browser">
    <action name="Execute">
      <command>dillo</command>
    </action>
  </item>
  <item label="File Manager">
    <action name="Execute">
      <command>pcmanfm</command>
    </action>
  </item>
  <separator />
  <item label="Exit">
    <action name="Exit">
      <prompt>yes</prompt>
    </action>
  </item>
</menu>
</openbox_menu>
EOF

EXPOSE 10000

# Startup script
CMD echo "Starting VNC server..." && \
    vncserver :1 -geometry ${VNC_RESOLUTION} -depth ${VNC_DEPTH} -localhost no && \
    echo "VNC started on :1" && \
    echo "Starting noVNC..." && \
    /opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 --heartbeat 30 --web /opt/novnc && \
    tail -f /dev/null
