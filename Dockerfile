FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV VNC_PASSWORD=password123

# Install TigerVNC (better WebSocket handling)
RUN apt update && apt install -y \
    tigervnc-standalone-server \
    tigervnc-common \
    xvfb \
    fluxbox \
    firefox \
    python3 \
    python3-pip \
    nginx \
    --no-install-recommends && \
    apt clean

# Install websockify (handles HEAD requests properly)
RUN pip3 install websockify

# Setup VNC password
RUN mkdir -p ~/.vnc && \
    echo ${VNC_PASSWORD} | vncpasswd -f > ~/.vnc/passwd && \
    chmod 600 ~/.vnc/passwd

# Create xstartup
RUN echo '#!/bin/bash
fluxbox &
sleep 2
firefox about:blank' > ~/.vnc/xstartup && \
    chmod +x ~/.vnc/xstartup

# Create HTML with noVNC
RUN mkdir -p /var/www/html && \
    cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>VNC Desktop</title>
    <meta charset="UTF-8">
    <style>
        body, html { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; }
        #screen { width: 100%; height: 100%; background: black; }
        #status { position: fixed; bottom: 10px; left: 10px; background: rgba(0,0,0,0.7); color: white; padding: 10px; }
        #connect-btn { position: fixed; top: 10px; left: 10px; padding: 10px 20px; background: #4CAF50; color: white; border: none; cursor: pointer; }
    </style>
    <script src="https://cdn.jsdelivr.net/npm/@novnc/novnc@1.4.0/lib/rfb.min.js"></script>
</head>
<body>
    <button id="connect-btn" onclick="connectVNC()">Connect VNC</button>
    <div id="screen"></div>
    <div id="status">Ready</div>
    
    <script>
        let rfb = null;
        
        function connectVNC() {
            const btn = document.getElementById('connect-btn');
            btn.disabled = true;
            btn.textContent = 'Connecting...';
            document.getElementById('status').textContent = 'Connecting...';
            
            const host = window.location.hostname;
            const protocol = window.location.protocol === 'https:' ? 'wss://' : 'ws://';
            
            // Connect to port 80/443 (Render's proxy) which forwards to 6080
            const wsUrl = protocol + host + '/websockify';
            
            console.log('WebSocket URL:', wsUrl);
            
            rfb = new RFB(document.getElementById('screen'), wsUrl, {
                credentials: { password: 'password123' },
                shared: true
            });
            
            rfb.addEventListener('connect', () => {
                document.getElementById('status').textContent = 'Connected!';
                btn.textContent = 'Disconnect';
                btn.disabled = false;
                btn.onclick = disconnectVNC;
            });
            
            rfb.addEventListener('disconnect', (e) => {
                document.getElementById('status').textContent = 'Disconnected';
                btn.textContent = 'Reconnect';
                btn.disabled = false;
                btn.onclick = connectVNC;
                if (!e.detail.clean) {
                    setTimeout(connectVNC, 3000);
                }
            });
        }
        
        function disconnectVNC() {
            if (rfb) {
                rfb.disconnect();
                rfb = null;
            }
            const btn = document.getElementById('connect-btn');
            btn.textContent = 'Connect VNC';
            btn.onclick = connectVNC;
            document.getElementById('status').textContent = 'Disconnected by user';
        }
        
        // Auto-connect
        setTimeout(connectVNC, 1000);
    </script>
</body>
</html>
EOF

# Nginx config that handles WebSocket properly
RUN cat > /etc/nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream websockify {
        server 127.0.0.1:6080;
    }
    
    server {
        listen 80;
        
        root /var/www/html;
        index index.html;
        
        location / {
            try_files $uri $uri/ =404;
        }
        
        # WebSocket proxy - handles HEAD requests properly
        location /websockify {
            proxy_pass http://websockify;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            
            # Handle HEAD requests (Render health checks)
            if ($request_method = HEAD) {
                return 200;
            }
            
            # Important timeouts
            proxy_connect_timeout 7d;
            proxy_send_timeout 7d;
            proxy_read_timeout 7d;
        }
    }
}
EOF

EXPOSE 80

# Startup script
CMD echo "=== Starting VNC Desktop ===" && \
    # Clean up
    rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true && \
    # Start Xvfb
    echo "Starting X virtual framebuffer..." && \
    Xvfb :1 -screen 0 1024x768x24 & \
    sleep 3 && \
    # Start fluxbox
    echo "Starting window manager..." && \
    fluxbox & \
    sleep 2 && \
    # Start Firefox
    echo "Starting Firefox..." && \
    firefox about:blank & \
    sleep 2 && \
    # Start TigerVNC
    echo "Starting VNC server..." && \
    vncserver :1 -geometry 1024x768 -depth 24 -localhost no & \
    sleep 2 && \
    # Start websockify (handles HEAD requests)
    echo "Starting WebSocket proxy..." && \
    websockify 6080 localhost:5901 & \
    sleep 2 && \
    # Start nginx
    echo "Starting nginx..." && \
    echo "=== Ready ===" && \
    echo "Access: https://$(hostname)" && \
    echo "Password: ${VNC_PASSWORD}" && \
    nginx -g 'daemon off;'
