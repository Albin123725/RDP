FROM ubuntu:22.04

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

# Install packages (REMOVE novnc and websockify packages - we'll install manually)
RUN apt update && apt install -y \
    fluxbox \
    xterm \
    thunar \
    firefox \
    x11vnc \
    xvfb \
    net-tools \
    x11-xserver-utils \
    xfonts-base \
    python3 \
    python3-numpy \
    dbus-x11 \
    wget \
    unzip \
    --no-install-recommends && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create VNC password file
RUN mkdir -p /root/.vnc && \
    echo "$VNC_PASSWD" > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Configure Firefox
RUN mkdir -p /root/.mozilla/firefox/default && \
    cat > /root/.mozilla/firefox/default/prefs.js << 'EOF'
user_pref("app.update.auto", false);
user_pref("app.update.enabled", false);
user_pref("browser.startup.page", 0);
user_pref("dom.ipc.processCount", 1);
EOF

# Create fluxbox menu
RUN mkdir -p /root/.fluxbox && \
    cat > /root/.fluxbox/menu << 'EOF'
[begin] (Applications)
  [exec] (Terminal) {xterm}
  [exec] (File Manager) {thunar}
  [exec] (Firefox) {firefox}
  [separator]
  [exit] (Exit)
[end]
EOF

# Create startup file
RUN cat > /root/.fluxbox/startup << 'EOF'
#!/bin/sh
xterm -geometry 80x24+10+10 &
thunar &
firefox &
EOF
RUN chmod +x /root/.fluxbox/startup

# DOWNLOAD LATEST NOVNC from GitHub (not Ubuntu package)
RUN cd /opt && \
    wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O novnc.tar.gz && \
    tar -xzf novnc.tar.gz && \
    mv noVNC-1.4.0 novnc && \
    rm novnc.tar.gz && \
    # Download websockify
    cd /opt/novnc/utils && \
    wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O websockify.tar.gz && \
    tar -xzf websockify.tar.gz && \
    mv websockify-0.11.0 websockify && \
    rm websockify.tar.gz

# Create a SIMPLE index.html that works with latest noVNC
RUN cat > /opt/novnc/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>VNC Desktop</title>
    <meta charset="utf-8">
    <style>
        body { margin: 0; padding: 0; background: #2d2d2d; }
        #noVNC_container { width: 100vw; height: 100vh; }
        #noVNC_connect_button { 
            position: fixed; top: 20px; left: 20px; 
            background: #4CAF50; color: white; border: none; 
            padding: 10px 20px; border-radius: 4px; cursor: pointer;
            font-size: 16px; z-index: 1000;
        }
    </style>
</head>
<body>
    <button id="noVNC_connect_button">Connect to VNC</button>
    <div id="noVNC_container"></div>
    
    <script type="module">
        import RFB from './app/rfb.js';
        
        document.getElementById('noVNC_connect_button').onclick = function() {
            this.style.display = 'none';
            
            const host = window.location.hostname;
            const port = window.location.port || (window.location.protocol === 'https:' ? '443' : '80');
            const path = 'websockify';
            
            // Create RFB object
            const rfb = new RFB(document.getElementById('noVNC_container'), 
                `wss://${host}:${port}/${path}`, {
                credentials: { password: 'password123' }
            });
            
            rfb.addEventListener("connect", () => console.log("Connected!"));
            rfb.addEventListener("disconnect", () => console.log("Disconnected"));
            rfb.addEventListener("credentialsrequired", () => console.log("Credentials required"));
            rfb.addEventListener("securityfailure", (e) => console.log("Security failure:", e.detail));
            rfb.addEventListener("clipboard", (e) => console.log("Clipboard:", e.detail));
            rfb.addEventListener("bell", () => console.log("Bell!"));
            rfb.addEventListener("desktopname", (e) => console.log("Desktop name:", e.detail));
        };
    </script>
</body>
</html>
EOF

# Also copy vnc_lite.html as backup
RUN cp /opt/novnc/vnc_lite.html /opt/novnc/vnc_lite.html.backup

# Create SIMPLE vnc_lite.html that definitely works
RUN cat > /opt/novnc/vnc_lite.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>noVNC Lite</title>
    <meta charset="utf-8">
    <script src="./app/ui.js"></script>
    <script>
    "use strict";
    window.addEventListener('load', function() {
        const UI = window.UI;
        const host = window.location.hostname;
        const port = window.location.port || (window.location.protocol === 'https:' ? '443' : '80');
        const path = 'websockify';
        
        // Auto-connect after 1 second
        setTimeout(function() {
            UI.connect(host, port, 'password123', path);
        }, 1000);
    });
    </script>
</head>
<body>
    <div id="noVNC_screen"></div>
</body>
</html>
EOF

# Create startup script that uses Python websockify module directly
RUN cat > /start.sh << 'EOF'
#!/bin/bash

echo "=== Starting VNC Desktop Environment ==="

# Clean up
pkill -9 x11vnc 2>/dev/null || true
pkill -9 Xvfb 2>/dev/null || true
pkill -9 python3 2>/dev/null || true
fuser -k 5901/tcp 2>/dev/null || true
fuser -k 10000/tcp 2>/dev/null || true
fuser -k 8080/tcp 2>/dev/null || true
rm -rf /tmp/.X11-unix/* /tmp/.X*-lock 2>/dev/null || true

# Start Xvfb
echo "1. Starting Xvfb on :99"
export DISPLAY=:99
Xvfb :99 -screen 0 ${VNC_RESOLUTION}x${VNC_DEPTH} &
sleep 3

# Start fluxbox
echo "2. Starting Fluxbox"
fluxbox &
sleep 2

# Start x11vnc
echo "3. Starting x11vnc on port 5901"
x11vnc -display :99 -forever -shared -rfbauth /root/.vnc/passwd -rfbport 5901 -bg -noxdamage -nowf -noscr
sleep 2

# Start websockify (WebSocket proxy)
echo "4. Starting websockify WebSocket proxy on port 10000"
cd /opt/novnc/utils/websockify
python3 -m websockify --web /opt/novnc 0.0.0.0:10000 localhost:5901 &
sleep 2

# Start simple HTTP server on port 8080
echo "5. Starting HTTP server on port 8080"
cd /opt/novnc
python3 -m http.server 8080 &
sleep 2

# Verification
echo "=== SERVICE STATUS ==="
echo "x11vnc:     $(pgrep x11vnc >/dev/null && echo '✓ RUNNING (port 5901)' || echo '✗ FAILED')"
echo "websockify: $(pgrep -f 'websockify.*10000' >/dev/null && echo '✓ RUNNING (port 10000)' || echo '✗ FAILED')"
echo "HTTP:       $(netstat -tuln | grep :8080 >/dev/null && echo '✓ RUNNING (port 8080)' || echo '✗ NOT RUNNING')"
echo "Xvfb:       $(pgrep Xvfb >/dev/null && echo '✓ RUNNING' || echo '✗ FAILED')"
echo ""
echo "=== HOW TO CONNECT ==="
echo "OPTION 1 (Recommended): https://${RENDER_EXTERNAL_HOSTNAME:-localhost}/"
echo "OPTION 2: https://${RENDER_EXTERNAL_HOSTNAME:-localhost}/vnc_lite.html"
echo "OPTION 3: Use VNC client to connect to: ${RENDER_EXTERNAL_HOSTNAME:-localhost}:5901"
echo "Password for all: $VNC_PASSWD"
echo "======================================"

# Keep container alive
tail -f /dev/null
EOF

RUN chmod +x /start.sh

EXPOSE 10000

CMD ["/start.sh"]
