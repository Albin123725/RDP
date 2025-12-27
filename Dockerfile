FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV VNC_PASSWORD=password123
ENV DISPLAY=:1

# Install packages
RUN apt update && apt install -y \
    wget \
    x11vnc \
    xvfb \
    fluxbox \
    firefox \
    python3 \
    python3-pip \
    nginx \
    --no-install-recommends && \
    apt clean

# Install websockify
RUN pip3 install websockify

# Set VNC password
RUN mkdir -p ~/.vnc && \
    x11vnc -storepasswd ${VNC_PASSWORD} ~/.vnc/passwd

# Create HTML page that WORKS on Render
RUN mkdir -p /var/www/html && \
    cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>VNC Desktop</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <script src="https://cdn.jsdelivr.net/npm/@novnc/novnc@1.4.0/lib/rfb.min.js"></script>
    <style>
        body, html { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; font-family: Arial, sans-serif; }
        #container { width: 100%; height: 100%; display: flex; flex-direction: column; }
        #header { background: #2c3e50; color: white; padding: 15px; display: flex; justify-content: space-between; align-items: center; }
        #vnc-area { flex: 1; background: black; position: relative; }
        #loading { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); 
                   color: white; text-align: center; background: rgba(0,0,0,0.8); padding: 30px; 
                   border-radius: 10px; }
        button { background: #3498db; color: white; border: none; padding: 10px 20px; 
                 margin: 0 5px; cursor: pointer; border-radius: 5px; font-size: 14px; }
        button:hover { background: #2980b9; }
        button:disabled { background: #7f8c8d; cursor: not-allowed; }
        #status { margin-top: 15px; }
        #debug { background: rgba(0,0,0,0.7); color: #0f0; padding: 10px; margin-top: 10px; 
                font-family: monospace; font-size: 12px; max-height: 100px; overflow-y: auto; }
    </style>
</head>
<body>
    <div id="container">
        <div id="header">
            <h2>VNC Desktop</h2>
            <div>
                <button id="connect-btn" onclick="connectVNC()">Connect</button>
                <button onclick="location.reload()">Refresh</button>
                <button onclick="toggleDebug()">Debug</button>
            </div>
        </div>
        <div id="vnc-area">
            <div id="loading">
                <h3>Ready to Connect</h3>
                <p>Click "Connect" button to start VNC session</p>
                <div id="status">Status: Waiting...</div>
                <div id="debug" style="display: none;"></div>
            </div>
            <div id="screen" style="width: 100%; height: 100%;"></div>
        </div>
    </div>

    <script>
        let rfb = null;
        let debugLog = [];
        
        function log(msg) {
            debugLog.push(new Date().toISOString().split('T')[1].split('.')[0] + ' - ' + msg);
            if (debugLog.length > 10) debugLog.shift();
            document.getElementById('debug').innerHTML = debugLog.join('<br>');
            console.log(msg);
        }
        
        function toggleDebug() {
            const debug = document.getElementById('debug');
            debug.style.display = debug.style.display === 'none' ? 'block' : 'none';
        }
        
        function updateStatus(msg) {
            document.getElementById('status').innerHTML = 'Status: ' + msg;
            log(msg);
        }
        
        function connectVNC() {
            if (rfb) {
                rfb.disconnect();
                rfb = null;
            }
            
            const btn = document.getElementById('connect-btn');
            btn.disabled = true;
            btn.textContent = 'Connecting...';
            updateStatus('Starting connection...');
            
            const host = window.location.hostname;
            const isHttps = window.location.protocol === 'https:';
            
            // Render requires specific WebSocket URL format
            // Try multiple possible WebSocket endpoints
            const wsUrls = [
                // Primary: Use current protocol
                (isHttps ? 'wss://' : 'ws://') + host + '/websockify',
                // Secondary: Try with port
                (isHttps ? 'wss://' : 'ws://') + host + (window.location.port ? ':' + window.location.port : '') + '/websockify',
                // Tertiary: Try different path
                (isHttps ? 'wss://' : 'ws://') + host + '/'
            ];
            
            let currentUrlIndex = 0;
            
            function tryNextUrl() {
                if (currentUrlIndex >= wsUrls.length) {
                    updateStatus('All connection attempts failed. Showing instructions...');
                    showFallbackInstructions();
                    return;
                }
                
                const wsUrl = wsUrls[currentUrlIndex];
                updateStatus('Trying: ' + wsUrl);
                
                // Disconnect existing connection
                if (rfb) {
                    rfb.disconnect();
                }
                
                // Create new RFB connection
                rfb = new RFB(document.getElementById('screen'), wsUrl, {
                    credentials: { password: 'password123' },
                    shared: true,
                    repeaterID: '',
                    wsProtocols: ['binary', 'base64']
                });
                
                rfb.scaleViewport = true;
                rfb.resizeSession = true;
                rfb.viewOnly = false;
                
                rfb.addEventListener("connect", function() {
                    updateStatus('Connected successfully!');
                    btn.textContent = 'Disconnect';
                    btn.disabled = false;
                    btn.onclick = disconnectVNC;
                    document.getElementById('loading').style.display = 'none';
                    log('VNC connected to: ' + wsUrl);
                });
                
                rfb.addEventListener("disconnect", function(e) {
                    updateStatus('Disconnected: ' + (e.detail.clean ? 'Normal disconnect' : 'Connection lost'));
                    btn.textContent = 'Reconnect';
                    btn.disabled = false;
                    btn.onclick = connectVNC;
                    document.getElementById('loading').style.display = 'block';
                    
                    if (!e.detail.clean) {
                        // Try to reconnect after 3 seconds
                        setTimeout(connectVNC, 3000);
                    }
                });
                
                rfb.addEventListener("credentialsrequired", function() {
                    updateStatus('Password required...');
                });
                
                rfb.addEventListener("securityfailure", function(e) {
                    updateStatus('Security failure, trying next URL...');
                    currentUrlIndex++;
                    setTimeout(tryNextUrl, 1000);
                });
                
                // If not connected in 5 seconds, try next URL
                setTimeout(function() {
                    if (rfb && !rfb._connected) {
                        updateStatus('Connection timeout, trying next URL...');
                        currentUrlIndex++;
                        tryNextUrl();
                    }
                }, 5000);
            }
            
            function disconnectVNC() {
                if (rfb) {
                    rfb.disconnect();
                    rfb = null;
                }
                btn.textContent = 'Connect';
                btn.onclick = connectVNC;
                document.getElementById('loading').style.display = 'block';
                updateStatus('Disconnected by user');
            }
            
            function showFallbackInstructions() {
                document.getElementById('loading').innerHTML = `
                    <h3>Alternative Connection Methods</h3>
                    <div style="text-align: left; margin: 20px 0;">
                        <p><strong>Option 1: Use external noVNC</strong></p>
                        <p>Visit: <a href="https://novnc.com/noVNC/vnc.html" target="_blank">novnc.com/noVNC/vnc.html</a></p>
                        <p>Enter: <code>${host}</code> as host (no port needed)</p>
                        <p>Password: <code>password123</code></p>
                        
                        <p style="margin-top: 20px;"><strong>Option 2: Use VNC client</strong></p>
                        <p>Download: <a href="https://www.realvnc.com/en/connect/download/viewer/" target="_blank">RealVNC Viewer</a></p>
                        <p>Connect to: <code>${host}:5900</code></p>
                        <p>Password: <code>password123</code></p>
                    </div>
                    <button onclick="connectVNC()">Try Again</button>
                `;
                btn.textContent = 'Try Again';
                btn.disabled = false;
                btn.onclick = connectVNC;
            }
            
            tryNextUrl();
        }
        
        // Auto-connect after 1 second
        setTimeout(connectVNC, 1000);
    </script>
</body>
</html>
EOF

# Configure nginx - CRITICAL FOR RENDER
RUN cat > /etc/nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # WebSocket upstream
    upstream websocket {
        server 127.0.0.1:6080;
    }
    
    server {
        listen 80;
        server_name _;
        
        root /var/www/html;
        index index.html;
        
        # Serve static files
        location / {
            try_files $uri $uri/ =404;
        }
        
        # CRITICAL: WebSocket proxy for VNC
        location /websockify {
            proxy_pass http://websocket;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Important timeouts for Render
            proxy_connect_timeout 7d;
            proxy_send_timeout 7d;
            proxy_read_timeout 7d;
        }
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1d;
            add_header Cache-Control "public, immutable";
        }
    }
}
EOF

EXPOSE 80

# Startup script - IMPORTANT: Start services in correct order
CMD echo "=== Starting VNC Desktop on Render ===" && \
    echo "Starting X virtual framebuffer..." && \
    Xvfb :1 -screen 0 1024x768x16 -ac & \
    sleep 3 && \
    echo "Starting window manager..." && \
    fluxbox & \
    sleep 2 && \
    echo "Starting Firefox..." && \
    firefox --no-remote --new-instance about:blank & \
    sleep 2 && \
    echo "Starting VNC server..." && \
    x11vnc -display :1 -forever -shared -rfbauth ~/.vnc/passwd -noxdamage -noxfixes -bg && \
    sleep 2 && \
    echo "Starting WebSocket proxy..." && \
    websockify --web /var/www/html 6080 localhost:5900 & \
    sleep 2 && \
    echo "Starting nginx..." && \
    echo "=== VNC Desktop Ready ===" && \
    echo "Access URL: https://$(hostname)" && \
    echo "VNC Password: ${VNC_PASSWORD}" && \
    nginx -g 'daemon off;'
