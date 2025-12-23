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

# Install packages
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
    openssl \
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

# Download latest noVNC
RUN cd /opt && \
    wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O novnc.tar.gz && \
    tar -xzf novnc.tar.gz && \
    mv noVNC-1.4.0 novnc && \
    rm novnc.tar.gz

# Download websockify
RUN cd /opt/novnc/utils && \
    wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O websockify.tar.gz && \
    tar -xzf websockify.tar.gz && \
    mv websockify-0.11.0 websockify && \
    rm websockify.tar.gz

# Create self-signed SSL certificate for WebSocket (required for HTTPS)
RUN mkdir -p /opt/novnc/utils/websockify && \
    cd /opt/novnc/utils/websockify && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout self.pem -out self.pem \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" && \
    chmod 600 self.pem

# Create ULTRA-SIMPLE index.html that auto-connects
RUN cat > /opt/novnc/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>VNC Desktop - Ready</title>
    <meta charset="utf-8">
    <script src="app/ui.js"></script>
    <script>
    window.addEventListener('load', function() {
        console.log("Page loaded, attempting to connect...");
        
        // Get current URL
        const url = new URL(window.location.href);
        const host = url.hostname;
        
        // For Render: Connect via wss:// on same host, port 10000
        // Use path 'websockify' as required by websockify
        const rfbUrl = 'wss://' + host + ':10000/websockify';
        
        console.log("Connecting to:", rfbUrl);
        
        // Auto-connect after short delay
        setTimeout(function() {
            UI.connect(host, '10000', 'password123', 'websockify');
        }, 100);
    });
    </script>
    <style>
        body { margin: 0; padding: 0; background: #2d2d2d; color: white; font-family: Arial; }
        #status { position: fixed; top: 20px; left: 20px; background: #333; padding: 10px; border-radius: 5px; }
        #noVNC_screen { width: 100vw; height: 100vh; }
    </style>
</head>
<body>
    <div id="status">Connecting to VNC Desktop...</div>
    <div id="noVNC_screen"></div>
</body>
</html>
EOF

# Create SIMPLE vnc.html that works
RUN cat > /opt/novnc/vnc.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>noVNC</title>
    <meta charset="utf-8">
    <script src="app/ui.js"></script>
    <script>
    window.addEventListener('load', function() {
        const url = new URL(window.location.href);
        const host = url.hostname;
        
        // Auto-connect
        UI.connect(host, '10000', 'password123', 'websockify');
    });
    </script>
</head>
<body>
    <div id="noVNC_screen"></div>
</body>
</html>
EOF

# Also copy vnc_lite.html
RUN cp /opt/novnc/vnc_lite.html /opt/novnc/

# Create startup script with SSL/TLS
RUN cat > /start.sh << 'EOF'
#!/bin/bash

echo "=== STARTING VNC DESKTOP (WITH SSL) ==="

# Clean up
pkill -9 x11vnc 2>/dev/null || true
pkill -9 Xvfb 2>/dev/null || true
pkill -9 python3 2>/dev/null || true
fuser -k 5901/tcp 2>/dev/null || true
fuser -k 10000/tcp 2>/dev/null || true
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
x11vnc -display :99 -forever -shared -rfbauth /root/.vnc/passwd -rfbport 5901 -bg
sleep 2

# Start websockify WITH SSL/TLS (CRITICAL FOR RENDER HTTPS)
echo "4. Starting websockify WITH SSL on port 10000"
cd /opt/novnc/utils/websockify
python3 -m websockify --web /opt/novnc --cert ./self.pem 0.0.0.0:10000 localhost:5901 &
sleep 3

# Start simple Python HTTP server on 8080 (optional fallback)
echo "5. Starting HTTP server on 8080"
cd /opt/novnc
python3 -m http.server 8080 &
sleep 2

# Verification
echo ""
echo "=== STATUS ==="
echo "x11vnc (5901):     $(netstat -tuln | grep :5901 >/dev/null && echo '✓ LISTENING' || echo '✗ NOT LISTENING')"
echo "websockify (10000): $(netstat -tuln | grep :10000 >/dev/null && echo '✓ LISTENING' || echo '✗ NOT LISTENING')"
echo "HTTP (8080):       $(netstat -tuln | grep :8080 >/dev/null && echo '✓ LISTENING' || echo '✗ NOT LISTENING')"
echo ""
echo "=== ACCESS YOUR DESKTOP ==="
echo "MAIN URL (Use this): https://${RENDER_EXTERNAL_HOSTNAME:-localhost}/"
echo "ALTERNATIVE: https://${RENDER_EXTERNAL_HOSTNAME:-localhost}/vnc.html"
echo "ALTERNATIVE: https://${RENDER_EXTERNAL_HOSTNAME:-localhost}/vnc_lite.html"
echo ""
echo "PASSWORD: $VNC_PASSWD"
echo ""
echo "If still 'loading', check browser console (F12) for WebSocket errors"
echo "=============================================="

# Keep container alive
tail -f /dev/null
EOF

RUN chmod +x /start.sh

EXPOSE 10000 8080

CMD ["/start.sh"]
