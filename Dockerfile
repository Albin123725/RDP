FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV VNC_PASSWORD=password123
ENV DISPLAY=:1

# Install packages
RUN apt update && apt install -y \
    x11vnc \
    xvfb \
    fluxbox \
    firefox \
    python3 \
    python3-pip \
    nginx \
    --no-install-recommends && \
    apt clean

# Install noVNC dependencies
RUN pip3 install websockify

# Set VNC password
RUN mkdir -p ~/.vnc && \
    x11vnc -storepasswd ${VNC_PASSWORD} ~/.vnc/passwd

# Create HTML page with proper noVNC
RUN mkdir -p /var/www/html && \
    wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /tmp/ && \
    cp -r /tmp/noVNC-1.4.0/vnc_lite.html /var/www/html/ && \
    cp -r /tmp/noVNC-1.4.0/app/ /var/www/html/ && \
    cp -r /tmp/noVNC-1.4.0/core/ /var/www/html/ && \
    cp -r /tmp/noVNC-1.4.0/vendor/ /var/www/html/ && \
    rm -rf /tmp/noVNC-1.4.0 /tmp/novnc.tar.gz

# Fix the noVNC JavaScript to work with CDN paths
RUN sed -i 's|\.\./core/|./core/|g' /var/www/html/app/*.js && \
    sed -i 's|\.\./vendor/|./vendor/|g' /var/www/html/app/*.js

# Create custom HTML with working VNC client
RUN cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>VNC Desktop</title>
    <meta charset="UTF-8">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body, html { width: 100%; height: 100%; }
        #container { width: 100%; height: 100%; display: flex; flex-direction: column; }
        #header { background: #2c3e50; color: white; padding: 15px; }
        #vnc-container { flex: 1; background: black; position: relative; }
        #loading { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); 
                   color: white; text-align: center; background: rgba(0,0,0,0.8); padding: 30px; 
                   border-radius: 10px; }
        button { background: #3498db; color: white; border: none; padding: 10px 20px; 
                 margin: 5px; cursor: pointer; border-radius: 5px; font-size: 16px; }
        button:hover { background: #2980b9; }
        #status { color: white; margin-top: 20px; }
    </style>
    <!-- Load noVNC from CDN to avoid module errors -->
    <script src="https://cdn.jsdelivr.net/npm/@novnc/novnc@1.4.0/lib/rfb.min.js"></script>
</head>
<body>
    <div id="container">
        <div id="header">
            <h2>VNC Desktop Viewer</h2>
            <button onclick="connectVNC()" id="connect-btn">Connect to Desktop</button>
            <button onclick="location.reload()">Refresh Page</button>
        </div>
        <div id="vnc-container">
            <div id="loading">
                <h3>Click "Connect to Desktop" to start</h3>
                <p>Your Ubuntu desktop with Firefox will appear here</p>
                <div id="status">Ready</div>
            </div>
            <div id="screen" style="width: 100%; height: 100%;"></div>
        </div>
    </div>

    <script>
        let rfb;
        let connected = false;
        
        function connectVNC() {
            if (connected) return;
            
            const btn = document.getElementById('connect-btn');
            btn.disabled = true;
            btn.textContent = 'Connecting...';
            document.getElementById('status').textContent = 'Establishing connection...';
            
            const host = window.location.hostname;
            const protocol = window.location.protocol === 'https:' ? 'wss://' : 'ws://';
            const port = window.location.port ? ':' + window.location.port : '';
            
            // Try different WebSocket paths
            const wsPaths = [
                '/websockify',
                '/websockify/',
                'websockify'
            ];
            
            let currentTry = 0;
            
            function tryConnect() {
                if (currentTry >= wsPaths.length) {
                    document.getElementById('status').textContent = 'Failed to connect. Trying fallback...';
                    setTimeout(tryFallback, 1000);
                    return;
                }
                
                const wsUrl = protocol + host + port + wsPaths[currentTry];
                console.log('Trying WebSocket:', wsUrl);
                document.getElementById('status').textContent = 'Trying: ' + wsUrl;
                
                rfb = new RFB(document.getElementById('screen'), wsUrl, {
                    credentials: { password: 'password123' },
                    shared: true,
                    repeaterID: ''
                });
                
                rfb.scaleViewport = true;
                rfb.resizeSession = true;
                
                rfb.addEventListener("connect", function() {
                    connected = true;
                    document.getElementById('loading').style.display = 'none';
                    document.getElementById('status').textContent = 'Connected!';
                    btn.textContent = 'Connected';
                    console.log('VNC connected successfully');
                });
                
                rfb.addEventListener("disconnect", function(e) {
                    connected = false;
                    btn.disabled = false;
                    btn.textContent = 'Reconnect';
                    document.getElementById('loading').style.display = 'block';
                    document.getElementById('status').textContent = 'Disconnected: ' + (e.detail.clean ? 'Clean disconnect' : 'Connection lost');
                    
                    if (!e.detail.clean) {
                        setTimeout(connectVNC, 3000);
                    }
                });
                
                rfb.addEventListener("credentialsrequired", function() {
                    document.getElementById('status').textContent = 'Password required';
                });
                
                rfb.addEventListener("securityfailure", function(e) {
                    document.getElementById('status').textContent = 'Auth failed: ' + e.detail.status;
                    currentTry++;
                    setTimeout(tryConnect, 1000);
                });
                
                // If no connection in 10 seconds, try next path
                setTimeout(function() {
                    if (!connected && rfb) {
                        rfb.disconnect();
                        currentTry++;
                        tryConnect();
                    }
                }, 10000);
            }
            
            function tryFallback() {
                document.getElementById('status').textContent = 'Using fallback connection method...';
                // Create iframe with novnc.com
                document.getElementById('loading').innerHTML = `
                    <h3>Alternative Connection</h3>
                    <p>Click below to open in noVNC.com:</p>
                    <button onclick="window.open('https://novnc.com/noVNC/vnc.html?host=' + encodeURIComponent('${host}') + '&port=${port.replace(":", "") || 443}&password=password123', '_blank')">
                        Open in noVNC.com
                    </button>
                    <p>Or use VNC client to connect to:</p>
                    <p><strong>Host:</strong> ${host}</p>
                    <p><strong>Port:</strong> 5900</p>
                    <p><strong>Password:</strong> password123</p>
                `;
            }
            
            tryConnect();
        }
        
        // Auto-connect after page loads
        window.addEventListener('load', function() {
            setTimeout(connectVNC, 1000);
        });
    </script>
</body>
</html>
EOF

# Configure nginx to proxy WebSocket connections
RUN cat > /etc/nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    upstream websocket {
        server localhost:6080;
    }
    
    server {
        listen 80;
        server_name _;
        
        root /var/www/html;
        index index.html;
        
        location / {
            try_files $uri $uri/ =404;
        }
        
        # WebSocket proxy for VNC
        location /websockify {
            proxy_pass http://websocket;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 86400;
        }
        
        # Static files
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|html)$ {
            expires 1d;
            add_header Cache-Control "public, immutable";
        }
    }
}
EOF

EXPOSE 80

# Startup script
CMD echo "=== Starting VNC Desktop ===" && \
    # Start X virtual framebuffer
    Xvfb :1 -screen 0 1024x768x16 & \
    sleep 3 && \
    # Start window manager
    fluxbox & \
    sleep 2 && \
    # Start Firefox
    firefox about:blank & \
    sleep 2 && \
    # Start VNC server
    x11vnc -display :1 -forever -shared -rfbauth ~/.vnc/passwd & \
    sleep 2 && \
    # Start websockify proxy
    echo "Starting WebSocket proxy on port 6080..." && \
    websockify 6080 localhost:5900 & \
    sleep 2 && \
    # Start nginx
    echo "Starting nginx on port 80..." && \
    nginx -g 'daemon off;'
