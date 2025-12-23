#!/usr/bin/env python3
"""
Real Browser RDP Server - All in One File
No templates directory needed
"""

import os
import time
import base64
import threading
import queue
import json
import asyncio
import websockets
from flask import Flask, Response, jsonify, request
from flask_cors import CORS
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.action_chains import ActionChains
from PIL import Image
import io

app = Flask(__name__)
CORS(app)

# HTML content embedded in the Python file
HTML_CONTENT = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Real Browser RDP</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #0f172a;
            color: white;
            height: 100vh;
            overflow: hidden;
        }
        #container {
            display: flex;
            flex-direction: column;
            height: 100vh;
        }
        #header {
            background: #1e293b;
            padding: 15px;
            border-bottom: 1px solid #334155;
            display: flex;
            gap: 10px;
            align-items: center;
            flex-wrap: wrap;
        }
        #urlBar {
            flex: 1;
            min-width: 200px;
            padding: 10px 15px;
            background: #0f172a;
            border: 1px solid #475569;
            border-radius: 6px;
            color: white;
            font-size: 14px;
        }
        button {
            padding: 10px 15px;
            background: #3b82f6;
            color: white;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-weight: 500;
            white-space: nowrap;
        }
        button:hover { background: #2563eb; }
        button:disabled { opacity: 0.5; cursor: not-allowed; }
        #screen {
            flex: 1;
            background: #000;
            position: relative;
            overflow: hidden;
        }
        #browserCanvas {
            width: 100%;
            height: 100%;
            cursor: default;
        }
        #status {
            background: #1e293b;
            padding: 10px;
            border-top: 1px solid #334155;
            font-size: 12px;
            color: #94a3b8;
            display: flex;
            gap: 15px;
            flex-wrap: wrap;
        }
        #loading {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            color: white;
            font-size: 18px;
            text-align: center;
        }
        .spinner {
            border: 4px solid rgba(255, 255, 255, 0.1);
            border-top: 4px solid #3b82f6;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto 15px;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .controls {
            display: flex;
            gap: 8px;
        }
        @media (max-width: 768px) {
            #header { padding: 10px; }
            button { padding: 8px 12px; font-size: 12px; }
            #urlBar { font-size: 12px; }
        }
    </style>
