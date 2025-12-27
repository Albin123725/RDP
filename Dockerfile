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
    wget \
    --no-install-recommends && \
    apt clean

# Install websockify from pip
RUN pip3 install websockify

# Set VNC password
RUN mkdir -p ~/.vnc && \
    x11vnc -storepasswd ${VNC_PASSWORD} ~/.vnc/passwd

# Create HTML page with built-in VNC using CDN noVNC
RUN mkdir -p /var/www/html && \
    cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>VNC Desktop</title>
    <meta charset="UTF-8">
    <style>
        body { margin: 0; padding: 0; font-family: Arial, sans-serif; }
        #noVNC_screen { width: 100vw; height: 100vh; }
        #noVNC_status_bar { position: fixed; bottom: 0; left: 0; right: 0; background: rgba(0,0,0,0.8); color: white; padding: 10px; }
        #noVNC_status { display: inline-block; margin-right: 20px; }
        #noVNC_buttons { float: right; }
        button { background: #4CAF50; color: white; border: none; padding: 8px 16px; margin-left: 10px; cursor: pointer; }
        button:hover { background: #45a049; }
        .loading { position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); text-align: center; }
    </style>
</head>
<body>
    <div class="loading" id="loading">
        <h2>Loading VNC Desktop...</h2>
        <p>Please wait while the desktop starts.</p>
    </div>
    
    <div id="noVNC_screen"></div>
    
    <div id="noVNC_status_bar" style="display: none;">
        <span id="noVNC_status">Initializing...</span>
        <div id="noVNC_buttons">
            <button onclick="sendCtrlAltDel()">Ctrl+Alt+Del</button>
            <button onclick="toggleFullscreen()">Fullscreen</button>
            <button onclick="reconnect()">Reconnect</button>
        </div>
    </div>

    <!-- Load noVNC from CDN -->
    <script src="https://cdn.jsdelivr.net/npm/@novnc/novnc@1.4.0/lib/rfb.min.js"></script>
    
    <script>
        let rfb;
        let reconnectTimer;
        
        function connectVNC() {
            document.getElementById('loading').style.display = 'none';
            document.getElementById('noVNC_status_bar').style.display = 'block';
            
            const host = window.location.hostname;
            const path = window.location.pathname;
            
            // Use relative WebSocket URL (Render proxies WebSockets)
            const wsUrl = (window.location.protocol === 'https:' ? 'wss://' : 'ws://') + 
                         host + 
                         (window.location.port ? ':' + window.location.port : '') + 
                         '/websockify';
            
            console.log('Connecting to:', wsUrl);
            
            rfb = new RFB(document.getElementById('noVNC_screen'), wsUrl, {
                credentials: { password: 'password123' },
                shared: true,
                repeaterID: '',
                wsProtocols: ['binary', 'base64']
            });
            
            rfb.viewOnly = false;
            rfb.scaleViewport = true;
            
            rfb.addEventListener("connect", function() {
                updateStatus('Connected');
                console.log('Connected to VNC server');
            });
            
            rfb.addEventListener("disconnect", function(e) {
                if (e.detail.clean) {
                    updateStatus('Disconnected');
                } else {
                    updateStatus('Connection failed - reconnecting...');
                    setTimeout(connectVNC, 3000);
                }
            });
            
            rfb.addEventListener("credentialsrequired", function() {
                updateStatus('Password required');
            });
            
            rfb.addEventListener("desktopname", function(e) {
                updateStatus('Desktop: ' + e.detail.name);
            });
            
            rfb.addEventListener("securityfailure", function(e) {
                updateStatus('Auth failed: ' + e.detail.status);
            });
            
            rfb.addEventListener("clipboard", function(e) {
                updateStatus('Clipboard: ' + e.detail.text.substring(0, 20) + '...');
            });
        }
        
        function updateStatus(status) {
            document.getElementById('noVNC_status').textContent = status;
        }
        
        function sendCtrlAltDel() {
            rfb.sendCtrlAltDel();
        }
        
        function toggleFullscreen() {
            if (!document.fullscreenElement) {
                document.documentElement.requestFullscreen();
            } else {
                if (document.exitFullscreen) {
                    document.exitFullscreen();
                }
            }
        }
        
        function reconnect() {
            if (rfb) {
                rfb.disconnect();
            }
            connectVNC();
        }
        
        // Auto-connect after 3 seconds
        setTimeout(connectVNC, 3000);
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
        
        # WebSocket proxy
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
    # Start VNC server
    x11vnc -display :1 -forever -shared -rfbauth ~/.vnc/passwd -bg && \
    sleep 2 && \
    # Start Firefox
    firefox about:blank & \
    sleep 2 && \
    # Start WebSocket proxy
    websockify --web /var/www/html 6080 localhost:5900 & \
    # Start nginx
    nginx -g 'daemon off;'
