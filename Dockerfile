FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV VNC_PASSWORD=password123
ENV DISPLAY=:1

# Install packages including novnc
RUN apt update && apt install -y \
    wget \
    x11vnc \
    xvfb \
    fluxbox \
    firefox \
    python3 \
    python3-pip \
    python3-numpy \
    nginx \
    novnc \
    --no-install-recommends && \
    apt clean

# Install websockify
RUN pip3 install websockify

# Set VNC password
RUN mkdir -p ~/.vnc && \
    x11vnc -storepasswd ${VNC_PASSWORD} ~/.vnc/passwd

# Create simple HTML page
RUN mkdir -p /var/www/html && \
    cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>VNC Desktop</title>
    <meta charset="UTF-8">
    <script src="https://cdn.jsdelivr.net/npm/@novnc/novnc@1.4.0/lib/rfb.min.js"></script>
    <style>
        body, html { margin: 0; padding: 0; width: 100%; height: 100%; }
        #screen { width: 100%; height: 100%; background: black; }
        #status { position: fixed; bottom: 10px; left: 10px; background: rgba(0,0,0,0.7); color: white; padding: 10px; }
        #connect-btn { position: fixed; top: 10px; left: 10px; padding: 10px 20px; background: #4CAF50; color: white; border: none; cursor: pointer; }
    </style>
</head>
<body>
    <button id="connect-btn" onclick="connectVNC()">Connect VNC</button>
    <div id="screen"></div>
    <div id="status">Ready</div>
    
    <script>
        function connectVNC() {
            const btn = document.getElementById('connect-btn');
            btn.disabled = true;
            btn.textContent = 'Connecting...';
            document.getElementById('status').textContent = 'Connecting...';
            
            const host = window.location.hostname;
            const protocol = window.location.protocol === 'https:' ? 'wss://' : 'ws://';
            
            const rfb = new RFB(document.getElementById('screen'), 
                protocol + host + '/websockify', {
                credentials: { password: 'password123' }
            });
            
            rfb.addEventListener('connect', () => {
                document.getElementById('status').textContent = 'Connected!';
                btn.textContent = 'Connected';
            });
            
            rfb.addEventListener('disconnect', () => {
                document.getElementById('status').textContent = 'Disconnected';
                btn.disabled = false;
                btn.textContent = 'Reconnect';
            });
        }
        
        // Auto-connect
        setTimeout(connectVNC, 1000);
    </script>
</body>
</html>
EOF

# Ensure novnc directory exists
RUN mkdir -p /usr/share/novnc && \
    ln -sf /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html

# Clean up any existing X locks
RUN rm -f /tmp/.X*-lock /tmp/.X11-unix/*

# Nginx configuration
RUN cat > /etc/nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    server {
        listen 80;
        server_name _;
        
        root /var/www/html;
        index index.html;
        
        location / {
            try_files $uri $uri/ =404;
        }
        
        location /websockify {
            proxy_pass http://localhost:6080;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_read_timeout 86400;
        }
    }
}
EOF

EXPOSE 80

# Startup script with cleanup
CMD echo "=== Starting VNC Desktop ===" && \
    # Clean up any existing locks
    rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 && \
    # Start Xvfb
    Xvfb :1 -screen 0 1024x768x16 & \
    sleep 3 && \
    # Start fluxbox
    fluxbox & \
    sleep 2 && \
    # Start Firefox
    firefox about:blank & \
    sleep 2 && \
    # Start x11vnc
    x11vnc -display :1 -forever -shared -rfbauth ~/.vnc/passwd -localhost & \
    sleep 2 && \
    # Start websockify with correct path
    websockify --web /var/www/html 6080 localhost:5900 & \
    sleep 2 && \
    # Start nginx
    echo "=== Ready ===" && \
    echo "Access: https://$(hostname)" && \
    echo "Password: ${VNC_PASSWORD}" && \
    nginx -g 'daemon off;'
