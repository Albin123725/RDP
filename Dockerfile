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

# Install a DIFFERENT websocket library that works
RUN pip3 install simple-websocket-server

# Set VNC password
RUN mkdir -p ~/.vnc && \
    x11vnc -storepasswd ${VNC_PASSWORD} ~/.vnc/passwd

# Download and extract noVNC 1.2.0 (more stable)
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.2.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt/ && \
    mv /opt/noVNC-1.2.0 /opt/novnc && \
    rm /tmp/novnc.tar.gz

# Create a Python WebSocket proxy that actually works
RUN cat > /websocket_proxy.py << 'EOF'
#!/usr/bin/env python3
import asyncio
import websockets
import socket
import sys
import signal

VNC_HOST = 'localhost'
VNC_PORT = 5900
WS_PORT = 6080

async def handle_client(websocket, path):
    print(f"New WebSocket connection from {websocket.remote_address}")
    
    try:
        # Connect to VNC server
        vnc_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        vnc_sock.connect((VNC_HOST, VNC_PORT))
        vnc_sock.setblocking(False)
        
        async def forward_to_vnc():
            try:
                while True:
                    data = await websocket.recv()
                    vnc_sock.send(data)
            except:
                pass
        
        async def forward_from_vnc():
            try:
                while True:
                    try:
                        data = vnc_sock.recv(4096)
                        if data:
                            await websocket.send(data)
                        else:
                            break
                    except BlockingIOError:
                        await asyncio.sleep(0.01)
            except:
                pass
        
        await asyncio.gather(forward_to_vnc(), forward_from_vnc())
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        vnc_sock.close()
        print(f"Connection closed for {websocket.remote_address}")

async def main():
    print(f"Starting WebSocket proxy on port {WS_PORT}")
    async with websockets.serve(handle_client, "0.0.0.0", WS_PORT):
        await asyncio.Future()  # run forever

if __name__ == "__main__":
    asyncio.run(main())
EOF

