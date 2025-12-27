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

# Install websockets library
RUN pip3 install websockets

# Set VNC password
RUN mkdir -p ~/.vnc && \
    x11vnc -storepasswd ${VNC_PASSWORD} ~/.vnc/passwd

# Create a proper WebSocket to TCP proxy in Python
RUN cat > /ws_proxy.py << 'EOF'
#!/usr/bin/env python3
import asyncio
import websockets
import socket
import ssl
import sys

VNC_HOST = 'localhost'
VNC_PORT = 5900
WS_PORT = 6080

async def handle_websocket(websocket, path):
    print(f"New WebSocket connection from {websocket.remote_address}")
    
    try:
        # Connect to VNC server
        reader, writer = await asyncio.open_connection(VNC_HOST, VNC_PORT)
        
        # Forward WebSocket to VNC
        async def ws_to_vnc():
            try:
                async for message in websocket:
                    writer.write(message)
                    await writer.drain()
            except:
                pass
            finally:
                writer.close()
        
        # Forward VNC to WebSocket
        async def vnc_to_ws():
            try:
                while True:
                    data = await reader.read(4096)
                    if not data:
                        break
                    await websocket.send(data)
            except:
                pass
        
        # Run both forwarding tasks
        await asyncio.gather(ws_to_vnc(), vnc_to_ws())
        
    except Exception as e:
        print(f"Error handling connection: {e}")
    finally:
        print(f"Connection closed for {websocket.remote_address}")

async def main():
    print(f"Starting WebSocket proxy on port {WS_PORT}")
    print(f"Proxying to VNC at {VNC_HOST}:{VNC_PORT}")
    
    # Start WebSocket server
    async with websockets.serve(
        handle_websocket,
        "0.0.0.0",
        WS_PORT,
        ping_interval=None,
        max_size=2**24  # 16MB buffer
    ):
        print(f"WebSocket server ready on port {WS_PORT}")
        await asyncio.Future()  # Run forever

if __name__ == "__main__":
    asyncio.run(main())
EOF

# Create HTML page
RUN mkdir -p /var/www/html && \
    cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>VNC Desktop</title>
    <meta charset="UTF-8">
    <style>
        body, html { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; }
        #container { width: 100%; height: 100%; display: flex; flex-direction: column; }
        #header { background: #2c3e50; color: white; padding: 10px; }
        #vnc-area { flex: 1; background: black; position: relative; }
        #screen { width: 100%; height: 100%; }
        #status { position: fixed; bottom: 10px; left: 10px; background: rgba(0,0,0,0.7); color: white; padding: 10px; }
        #connect-btn { padding: 10px 20px; background: #4CAF50; color: white; border: none; cursor: pointer; margin-right: 10px; }
    </style>
    <script src="https://cdn.jsdelivr.net/npm/@novnc/novnc@1.4.0/lib/rfb.min.js"></script>
</head>
<body>
    <div id="container">
        <div id="header">
            <button id="connect-btn" onclick="connectVNC()">Connect VNC</button>
            <span>VNC Desktop</span>
        </div>
        <div id="vnc-area">
            <div id="screen"></div>
        </div>
        <div id="status">Ready</div>
    </div>

    <script>
        let rfb = null;
        
        function updateStatus(msg) {
            document.getElementById('status').textContent = msg;
            console.log(msg);
        }
        
        function connectVNC() {
            const btn = document.getElementById('connect-btn');
            btn.disabled = true;
            btn.textContent = 'Connecting...';
            updateStatus('Starting connection...');
            
            const host = window.location.hostname;
            const protocol = window.location.protocol === 'https:' ? 'wss://' : 'ws://';
            const port = window.location.port ? ':' + window.location.port : '';
            
            // IMPORTANT: Use port 6080 for WebSocket (our Python proxy)
            const wsUrl = protocol + host + ':6080';
            
            console.log('Connecting to WebSocket:', wsUrl);
            updateStatus('Connecting to: ' + wsUrl);
            
            rfb = new RFB(document.getElementById('screen'), wsUrl, {
                credentials: { password: 'password123' },
                shared: true,
                repeaterID: ''
            });
            
            rfb.scaleViewport = true;
            
            rfb.addEventListener("connect", function() {
                updateStatus('Connected!');
                btn.textContent = 'Disconnect';
                btn.disabled = false;
                btn.onclick = disconnectVNC;
            });
            
            rfb.addEventListener("disconnect", function(e) {
                updateStatus('Disconnected');
                btn.textContent = 'Reconnect';
                btn.disabled = false;
                btn.onclick = connectVNC;
                
                if (!e.detail.clean) {
                    setTimeout(connectVNC, 3000);
                }
            });
            
            rfb.addEventListener("credentialsrequired", function() {
                updateStatus('Password required...');
            });
            
            rfb.addEventListener("securityfailure", function(e) {
                updateStatus('Security failure: ' + e.detail.status);
            });
            
            // Test WebSocket connection first
            testWebSocket(wsUrl);
        }
        
        function disconnectVNC() {
            if (rfb) {
                rfb.disconnect();
                rfb = null;
            }
            const btn = document.getElementById('connect-btn');
            btn.textContent = 'Connect VNC';
            btn.onclick = connectVNC;
            updateStatus('Disconnected by user');
        }
        
        function testWebSocket(url) {
            const ws = new WebSocket(url);
            ws.onopen = function() {
                console.log('WebSocket test: OPEN');
                updateStatus('WebSocket connected, starting VNC...');
                ws.close();
            };
            ws.onerror = function(e) {
                console.error('WebSocket test: ERROR', e);
                updateStatus('WebSocket error, trying alternative...');
                // Try alternative URL
                const altUrl = url.replace(':6080', '/websockify');
                setTimeout(() => testWebSocket(altUrl), 1000);
            };
        }
        
        // Auto-connect
        setTimeout(connectVNC, 1000);
    </script>
</body>
</html>
EOF

# Nginx config - SIMPLER
RUN cat > /etc/nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    server {
        listen 80;
        root /var/www/html;
        index index.html;
        
        location / {
            try_files $uri $uri/ =404;
        }
    }
}
EOF

EXPOSE 80

# Startup script - CRITICAL: Start x11vnc WITHOUT WebSocket support
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
    # Start x11vnc with NO WebSocket support
    echo "4. Starting VNC server (TCP only)..." && \
    x11vnc -display :1 -forever -shared -rfbauth ~/.vnc/passwd -localhost -nosel -noxdamage -nowf -noscr & \
    sleep 2 && \
    # Start Python WebSocket proxy
    echo "5. Starting Python WebSocket proxy on port 6080..." && \
    python3 /ws_proxy.py & \
    sleep 2 && \
    # Start nginx
    echo "6. Starting nginx..." && \
    echo "=== Ready ===" && \
    echo "Web interface: https://$(hostname)" && \
    echo "VNC Password: ${VNC_PASSWORD}" && \
    echo "WebSocket URL: wss://$(hostname):6080" && \
    nginx -g 'daemon off;'
