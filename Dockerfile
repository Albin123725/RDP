FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Kolkata
ENV USER=root
ENV HOME=/root
ENV DISPLAY=:1
ENV VNC_PASSWD=password123
ENV VNC_RESOLUTION=1024x768
ENV VNC_DEPTH=24

# Set timezone
RUN ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo "Asia/Kolkata" > /etc/timezone

# First, install tightvncserver and core packages
RUN apt update && apt install -y \
    tightvncserver \
    xserver-xorg-core \
    xinit \
    novnc \
    websockify \
    wget \
    curl \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    xfonts-base \
    openbox \
    chromium-browser \
    chromium-codecs-ffmpeg \
    firefox-esr \
    fonts-liberation \
    fonts-noto \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    libnss3 \
    libxss1 \
    libasound2 \
    libgbm1 \
    libgtk-3-0 \
    libu2f-udev \
    libvulkan1 \
    htop \
    nano \
    --no-install-recommends

# Setup VNC password - NOW vncpasswd should be available
RUN mkdir -p /root/.vnc && \
    echo "${VNC_PASSWD}" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Continue with cleanup and other installations
RUN apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    apt purge -y '*xfce*' 'gnome*' 'kde*' 'libreoffice*' || true && \
    apt purge -y 'thunderbird*' 'rhythmbox*' 'shotwell*' || true && \
    find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name "en*" ! -name "C" ! -name "C.UTF-8" -exec rm -rf {} \; 2>/dev/null || true && \
    apt autoremove -y && \
    apt autoclean

# Create xstartup with browser launcher
RUN cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
xsetroot -solid grey
vncconfig -iconic &

# Start Openbox
openbox-session &

# Wait for desktop to initialize
sleep 2

# Create desktop shortcuts
cat > /root/Desktop/chromium.desktop << 'DESKEOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Chromium (Fast)
Comment=Chromium browser for heavy websites
Exec=chromium-browser %U --disable-dev-shm-usage --no-sandbox --disable-gpu --window-size=1024,768
Icon=chromium-browser
Terminal=false
Categories=Network;WebBrowser;
DESKEOF

cat > /root/Desktop/firefox.desktop << 'DESKEOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Firefox
Comment=Firefox browser
Exec=firefox-esr %U
Icon=firefox-esr
Terminal=false
Categories=Network;WebBrowser;
DESKEOF

cat > /root/Desktop/colab.desktop << 'DESKEOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Google Colab
Comment=Open Google Colab
Exec=chromium-browser https://colab.research.google.com/ --disable-dev-shm-usage --no-sandbox --disable-gpu --window-size=1024,768
Icon=chromium-browser
Terminal=false
Categories=Network;WebBrowser;
DESKEOF

cat > /root/Desktop/firebase.desktop << 'DESKEOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Firebase Console
Comment=Open Firebase Console
Exec=chromium-browser https://console.firebase.google.com/ --disable-dev-shm-usage --no-sandbox --disable-gpu --window-size=1024,768
Icon=chromium-browser
Terminal=false
Categories=Network;WebBrowser;
DESKEOF

chmod +x /root/Desktop/*.desktop

# Start Chromium with blank page
# chromium-browser about:blank --disable-dev-shm-usage --no-sandbox --disable-gpu &
EOF

RUN chmod +x /root/.vnc/xstartup

# Fix vncserver font path issue
RUN sed -i 's/\$fontPath = ".*"/\$fontPath = ""/' /usr/bin/vncserver && \
    mkdir -p /usr/share/fonts/X11/misc && \
    touch /root/.Xauthority

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

# Create Openbox menu with browser options
RUN mkdir -p /root/.config/openbox && \
    cat > /root/.config/openbox/menu.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu xmlns="http://openbox.org/3.4/menu">
<menu id="root-menu" label="Applications">
  <menu id="browsers" label="Web Browsers">
    <item label="Chromium (for Colab/Firebase)">
      <action name="Execute">
        <command>chromium-browser --disable-dev-shm-usage --no-sandbox --disable-gpu</command>
      </action>
    </item>
    <item label="Firefox">
      <action name="Execute">
        <command>firefox-esr</command>
      </action>
    </item>
  </menu>
  <menu id="websites" label="Quick Links">
    <item label="Google Colab">
      <action name="Execute">
        <command>chromium-browser https://colab.research.google.com/ --disable-dev-shm-usage --no-sandbox --disable-gpu</command>
      </action>
    </item>
    <item label="Firebase Console">
      <action name="Execute">
        <command>chromium-browser https://console.firebase.google.com/ --disable-dev-shm-usage --no-sandbox --disable-gpu</command>
      </action>
    </item>
    <item label="GitHub">
      <action name="Execute">
        <command>chromium-browser https://github.com/ --disable-dev-shm-usage --no-sandbox --disable-gpu</command>
      </action>
    </item>
  </menu>
  <separator />
  <item label="Exit">
    <action name="Exit">
      <prompt>yes</prompt>
    </action>
  </item>
</menu>
</openbox_menu>
EOF

# Create Chromium configuration for low memory
RUN mkdir -p /etc/chromium-browser && \
    echo 'CHROMIUM_FLAGS="--disable-dev-shm-usage --no-sandbox --disable-gpu --disable-software-rasterizer --max_old_space_size=512 --single-process"' > /etc/chromium-browser/default

# Add swap file for heavy websites
RUN fallocate -l 512M /swapfile && \
    chmod 600 /swapfile && \
    mkswap /swapfile

EXPOSE 10000

# Startup script
CMD echo "Starting VNC server..." && \
    # Enable swap
    swapon /swapfile && \
    echo "Swap enabled" && \
    # Start VNC
    vncserver :1 -geometry ${VNC_RESOLUTION} -depth ${VNC_DEPTH} && \
    echo "VNC started on :1" && \
    echo "Starting noVNC..." && \
    /opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 --heartbeat 30 --web /opt/novnc && \
    tail -f /dev/null