</head>
<body>
    <div id="container">
        <div id="header">
            <div class="controls">
                <button onclick="goBack()" title="Back">←</button>
                <button onclick="goForward()" title="Forward">→</button>
                <button onclick="reload()" title="Refresh">↻</button>
            </div>
            <input type="text" id="urlBar" placeholder="Enter URL (e.g., https://google.com)" onkeypress="handleEnter(event)">
            <button onclick="navigate()">Go</button>
            <button onclick="fullscreen()" title="Fullscreen" style="margin-left: auto;">⛶</button>
        </div>
        
        <div id="screen">
            <canvas id="browserCanvas"></canvas>
            <div id="loading">
                <div class="spinner"></div>
                <div>Starting remote browser...</div>
                <div style="font-size: 12px; margin-top: 10px; color: #94a3b8;">
                    This may take 10-20 seconds on first load
                </div>
            </div>
        </div>
        
        <div id="status">
            <span>Status: <span id="statusText">Connecting...</span></span>
            <span>FPS: <span id="fps">0</span></span>
            <span>Resolution: <span id="resolution">1280x720</span></span>
            <span>URL: <span id="currentUrl">-</span></span>
        </div>
    </div>
    
    <script>
        const canvas = document.getElementById('browserCanvas');
        const ctx = canvas.getContext('2d');
        const urlBar = document.getElementById('urlBar');
        const statusText = document.getElementById('statusText');
        const fpsElement = document.getElementById('fps');
        const resolutionElement = document.getElementById('resolution');
        const currentUrlElement = document.getElementById('currentUrl');
        const loadingElement = document.getElementById('loading');
        
        let ws = null;
        let isConnected = false;
        let frameCount = 0;
        let lastFpsUpdate = Date.now();
        let fps = 0;
        let reconnectAttempts = 0;
        const maxReconnectAttempts = 10;
        
        // Set canvas size
        function resizeCanvas() {
            const screen = document.getElementById('screen');
            canvas.width = screen.clientWidth;
            canvas.height = screen.clientHeight;
            resolutionElement.textContent = `${canvas.width}x${canvas.height}`;
        }
        
        window.addEventListener('resize', resizeCanvas);
        resizeCanvas();
        
        // Connect to WebSocket
        function connect() {
            const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
            const wsUrl = `${protocol}//${window.location.host}/ws`;
            
            console.log('Connecting to:', wsUrl);
            
            ws = new WebSocket(wsUrl);
            
            ws.onopen = () => {
                console.log('Connected to browser server');
                isConnected = true;
                reconnectAttempts = 0;
                statusText.textContent = 'Connected';
                statusText.style.color = '#10b981';
                loadingElement.style.display = 'none';
            };
            
            ws.onmessage = (event) => {
                try {
                    const data = JSON.parse(event.data);
                    
                    if (data.type === 'screenshot') {
                        // Update URL bar
                        if (data.url && data.url !== 'data:,') {
                            urlBar.value = data.url;
                            currentUrlElement.textContent = new URL(data.url).hostname;
                        }
                        
                        // Draw image
                        const img = new Image();
                        img.onload = () => {
                            ctx.clearRect(0, 0, canvas.width, canvas.height);
                            
                            // Maintain aspect ratio
                            const scale = Math.min(
                                canvas.width / img.width,
                                canvas.height / img.height
                            );
                            const width = img.width * scale;
                            const height = img.height * scale;
                            const x = (canvas.width - width) / 2;
                            const y = (canvas.height - height) / 2;
                            
                            ctx.drawImage(img, x, y, width, height);
                            
                            // Update FPS
                            frameCount++;
                            const now = Date.now();
                            if (now - lastFpsUpdate >= 1000) {
                                fps = frameCount;
                                fpsElement.textContent = fps;
                                frameCount = 0;
                                lastFpsUpdate = now;
                            }
                        };
                        img.src = 'data:image/jpeg;base64,' + data.image;
                    }
                    else if (data.type === 'error') {
                        statusText.textContent = 'Error: ' + data.message;
                        statusText.style.color = '#ef4444';
                    }
                } catch (e) {
                    console.error('Error processing message:', e);
                }
            };
            
            ws.onclose = () => {
                console.log('Disconnected from server');
                isConnected = false;
                statusText.textContent = 'Disconnected';
                statusText.style.color = '#ef4444';
                loadingElement.style.display = 'block';
                
                // Try to reconnect
                if (reconnectAttempts < maxReconnectAttempts) {
                    reconnectAttempts++;
                    const delay = Math.min(1000 * reconnectAttempts, 10000);
                    console.log(`Reconnecting in ${delay}ms... (attempt ${reconnectAttempts})`);
                    
                    setTimeout(() => {
                        if (!isConnected) {
                            connect();
                        }
                    }, delay);
                }
            };
            
            ws.onerror = (error) => {
                console.error('WebSocket error:', error);
            };
        }
        
        // Send command to server
        function sendCommand(command) {
            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify(command));
                return true;
            }
            return false;
        }
        
        // Navigation functions
        function navigate() {
            const url = urlBar.value.trim();
            if (url) {
                const fullUrl = url.startsWith('http') ? url : 'https://' + url;
                if (sendCommand({
                    type: 'navigate',
                    url: fullUrl
                })) {
                    statusText.textContent = 'Navigating...';
                    statusText.style.color = '#f59e0b';
                }
            }
        }
        
        function handleEnter(event) {
            if (event.key === 'Enter') {
                navigate();
            }
        }
        
        function goBack() {
            sendCommand({ type: 'back' });
        }
        
        function goForward() {
            sendCommand({ type: 'forward' });
        }
        
        function reload() {
            sendCommand({ type: 'refresh' });
            statusText.textContent = 'Refreshing...';
            statusText.style.color = '#f59e0b';
        }
        
        function fullscreen() {
            const elem = document.getElementById('container');
            if (!document.fullscreenElement) {
                elem.requestFullscreen().catch(err => {
                    console.log('Fullscreen error:', err);
                });
            } else {
                document.exitFullscreen();
            }
        }
        
        // Mouse events
        canvas.addEventListener('mousedown', (e) => {
            const rect = canvas.getBoundingClientRect();
            const imgRect = getImageRect();
            if (!imgRect) return;
            
            // Calculate click position relative to image
            const scaleX = imgRect.width / 1280;
            const scaleY = imgRect.height / 720;
            
            const x = Math.floor((e.clientX - rect.left - imgRect.x) / scaleX);
            const y = Math.floor((e.clientY - rect.top - imgRect.y) / scaleY);
            
            if (x >= 0 && x < 1280 && y >= 0 && y < 720) {
                sendCommand({
                    type: 'click',
                    x: x,
                    y: y,
                    button: e.button === 2 ? 'right' : 'left'
                });
            }
            
            e.preventDefault();
        });
        
        canvas.addEventListener('mousemove', (e) => {
            const rect = canvas.getBoundingClientRect();
            const imgRect = getImageRect();
            if (!imgRect) return;
            
            const scaleX = imgRect.width / 1280;
            const scaleY = imgRect.height / 720;
            
            const x = Math.floor((e.clientX - rect.left - imgRect.x) / scaleX);
            const y = Math.floor((e.clientY - rect.top - imgRect.y) / scaleY);
            
            if (x >= 0 && x < 1280 && y >= 0 && y < 720) {
                sendCommand({
                    type: 'mousemove',
                    x: x,
                    y: y
                });
            }
        });
        
        canvas.addEventListener('wheel', (e) => {
            sendCommand({
                type: 'scroll',
                delta: Math.sign(e.deltaY) * 100
            });
            e.preventDefault();
        });
        
        canvas.addEventListener('contextmenu', (e) => {
            e.preventDefault();
        });
        
        // Keyboard events
        document.addEventListener('keydown', (e) => {
            // Don't capture keys in URL bar
            if (e.target === urlBar) return;
            
            // Global shortcuts
            if (e.ctrlKey || e.metaKey) {
                switch (e.key.toLowerCase()) {
                    case 'l':
                        e.preventDefault();
                        urlBar.focus();
                        urlBar.select();
                        return;
                    case 'r':
                        e.preventDefault();
                        reload();
                        return;
                    case 't':
                        // Can't open new tabs in remote browser
                        e.preventDefault();
                        return;
                }
            }
            
            // Send key to browser
            sendCommand({
                type: 'keydown',
                key: e.key
            });
            
            // Prevent default for special keys
            if ([
                'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight',
                'Tab', 'F5', 'F11', 'Escape'
            ].includes(e.key)) {
                e.preventDefault();
            }
        });
        
        // Helper to get image position
        function getImageRect() {
            // This assumes the image is centered
            const imgWidth = 1280;
            const imgHeight = 720;
            const scale = Math.min(canvas.width / imgWidth, canvas.height / imgHeight);
            const width = imgWidth * scale;
            const height = imgHeight * scale;
            const x = (canvas.width - width) / 2;
            const y = (canvas.height - height) / 2;
            
            return { x, y, width, height };
        }
        
        // Connect on load
        window.addEventListener('load', () => {
            connect();
            
            // Auto-connect if disconnected
            setInterval(() => {
                if (!isConnected && ws.readyState === WebSocket.CLOSED) {
                    if (reconnectAttempts < maxReconnectAttempts) {
                        connect();
                    }
                }
            }, 5000);
        });
        
        // Handle page visibility
        document.addEventListener('visibilitychange', () => {
            if (!document.hidden && !isConnected) {
                connect();
            }
        });
    </script>
