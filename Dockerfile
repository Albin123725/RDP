FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Kolkata
ENV USER=root
ENV HOME=/root
ENV DISPLAY=:1
ENV VNC_PASSWD=password123
ENV VNC_RESOLUTION=1024x576
ENV VNC_DEPTH=16

# Set timezone
RUN ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo "Asia/Kolkata" > /etc/timezone

# Install only essential packages
RUN apt update && apt install -y \
    xfce4 \
    xfce4-terminal \
    xfce4-panel \
    xfdesktop4 \
    thunar \
    firefox \
    tightvncserver \
    novnc \
    websockify \
    wget \
    --no-install-recommends && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    # Remove unnecessary components
    apt purge -y \
        xfce4-screensaver \
        xfce4-power-manager \
        xfce4-taskmanager \
        xfce4-appfinder \
        xfce4-clipman \
        xfce4-notifyd \
        xfce4-volumed \
        mousepad \
        orage \
        parole \
        ristretto \
        thunar-archive-plugin \
        thunar-media-tags-plugin \
        xfburn \
        xfce4-cpufreq-plugin \
        xfce4-dict \
        xfce4-mailwatch-plugin \
        xfce4-netload-plugin \
        xfce4-notes-plugin \
        xfce4-places-plugin \
        xfce4-sensors-plugin \
        xfce4-smartbookmark-plugin \
        xfce4-systemload-plugin \
        xfce4-timer-plugin \
        xfce4-verve-plugin \
        xfce4-weather-plugin \
        xfce4-whiskermenu-plugin \
        xfce4-wavelan-plugin && \
    apt autoremove -y && \
    apt autoclean && \
    # Remove more unnecessary files
    rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/locale/* /usr/share/icons/*

# Setup VNC
RUN mkdir -p /root/.vnc && \
    echo "$VNC_PASSWD" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Minimal xstartup with only what we need
RUN cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
xsetroot -solid grey
# Start Xfce with minimal components
xfwm4 --daemon --compositor=off
xfdesktop &
xfce4-panel &
xfce4-terminal &
thunar &
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

# Configure Firefox for Google Colab (minimal settings)
RUN mkdir -p /root/.mozilla/firefox/default && \
    cat > /root/.mozilla/firefox/default/prefs.js << 'EOF'
// Disable updates and telemetry
user_pref("app.update.auto", false);
user_pref("app.update.enabled", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("devtools.onboarding.telemetry.logged", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("toolkit.telemetry.bhrPing.enabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
user_pref("toolkit.telemetry.hybridContent.enabled", false);
user_pref("toolkit.telemetry.newProfilePing.enabled", false);
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.updatePing.enabled", false);

// Performance optimizations
user_pref("browser.cache.disk.enable", false);
user_pref("browser.cache.memory.enable", true);
user_pref("browser.sessionhistory.max_total_viewers", 0);
user_pref("browser.sessionstore.interval", 60000);
user_pref("browser.startup.page", 0);
user_pref("browser.tabs.animate", false);
user_pref("browser.urlbar.suggest.searches", false);
user_pref("dom.ipc.processCount", 1);
user_pref("extensions.pocket.enabled", false);
user_pref("gfx.canvas.accelerated", false);
user_pref("gfx.webrender.all", false);
EOF

# Copy noVNC HTML files for health check
RUN cp /opt/novnc/vnc_lite.html /opt/novnc/index.html

# Fix vncserver font path issue
RUN sed -i 's/^.*\$fontPath.*=.*/\$fontPath = "";/' /usr/bin/vncserver

EXPOSE 10000

# Simple startup script
CMD echo "Starting VNC server..." && \
    vncserver :1 -geometry ${VNC_RESOLUTION} -depth ${VNC_DEPTH} && \
    echo "VNC started successfully" && \
    echo "Starting noVNC proxy..." && \
    /opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 --heartbeat 30 --web /opt/novnc
