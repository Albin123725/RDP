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

# Create self-signed SSL certificate
RUN mkdir -p /opt/novnc/utils/websockify && \
    cd /opt/novnc/utils/websockify && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout self.pem -out self.pem \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" && \
    chmod 600 self.pem

# Create ULTIMATE FIX index.html
RUN cat > /opt/novnc/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>VNC Desktop</title>
    <meta charset="utf-8">
    <script src="app/ui.js"></script>
    <script>
    window.addEventListener('load', function() {
        console.log("VNC Desktop Loaded");
        
        // Get current URL
        const url = window.location;
        const host = url.hostname;
        const protocol = url.protocol;
        
        // Determine WebSocket protocol (ws:// or wss://)
        const wsProtocol = protocol === 'https:' ? 'wss://' : 'ws://';
        
        // On Render, we need to connect to /websockify path
        console.log("Protocol:", protocol, "WebSocket Protocol:", wsProtocol);
        console.log("Host:", host);
        
        // Try connecting - Render will route to port 8080 internally
        // The path MUST be 'websockify' (no slash at beginning)
        setTimeout(function() {
            console.log("Attempting to connect...");
            UI.connect(host, '', 'password123', 'websockify');
        }, 1000);
        
        // Alternative method after 3 seconds
        setTimeout(function() {
            if (!window.connected) {
                console.log("Trying alternative connection method...");
                // Try with explicit path
                UI.connect(host, '8080', 'password123', 'websockify');
            }
        }, 3000);
    });
    
    // Track connection status
    window.connected = false;
    window.addEventListener('UIConnected', function() {
        console.log("CONNECTED!");
        window.connected = true;
        document.getElementById('status').style.display = 'none';
    });
    </script>
    <style>
        body { margin: 0; padding: 0; background: #2d2d2d; color: white; font-family: Arial; }
        #status { 
            position: fixed; top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(0,0,0,0.9); 
            display: flex; flex-direction: column;
            justify-content: center; align-items: center;
            z-index: 1000;
        }
        #connect_btn {
            background: #4CAF50; color: white; border: none;
            padding: 15px 30px; margin: 20px; border-radius: 4px;
            cursor: pointer; font-size: 18px; font-weight: bold;
        }
        .info { margin: 10px; color: #ccc; }
        #noVNC_screen { width: 100vw; height: 100vh; }
    </style>
</head>
<body>
    <div id="status">
        <h1>🖥️ VNC Desktop</h1>
        <div class="info">Host: rdp-00jy.onrender.com</div>
        <div class="info">Password: password123</div>
        <div class="info" id="connection_status">Connecting to WebSocket...</div>
        <button id="connect_btn" onclick="connectManual()">Click to Connect</button>
        <div class="info" style="margin-top: 30px; font-size: 12px;">
            If stuck, try: <a href="/vnc_lite.html" style="color: #4CAF50;">/vnc_lite.html</a>
        </div>
    </div>
    <div id="noVNC_screen"></div>
    
    <script>
    function connectManual() {
        console.log("Manual connect attempt...");
        const host = window.location.hostname;
        
        // Try multiple connection methods
        try {
            UI.connect(host, '', 'password123', 'websockify');
        } catch(e) {
            console.log("Method 1 failed:", e);
            try {
                UI.connect(host, '8080', 'password123', 'websockify');
            } catch(e2) {
                console.log("Method 2 failed:", e2);
                alert("Connection failed. Check browser console (F12) for errors.");
            }
        }
    }
    
    // Update status
    setInterval(function() {
        const elem = document.getElementById('connection_status');
        if (window.connected) {
            elem.innerHTML = "✅ CONNECTED! Desktop should be visible.";
        } else {
            elem.innerHTML = "Attempting WebSocket connection... " + new Date().toLocaleTimeString();
        }
    }, 1000);
    </script>
</body>
</html>
EOF

# Create SIMPLE vnc_lite.html with same-port connection
RUN cat > /opt/novnc/vnc_lite.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>noVNC Lite</title>
    <meta charset="utf-8">
    <script src="app/ui.js"></script>
    <script>
    window.addEventListener('load', function() {
        // Connect to WebSocket on SAME PORT as the page
        const host = window.location.hostname;
        UI.connect(host, '', 'password123', 'websockify');
    });
    </script>
</head>
<body>
    <div id="noVNC_screen"></div>
</body>
</html>
EOF

# Create startup script - ONLY USE PORT 8080 (Render-accessible)
RUN cat > /start.sh << 'EOF'
#!/bin/bash

echo "=== STARTING VNC DESKTOP FOR RENDER ==="
echo "Using port 8080 for both HTTP and WebSocket"

# Clean up
pkill -9 x11vnc 2>/dev/null || true
pkill -9 Xvfb 2>/dev/null || true
pkill -9 python3 2>/dev/null || true
fuser -k 5901/tcp 2>/dev/null || true
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
x11vnc -display :99 -forever -shared -rfbauth /root/.vnc/passwd -rfbport 5901 -bg
sleep 2

# CRITICAL: Start websockify on PORT 8080 (not 10000) with VERBOSE logging
echo "4. Starting websockify WITH SSL on port 8080"
cd /opt/novnc/utils/websockify
# Use --web for serving HTML, --cert for SSL, port 8080 for WebSocket, --verbose for debugging
python3 -m websockify --web /opt/novnc --cert ./self.pem --verbose 0.0.0.0:8080 localhost:5901 2>&1 | tee /var/log/websockify.log &
sleep 3

# Verification
echo ""
echo "=== STATUS ==="
echo "x11vnc (5901):      $(netstat -tuln | grep :5901 >/dev/null && echo '✓ LISTENING' || echo '✗ NOT LISTENING')"
echo "websockify (8080):  $(netstat -tuln | grep :8080 >/dev/null && echo '✓ LISTENING' || echo '✗ NOT LISTENING')"
echo ""
echo "=== HOW RENDER WORKS ==="
echo "1. You visit: https://rdp-00jy.onrender.com"
echo "2. Render routes to port 8080 in container"
echo "3. WebSocket connects to wss://rdp-00jy.onrender.com/websockify"
echo "4. All traffic goes through port 8080"
echo ""
echo "=== ACCESS NOW ==="
echo "1. Main: https://${RENDER_EXTERNAL_HOSTNAME:-localhost}/"
echo "2. Lite: https://${RENDER_EXTERNAL_HOSTNAME:-localhost}/vnc_lite.html"
echo ""
echo "Password: $VNC_PASSWD"
echo ""
echo "=== TROUBLESHOOTING ==="
echo "If still 'Connecting...':"
echo "1. Open browser console (F12 → Console)"
echo "2. Check for WebSocket errors"
echo "3. Try direct VNC: rdp-00jy.onrender.com:5901 (password: $VNC_PASSWD)"
echo "========================================="

# Keep container alive
tail -f /dev/null
EOF

RUN chmod +x /start.sh

# EXPOSE ONLY 8080 - Render will use this
EXPOSE 8080

CMD ["/start.sh"]