</body>
</html>
'''

# Browser management
class BrowserManager:
    def __init__(self):
        self.driver = None
        self.screenshot_thread = None
        self.command_thread = None
        self.running = False
        self.last_screenshot = None
        self.screenshot_ready = threading.Event()
        self.command_queue = queue.Queue()
        self.websocket_clients = set()
        
    def start(self):
        """Start the browser"""
        try:
            print("Starting Chrome browser...")
            
            chrome_options = Options()
            chrome_options.add_argument('--no-sandbox')
            chrome_options.add_argument('--disable-dev-shm-usage')
            chrome_options.add_argument('--disable-gpu')
            chrome_options.add_argument(f'--window-size={1280},{720}')
            chrome_options.add_argument('--force-device-scale-factor=1')
            
            # Headless mode for Render
            chrome_options.add_argument('--headless=new')
            
            # Performance optimizations
            chrome_options.add_argument('--disable-background-networking')
            chrome_options.add_argument('--disable-default-apps')
            chrome_options.add_argument('--disable-extensions')
            chrome_options.add_argument('--disable-sync')
            chrome_options.add_argument('--disable-translate')
            chrome_options.add_argument('--metrics-recording-only')
            chrome_options.add_argument('--no-first-run')
            chrome_options.add_argument('--disable-web-security')
            chrome_options.add_argument('--allow-running-insecure-content')
            
            # Disable features to save memory
            chrome_options.add_experimental_option('excludeSwitches', ['enable-automation'])
            chrome_options.add_experimental_option('useAutomationExtension', False)
            
            # Set Chrome binary location
            chrome_options.binary_location = '/usr/bin/google-chrome'
            
            self.driver = webdriver.Chrome(options=chrome_options)
            
            # Set initial URL
            self.driver.get('https://www.google.com')
            print(f"Browser started. Initial URL: {self.driver.current_url}")
            
            self.running = True
            
            # Start threads
            self.screenshot_thread = threading.Thread(target=self._screenshot_loop, daemon=True)
            self.screenshot_thread.start()
            
            self.command_thread = threading.Thread(target=self._command_loop, daemon=True)
            self.command_thread.start()
            
            return True
            
        except Exception as e:
            print(f"Failed to start browser: {e}")
            return False
    
    def _screenshot_loop(self):
        """Continuously capture screenshots"""
        while self.running and self.driver:
            try:
                # Take screenshot
                screenshot = self.driver.get_screenshot_as_png()
                
                # Compress image
                img = Image.open(io.BytesIO(screenshot))
                
                # Convert to JPEG for smaller size
                buffer = io.BytesIO()
                img.save(buffer, format='JPEG', quality=80, optimize=True)
                self.last_screenshot = buffer.getvalue()
                self.screenshot_ready.set()
                
                # Notify WebSocket clients
                self._notify_clients()
                
            except Exception as e:
                print(f"Screenshot error: {e}")
            
            # Throttle to 5 FPS to save CPU
            time.sleep(0.2)
    
    def _command_loop(self):
        """Process commands from queue"""
        while self.running:
            try:
                command = self.command_queue.get(timeout=1)
                self._execute_command(command)
            except queue.Empty:
                continue
            except Exception as e:
                print(f"Command error: {e}")
    
    def _execute_command(self, command):
        """Execute a browser command"""
        if not self.driver:
            return
        
        try:
            cmd_type = command.get('type')
            
            if cmd_type == 'navigate':
                url = command.get('url', '')
                if url:
                    print(f"Navigating to: {url}")
                    self.driver.get(url)
                    
            elif cmd_type == 'click':
                x = command.get('x', 0)
                y = command.get('y', 0)
                button = command.get('button', 'left')
                
                # Use JavaScript to click at position
                script = f"""
                var elem = document.elementFromPoint({x}, {y});
                if (elem) {{
                    var event = new MouseEvent('click', {{
                        view: window,
                        bubbles: true,
                        cancelable: true,
                        clientX: {x},
                        clientY: {y}
                    }});
                    elem.dispatchEvent(event);
                }}
                """
                self.driver.execute_script(script)
                
            elif cmd_type == 'mousemove':
                # Just update mouse position
                pass
                
            elif cmd_type == 'keydown':
                key = command.get('key', '')
                if key:
                    # Send key to active element
                    try:
                        active_elem = self.driver.switch_to.active_element
                        if active_elem:
                            active_elem.send_keys(key)
                        else:
                            # Send to body if no active element
                            body = self.driver.find_element(By.TAG_NAME, 'body')
                            body.send_keys(key)
                    except:
                        # Fallback: send to body
                        body = self.driver.find_element(By.TAG_NAME, 'body')
                        body.send_keys(key)
                        
            elif cmd_type == 'scroll':
                delta = command.get('delta', 0)
                self.driver.execute_script(f"window.scrollBy(0, {delta});")
                
            elif cmd_type == 'refresh':
                self.driver.refresh()
                
            elif cmd_type == 'back':
                self.driver.back()
                
            elif cmd_type == 'forward':
                self.driver.forward()
                
        except Exception as e:
            print(f"Command execution error: {e}")
    
    def _notify_clients(self):
        """Notify all WebSocket clients"""
        if not self.last_screenshot:
            return
        
        message = {
            'type': 'screenshot',
            'image': base64.b64encode(self.last_screenshot).decode('utf-8'),
            'url': self.driver.current_url if self.driver else '',
            'timestamp': time.time()
        }
        
        # This will be handled by the WebSocket handler
        for client in list(self.websocket_clients):
            try:
                client.send(json.dumps(message))
            except:
                self.websocket_clients.remove(client)
    
    def stop(self):
        """Stop the browser"""
        self.running = False
        if self.driver:
            self.driver.quit()

# Global browser instance
browser_manager = BrowserManager()

@app.route('/')
def index():
    """Serve the main page"""
    return HTML_CONTENT

@app.route('/screenshot')
def get_screenshot():
    """Get latest screenshot (HTTP fallback)"""
    if not browser_manager.last_screenshot:
        return jsonify({'error': 'Browser not ready'}), 503
    
    browser_manager.screenshot_ready.wait(timeout=5)
    
    return jsonify({
        'image': base64.b64encode(browser_manager.last_screenshot).decode('utf-8'),
        'url': browser_manager.driver.current_url if browser_manager.driver else '',
        'timestamp': time.time()
    })

@app.route('/command', methods=['POST'])
def send_command():
    """Send command to browser"""
    try:
        command = request.json
        browser_manager.command_queue.put(command)
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/status')
def status():
    """Get browser status"""
    if browser_manager.driver:
        return jsonify({
            'status': 'running',
            'url': browser_manager.driver.current_url,
            'title': browser_manager.driver.title,
            'ready': True
        })
    return jsonify({'status': 'starting', 'ready': False})

@app.route('/health')
def health():
    """Health check"""
    return jsonify({
        'status': 'ok',
        'browser': 'running' if browser_manager.driver else 'starting',
        'timestamp': time.time()
    })

# WebSocket handler
connected_clients = set()

async def websocket_handler(websocket, path):
    """Handle WebSocket connections"""
    connected_clients.add(websocket)
    print(f"WebSocket client connected. Total: {len(connected_clients)}")
    
    try:
        # Send initial screenshot if available
        if browser_manager.last_screenshot:
            message = {
                'type': 'screenshot',
                'image': base64.b64encode(browser_manager.last_screenshot).decode('utf-8'),
                'url': browser_manager.driver.current_url if browser_manager.driver else '',
                'timestamp': time.time()
            }
            await websocket.send(json.dumps(message))
        
        # Handle incoming messages
        async for message in websocket:
            try:
                command = json.loads(message)
                browser_manager.command_queue.put(command)
            except json.JSONDecodeError:
                print(f"Invalid JSON: {message}")
    
    except websockets.exceptions.ConnectionClosed:
        print("WebSocket connection closed")
    finally:
        connected_clients.remove(websocket)
        print(f"WebSocket client disconnected. Total: {len(connected_clients)}")

async def broadcast_screenshots():
    """Broadcast screenshots to all connected clients"""
    while True:
        if browser_manager.last_screenshot and connected_clients:
            message = {
                'type': 'screenshot',
                'image': base64.b64encode(browser_manager.last_screenshot).decode('utf-8'),
                'url': browser_manager.driver.current_url if browser_manager.driver else '',
                'timestamp': time.time()
            }
            
            message_json = json.dumps(message)
            for client in list(connected_clients):
                try:
                    await client.send(message_json)
                except:
                    connected_clients.remove(client)
        
        await asyncio.sleep(0.2)  # 5 FPS

async def main():
    """Main async function"""
    # Start browser
    print("Starting browser manager...")
    browser_manager.start()
    
    # Start WebSocket server
    print("Starting WebSocket server...")
    websocket_server = await websockets.serve(
        websocket_handler,
        "0.0.0.0",
        int(os.environ.get('WEBSOCKET_PORT', 8081)),
        ping_interval=20,
        ping_timeout=40
    )
    
    # Start screenshot broadcaster
    asyncio.create_task(broadcast_screenshots())
    
    print(f"WebSocket server running on port {os.environ.get('WEBSOCKET_PORT', 8081)}")
    
    # Keep running
    await asyncio.Future()

def run_flask():
    """Run Flask server"""
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, threaded=True)

if __name__ == '__main__':
    # Start browser in background thread
    import threading
    browser_thread = threading.Thread(target=browser_manager.start, daemon=True)
    browser_thread.start()
    
    # Start WebSocket server in background thread
    def run_websocket():
        asyncio.run(main())
    
    websocket_thread = threading.Thread(target=run_websocket, daemon=True)
    websocket_thread.start()
    
    # Wait a moment for browser to start
    time.sleep(3)
    
    # Start Flask
    run_flask()
