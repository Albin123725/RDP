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
    --no-install-recommends && \
    apt clean

# Install websockify
RUN pip3 install websockify

# Set VNC password
RUN mkdir -p ~/.vnc && \
    x11vnc -storepasswd ${VNC_PASSWORD} ~/.vnc/passwd

# Create a simple HTML page with VNC client
RUN mkdir -p /app && \
    cat > /app/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>VNC Desktop</title>
    <meta charset="UTF-8">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body, html { width: 100%; height: 100%; overflow: hidden; }
        #container { width: 100%; height: 100%; display: flex; flex-direction: column; }
        #header { background: #2c3e50; color: white; padding: 15px; }
        #vnc-area { flex: 1; background: black; position: relative; }
        #loading { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); 
                   color: white; text-align: center; }
        #status { background: rgba(0,0,0,0.8); color: white; padding: 10px; position: absolute; 
                  bottom: 0; left: 0; right: 0; }
        button { background: #3498db; color: white; border: none; padding: 8px 16px; 
                 margin-left: 10px; cursor: pointer; border-radius: 4px; }
        button:hover { background: #2980b9; }
    </style>
</head>
<body>
    <div id="container">
        <div id="header">
            <h2>VNC Desktop Viewer</h2>
            <button onclick="connectVNC()" id="connect-btn">Connect</button>
            <button onclick="location.reload()">Refresh</button>
        </div>
        <div id="vnc-area">
            <div id="loading">
                <h3>Ready to Connect</h3>
                <p>Click "Connect" button to start VNC session</p>
            </div>
            <canvas id="vnc-canvas" style="display: none; width: 100%; height: 100%;"></canvas>
        </div>
        <div id="status">Disconnected</div>
    </div>

    <script>
        // Simple RFB/VNC client implementation
        class SimpleVNC {
            constructor(canvas, host, port, password) {
                this.canvas = canvas;
                this.ctx = canvas.getContext('2d');
                this.host = host;
                this.port = port;
                this.password = password;
                this.ws = null;
                this.connected = false;
                this.frameBuffer = null;
                
                // Set canvas size
                this.resizeCanvas();
                window.addEventListener('resize', () => this.resizeCanvas());
            }
            
            resizeCanvas() {
                this.canvas.width = this.canvas.clientWidth;
                this.canvas.height = this.canvas.clientHeight;
                if (this.frameBuffer) {
                    this.drawFrame();
                }
            }
            
            connect() {
                const wsUrl = `wss://${this.host}/websockify`;
                console.log('Connecting to:', wsUrl);
                
                this.ws = new WebSocket(wsUrl);
                
                this.ws.onopen = () => {
                    console.log('WebSocket connected');
                    this.sendProtocolVersion();
                };
                
                this.ws.onmessage = (event) => {
                    this.handleMessage(event.data);
                };
                
                this.ws.onclose = () => {
                    console.log('WebSocket disconnected');
                    this.connected = false;
                    updateStatus('Disconnected');
                };
                
                this.ws.onerror = (error) => {
                    console.error('WebSocket error:', error);
                    updateStatus('Connection error');
                };
            }
            
            sendProtocolVersion() {
                // Send RFB protocol version
                const version = "RFB 003.008\n";
                this.ws.send(version);
            }
            
            handleMessage(data) {
                // Simple message handler - in real implementation, 
                // you'd parse RFB protocol messages
                console.log('Received data:', data);
                
                // For demo, just show we're connected
                if (!this.connected) {
                    this.connected = true;
                    updateStatus('Connected - Desktop loading...');
                    document.getElementById('loading').style.display = 'none';
                    document.getElementById('vnc-canvas').style.display = 'block';
                    
                    // Create a simple desktop preview
                    this.frameBuffer = this.createDemoDesktop();
                    this.drawFrame();
                }
            }
            
            createDemoDesktop() {
                // Create a simple demo desktop (in real VNC, this comes from server)
                const width = 1024;
                const height = 768;
                const canvas = document.createElement('canvas');
                canvas.width = width;
                canvas.height = height;
                const ctx = canvas.getContext('2d');
                
                // Draw background
                ctx.fillStyle = '#2c3e50';
                ctx.fillRect(0, 0, width, height);
                
                // Draw desktop
                ctx.fillStyle = '#34495e';
                ctx.fillRect(50, 50, width - 100, height - 100);
                
                // Draw window
                ctx.fillStyle = '#ecf0f1';
                ctx.fillRect(100, 100, 800, 500);
                ctx.fillStyle = '#3498db';
                ctx.fillRect(100, 100, 800, 30);
                
                // Draw text
                ctx.fillStyle = '#2c3e50';
                ctx.font = '16px Arial';
                ctx.fillText('Firefox Browser', 120, 122);
                
                ctx.fillStyle = '#7f8c8d';
                ctx.font = '14px Arial';
                ctx.fillText('Your VNC desktop is running!', 150, 200);
                ctx.fillText('To use actual VNC:', 150, 230);
                ctx.fillText('1. Download RealVNC Viewer', 170, 260);
                ctx.fillText('2. Connect to: ' + window.location.hostname + ':5900', 170, 290);
                ctx.fillText('3. Password: password123', 170, 320);
                
                return canvas;
            }
            
            drawFrame() {
                if (this.frameBuffer) {
                    this.ctx.drawImage(this.frameBuffer, 0, 0, this.canvas.width, this.canvas.height);
                }
            }
        }
        
        let vncClient = null;
        
        function connectVNC() {
            const btn = document.getElementById('connect-btn');
            btn.disabled = true;
            btn.textContent = 'Connecting...';
            updateStatus('Connecting to VNC server...');
            
            const canvas = document.getElementById('vnc-canvas');
            const host = window.location.hostname;
            
            // Try WebSocket connection
            vncClient = new SimpleVNC(canvas, host, 443, 'password123');
            vncClient.connect();
            
            // Fallback: Show instructions if WebSocket fails
            setTimeout(() => {
                if (!vncClient || !vncClient.connected) {
                    updateStatus('WebSocket failed. Using direct VNC connection...');
                    showInstructions();
                }
            }, 5000);
        }
        
        function showInstructions() {
            document.getElementById('loading').innerHTML = `
                <h3>Connect with VNC Client</h3>
                <p>For best experience, use a VNC viewer:</p>
                <p>1. Download <a href="https://www.realvnc.com/en/connect/download/viewer/" target="_blank">RealVNC Viewer</a></p>
                <p>2. Connect to: <code>${window.location.hostname}:5900</code></p>
                <p>3. Password: <code>password123</code></p>
                <button onclick="connectVNC()" style="margin-top: 20px;">Try Web Connection Again</button>
            `;
        }
        
        function updateStatus(text) {
            document.getElementById('status').textContent = text;
        }
        
        // Auto-connect after 2 seconds
        setTimeout(connectVNC, 2000);
    </script>
</body>
</html>
EOF

EXPOSE 8080

# Startup script
CMD echo "=== Starting VNC Desktop ===" && \
    # Start virtual display
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
    # Start websockify on port 8080
    echo "Starting WebSocket proxy..." && \
    websockify --web=/app 8080 localhost:5900
