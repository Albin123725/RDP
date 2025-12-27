FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV VNC_PASSWORD=password123

# Install all necessary packages
RUN apt update && apt install -y \
    x11vnc \
    xvfb \
    fluxbox \
    firefox \
    python3 \
    python3-pip \
    nginx \
    net-tools \
    curl \
    --no-install-recommends && \
    apt clean

# Install a DIFFERENT WebSocket library that handles HEAD requests
RUN pip3 install simple-websocket-server

# Set VNC password
RUN mkdir -p ~/.vnc && \
    x11vnc -storepasswd ${VNC_PASSWORD} ~/.vnc/passwd

# Create a robust WebSocket proxy that handles HEAD requests
RUN cat > /ws_server.py << 'EOF'
#!/usr/bin/env python3
from simple_websocket_server import WebSocketServer, WebSocket
import socket
import threading
import time

class VNCProxy(WebSocket):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.vnc_socket = None
        self.running = True
        
    def connected(self):
        print(f"WebSocket connected from {self.address}")
        try:
            # Connect to VNC server
            self.vnc_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.vnc_socket.connect(('localhost', 5900))
            self.vnc_socket.setblocking(False)
            
            # Start thread to read from VNC
            self.thread = threading.Thread(target=self.read_from_vnc)
            self.thread.daemon = True
            self.thread.start()
        except Exception as e:
            print(f"Error connecting to VNC: {e}")
            self.send_message("ERROR: Cannot connect to VNC server")
            self.close()
    
    def handle(self):
        # Send received data to VNC server
        if self.vnc_socket:
            try:
                self.vnc_socket.send(self.data)
            except:
                pass
    
    def read_from_vnc(self):
        while self.running and self.vnc_socket:
            try:
                data = self.vnc_socket.recv(4096)
                if data:
                    self.send_message(data)
                else:
                    break
            except socket.error:
                time.sleep(0.01)
            except:
                break
    
    def handle_close(self):
        print(f"WebSocket closed from {self.address}")
        self.running = False
        if self.vnc_socket:
            self.vnc_socket.close()

# Create HTTP server that handles HEAD requests
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading

class HealthHandler(BaseHTTPRequestHandler):
    def do_HEAD(self):
        self.send_response(200)
        self.end_headers()
    
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<html><body><h1>VNC Server Ready</h1><p>Connect with VNC client to port 5900</p></body></html>')
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        pass  # Disable logging

def start_http_server():
    server = HTTPServer(('0.0.0.0', 6080), HealthHandler)
    print("HTTP server started on port 6080")
    server.serve_forever()

if __name__ == "__main__":
    # Start HTTP server in background thread
    http_thread = threading.Thread(target=start_http_server)
    http_thread.daemon = True
    http_thread.start()
    
    # Start WebSocket server
    print("WebSocket server starting on port 6081")
    server = WebSocketServer('0.0.0.0', 6081, VNCProxy)
    server.serve_forever()
EOF

# HTML
RUN mkdir -p /var/www/html && \
    echo '<html><body>
    <h1>VNC Desktop</h1>
    <p>Starting VNC server...</p>
    <script>
    setTimeout(() => location.reload(), 3000);
    </script>
    </body></html>' > /var/www/html/index.html

EXPOSE 80

# Start everything
CMD echo "Starting VNC Desktop..." && \
    rm -f /tmp/.X1-lock && \
    # Start Xvfb
    Xvfb :1 -screen 0 1024x768x24 & \
    sleep 3 && \
    # Start fluxbox
    fluxbox & \
    sleep 2 && \
    # Start Firefox
    firefox about:blank & \
    sleep 2 && \
    # Start x11vnc with NO WebSocket
    x11vnc -display :1 -forever -shared -rfbauth ~/.vnc/passwd -localhost -nosel -noxdamage & \
    sleep 2 && \
    # Start Python server
    python3 /ws_server.py & \
    sleep 2 && \
    # Start nginx
    echo "VNC Desktop Ready!" && \
    echo "Web: https://$(hostname)" && \
    echo "VNC: $(hostname):5900" && \
    echo "Password: ${VNC_PASSWORD}" && \
    nginx -g 'daemon off;'
