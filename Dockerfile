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

# Install simple-websocket-server
RUN pip3 install simple-websocket-server

# Set VNC password
RUN mkdir -p ~/.vnc && \
    x11vnc -storepasswd ${VNC_PASSWORD} ~/.vnc/passwd

# Create a Python WebSocket to VNC proxy
RUN cat > /websocket_proxy.py << 'EOF'
#!/usr/bin/env python3
import asyncio
import websockets
import socket
import threading

VNC_HOST = 'localhost'
VNC_PORT = 5900
WS_PORT = 6080

async def handle_websocket(websocket, path):
    print(f"WebSocket connection from {websocket.remote_address}")
    try:
        # Connect to VNC server
        vnc_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        vnc_socket.connect((VNC_HOST, VNC_PORT))
        vnc_socket.setblocking(False)
        
        async def forward_to_vnc():
            try:
                while True:
                    data = await websocket.recv()
                    vnc_socket.send(data)
            except:
                pass
        
        async def forward_from_vnc():
            try:
                while True:
                    try:
                        data = vnc_socket.recv(4096)
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
        vnc_socket.close()

async def main():
    print(f"Starting WebSocket proxy on port {WS_PORT}")
    async with websockets.serve(handle_websocket, "0.0.0.0", WS_PORT):
        await asyncio.Future()  # run forever

if __name__ == "__main__":
    asyncio.run(main())
EOF

# Create HTML page with built-in VNC viewer using HTML5 Canvas
RUN mkdir -p /var/www/html && \
    cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>HTML5 VNC Viewer</title>
    <script src="https://cdn.jsdelivr.net/npm/@novnc/novnc@1.2.0/lib/rfb.min.js"></script>
    <style>
        body { margin: 0; padding: 20px; font-family: Arial; background: #f0f0f0; }
        #container { max-width: 1000px; margin: 0 auto; }
        #header { background: white; padding: 20px; border-radius: 10px 10px 0 0; }
        #vnc-container { background: black; }
        #status { padding: 10px; background: #333; color: white; }
        #connect-btn { padding: 10px 20px; background: #4CAF50; color: white; border: none; cursor: pointer; }
        #connect-btn:disabled { background: #ccc; }
    </style>
</head>
<body>
    <div id="container">
        <div id="header">
            <h1>VNC Desktop</h1>
            <p>Click connect to start VNC session</p>
            <button id="connect-btn" onclick="connectVNC()">Connect to VNC</button>
            <div id="status">Disconnected</div>
        </div>
        <div id="vnc-container"></div>
    </div>
    
    <script>
        let rfb;
        const host = window.location.hostname;
        const port = 6080;
        
        function connectVNC() {
            const btn = document.getElementById('connect-btn');
            btn.disabled = true;
            document.getElementById('status').textContent = 'Connecting...';
            
            // Create RFB connection
            rfb = new RFB(document.getElementById('vnc-container'), `ws://${host}:${port}/`, {
                credentials: { password: 'password123' }
            });
            
            rfb.addEventListener("connect", () => {
                document.getElementById('status').textContent = 'Connected';
            });
            
            rfb.addEventListener("disconnect", () => {
                document.getElementById('status').textContent = 'Disconnected';
                btn.disabled = false;
            });
            
            rfb.addEventListener("credentialsrequired", () => {
                document.getElementById('status').textContent = 'Authentication required';
            });
            
            rfb.addEventListener("securityfailure", (e) => {
                document.getElementById('status').textContent = 'Security failure: ' + e.detail.status;
                btn.disabled = false;
            });
        }
        
        // Auto-connect after 2 seconds
        setTimeout(connectVNC, 2000);
    </script>
</body>
</html>
EOF

# Configure nginx
RUN echo 'server { listen 80; root /var/www/html; index index.html; }' > /etc/nginx/sites-available/default

EXPOSE 80 6080

# Startup
CMD echo "=== Starting VNC Desktop ===" && \
    # Start Xvfb
    Xvfb :1 -screen 0 1024x768x16 & \
    sleep 3 && \
    # Start fluxbox
    fluxbox & \
    sleep 2 && \
    # Start x11vnc
    x11vnc -display :1 -forever -shared -rfbauth ~/.vnc/passwd & \
    sleep 2 && \
    # Start Firefox
    firefox about:blank & \
    sleep 2 && \
    # Start nginx
    nginx & \
    # Start WebSocket proxy
    python3 /websocket_proxy.py & \
    echo "=== Ready ===" && \
    echo "Web interface: http://$(hostname)" && \
    tail -f /dev/null