# Create HTML with CDN noVNC (bypasses module errors)
RUN mkdir -p /var/www/html && \
    cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>VNC Desktop</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body, html { width: 100%; height: 100%; overflow: hidden; }
        #container { width: 100%; height: 100%; display: flex; flex-direction: column; }
        #header { background: #2c3e50; color: white; padding: 15px; }
        #vnc-area { flex: 1; background: black; position: relative; }
        #loading { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); 
                   color: white; text-align: center; background: rgba(0,0,0,0.8); padding: 30px; 
                   border-radius: 10px; z-index: 1000; }
        #screen { width: 100%; height: 100%; }
        button { background: #3498db; color: white; border: none; padding: 10px 20px; 
                 margin: 5px; cursor: pointer; border-radius: 5px; font-size: 16px; }
        button:hover { background: #2980b9; }
        #status { margin-top: 15px; color: white; }
    </style>
    <!-- Load noVNC from UNPKG (more reliable) -->
    <script src="https://unpkg.com/@novnc/novnc@1.4.0/lib/rfb.js"></script>
</head>
<body>
    <div id="container">
        <div id="header">
            <h2>VNC Desktop</h2>
            <button onclick="connectVNC()" id="connect-btn">Connect to Desktop</button>
            <button onclick="location.reload()">Refresh</button>
        </div>
        <div id="vnc-area">
            <div id="loading">
                <h3>Ready to Connect</h3>
                <p>Click "Connect to Desktop" to start VNC session</p>
                <div id="status">Status: Waiting...</div>
            </div>
            <div id="screen"></div>
        </div>
    </div>

    <script>
        let rfb = null;
        let isConnected = false;
        
        function updateStatus(msg) {
            document.getElementById('status').textContent = 'Status: ' + msg;
            console.log(msg);
        }
        
        function connectVNC() {
            if (isConnected) {
                if (rfb) {
                    rfb.disconnect();
                }
                return;
            }
            
            const btn = document.getElementById('connect-btn');
            btn.disabled = true;
            btn.textContent = 'Connecting...';
            updateStatus('Starting connection...');
            
            const host = window.location.hostname;
            const isHttps = window.location.protocol === 'https:';
            const port = window.location.port || (isHttps ? '443' : '80');
            
            // IMPORTANT: Use wss:// for HTTPS, ws:// for HTTP
            const wsProtocol = isHttps ? 'wss://' : 'ws://';
            
            // Try different WebSocket endpoints
            const wsUrls = [
                wsProtocol + host + ':' + port + '/websockify',
                wsProtocol + host + '/websockify',
                'ws://' + host + ':6080/websockify',
                'wss://' + host + ':6080/websockify'
            ];
            
            let currentUrlIndex = 0;
            
            function tryConnect(url) {
                console.log('Trying WebSocket URL:', url);
                updateStatus('Trying: ' + url);
                
                if (rfb) {
                    rfb.disconnect();
                    rfb = null;
                }
                
                rfb = new RFB(document.getElementById('screen'), url, {
                    credentials: { password: 'password123' },
                    shared: true,
                    repeaterID: ''
                });
                
                rfb.scaleViewport = true;
                rfb.resizeSession = true;
                
                rfb.addEventListener("connect", function() {
                    isConnected = true;
                    updateStatus('Connected successfully!');
                    btn.textContent = 'Disconnect';
                    btn.disabled = false;
                    document.getElementById('loading').style.display = 'none';
                    console.log('VNC connected to:', url);
                });
                
                rfb.addEventListener("disconnect", function(e) {
                    isConnected = false;
                    updateStatus('Disconnected: ' + (e.detail.clean ? 'Normal' : 'Lost'));
                    btn.textContent = 'Reconnect';
                    btn.disabled = false;
                    document.getElementById('loading').style.display = 'block';
                    
                    if (!e.detail.clean) {
                        // Try to reconnect
                        setTimeout(connectVNC, 3000);
                    }
                });
                
                rfb.addEventListener("securityfailure", function(e) {
                    updateStatus('Security failed, trying next URL...');
                    currentUrlIndex++;
                    if (currentUrlIndex < wsUrls.length) {
                        setTimeout(() => tryConnect(wsUrls[currentUrlIndex]), 1000);
                    } else {
                        updateStatus('All connection attempts failed');
                        btn.textContent = 'Try Again';
                        btn.disabled = false;
                    }
                });
                
                // Timeout after 5 seconds
                setTimeout(function() {
                    if (!isConnected && rfb) {
                        updateStatus('Connection timeout, trying next...');
                        currentUrlIndex++;
                        if (currentUrlIndex < wsUrls.length) {
                            setTimeout(() => tryConnect(wsUrls[currentUrlIndex]), 1000);
                        }
                    }
                }, 5000);
            }
            
            // Start with first URL
            tryConnect(wsUrls[0]);
            
            // Override disconnect button
            btn.onclick = function() {
                if (isConnected) {
                    rfb.disconnect();
                    btn.textContent = 'Connect to Desktop';
                    isConnected = false;
                } else {
                    connectVNC();
                }
            };
        }
        
        // Auto-connect after 1 second
        setTimeout(connectVNC, 1000);
    </script>
</body>
</html>
EOF

# Configure nginx to proxy to our Python WebSocket server
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
        
        # Proxy WebSocket to Python server
        location /websockify {
            proxy_pass http://localhost:6080;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
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
    echo "1. Starting X virtual framebuffer..." && \
    Xvfb :1 -screen 0 1024x768x16 -ac & \
    sleep 3 && \
    # Start fluxbox
    echo "2. Starting window manager..." && \
    fluxbox & \
    sleep 2 && \
    # Start Firefox
    echo "3. Starting Firefox..." && \
    firefox --no-remote about:blank & \
    sleep 2 && \
    # Start x11vnc
    echo "4. Starting VNC server..." && \
    x11vnc -display :1 -forever -shared -rfbauth ~/.vnc/passwd -localhost -noxdamage & \
    sleep 2 && \
    # Start Python WebSocket proxy
    echo "5. Starting WebSocket proxy..." && \
    python3 /websocket_proxy.py & \
    sleep 2 && \
    # Start nginx
    echo "6. Starting nginx..." && \
    echo "=== Ready ===" && \
    echo "Access: https://$(hostname)" && \
    echo "Password: ${VNC_PASSWORD}" && \
    nginx -g 'daemon off;'
