FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Kolkata
ENV USER=root
ENV HOME=/root
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
    python3 \
    novnc \
    websockify \
    --no-install-recommends && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create PROPER VNC password (not just text file)
RUN mkdir -p /root/.vnc && \
    x11vnc -storepasswd "$VNC_PASSWD" /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Link novnc files
RUN ln -s /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html

# Create a SIMPLE WORKING HTML file
RUN cat > /usr/share/novnc/simple.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>VNC Desktop</title>
    <meta charset="utf-8">
    <script>
    // Load noVNC
    function loadVNC() {
        const script = document.createElement('script');
        script.src = 'app/ui.js';
        script.onload = function() {
            console.log('noVNC loaded');
            // Auto-connect after 1 second
            setTimeout(connectVNC, 1000);
        };
        script.onerror = function() {
            document.body.innerHTML = 
                '<div style="padding: 20px; text-align: center;">' +
                '<h2>VNC Desktop</h2>' +
                '<p><strong>Connect using VNC Client:</strong></p>' +
                '<p>Address: <code>rdp-00jy.onrender.com:5901</code></p>' +
                '<p>Password: <code>password123</code></p>' +
                '<p><a href="https://www.realvnc.com/en/connect/download/viewer/" target="_blank">Download VNC Viewer</a></p>' +
                '</div>';
        };
        document.head.appendChild(script);
    }
    
    function connectVNC() {
        try {
            // Connect to WebSocket
            UI.connect(window.location.hostname, '', 'password123', 'websockify');
            console.log('Connection attempt sent');
        } catch(e) {
            console.error('Connection error:', e);
            alert('Connection failed. Please use VNC client instead.');
        }
    }
    
    window.onload = loadVNC;
    </script>
    <style>
        body { margin: 0; padding: 0; background: #222; }
        #noVNC_screen { width: 100vw; height: 100vh; }
        #status { 
            position: fixed; top: 10px; left: 10px; 
            background: rgba(0,0,0,0.8); color: white; 
            padding: 10px; border-radius: 5px; z-index: 1000;
        }
    </style>
</head>
<body>
    <div id="status">Loading VNC desktop...</div>
    <div id="noVNC_screen"></div>
</body>
</html>
EOF

# Create startup script with PROPER VNC configuration
RUN cat > /start.sh << 'EOF'
#!/bin/bash

echo "=== STARTING VNC DESKTOP ==="

# Kill any existing processes
pkill -9 x11vnc 2>/dev/null || true
pkill -9 Xvfb 2>/dev/null || true
pkill -9 websockify 2>/dev/null || true
fuser -k 5901/tcp 2>/dev/null || true
fuser -k 8080/tcp 2>/dev/null || true

# Start Xvfb
export DISPLAY=:99
echo "Starting Xvfb..."
Xvfb :99 -screen 0 ${VNC_RESOLUTION}x${VNC_DEPTH} &
sleep 3

# Start fluxbox
echo "Starting Fluxbox..."
fluxbox &
sleep 2

# Start x11vnc with PROPER authentication
echo "Starting x11vnc on port 5901..."
x11vnc -display :99 -forever -shared -rfbauth /root/.vnc/passwd -rfbport 5901 -bg -auth /tmp/.X99-auth -noxdamage
sleep 2

# Start websockify
echo "Starting websockify on port 8080..."
websockify --web /usr/share/novnc 0.0.0.0:8080 localhost:5901 &
sleep 2

echo ""
echo "=== STATUS ==="
echo "x11vnc:     $(netstat -tuln | grep :5901 >/dev/null && echo '✓ Running' || echo '✗ Failed')"
echo "websockify: $(netstat -tuln | grep :8080 >/dev/null && echo '✓ Running' || echo '✗ Failed')"
echo ""
echo "=== ACCESS ==="
echo "Web: https://${RENDER_EXTERNAL_HOSTNAME:-localhost}/"
echo "Web: https://${RENDER_EXTERNAL_HOSTNAME:-localhost}/simple.html"
echo "VNC Client: ${RENDER_EXTERNAL_HOSTNAME:-localhost}:5901"
echo "Password: $VNC_PASSWD"
echo "======================================"

# Keep running
tail -f /dev/null
EOF

RUN chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
