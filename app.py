#!/usr/bin/env python3
"""
Real Browser RDP Server
Deploy this on Render to get a real browser accessible via web
"""

import os
import time
import base64
import threading
import queue
import json
from flask import Flask, render_template, Response, jsonify, request
from flask_cors import CORS
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.action_chains import ActionChains
from PIL import Image
import io
import numpy as np

app = Flask(__name__)
CORS(app)

# Global variables
browser = None
browser_lock = threading.Lock()
command_queue = queue.Queue()
screenshot_interval = 0.1  # 10 FPS
current_url = "https://www.google.com"
screen_width = 1280
screen_height = 720
mouse_x = 0
mouse_y = 0
connected_clients = set()

class BrowserManager:
    def __init__(self):
        self.driver = None
        self.screenshot_thread = None
        self.running = False
        self.last_screenshot = None
        self.screenshot_ready = threading.Event()
        
    def start_browser(self):
        """Start Chrome browser with remote debugging"""
        global browser
        
        chrome_options = Options()
        chrome_options.add_argument('--no-sandbox')
        chrome_options.add_argument('--disable-dev-shm-usage')
        chrome_options.add_argument('--disable-gpu')
        chrome_options.add_argument('--disable-software-rasterizer')
        chrome_options.add_argument('--window-size=1280,720')
        chrome_options.add_argument('--force-device-scale-factor=1')
        chrome_options.add_argument('--disable-background-networking')
        chrome_options.add_argument('--disable-default-apps')
        chrome_options.add_argument('--disable-extensions')
        chrome_options.add_argument('--disable-sync')
        chrome_options.add_argument('--disable-translate')
        chrome_options.add_argument('--metrics-recording-only')
        chrome_options.add_argument('--no-first-run')
        chrome_options.add_argument('--safebrowsing-disable-auto-update')
        chrome_options.add_argument('--disable-web-security')
        chrome_options.add_argument('--allow-running-insecure-content')
        
        # For Render deployment
        chrome_options.add_argument('--headless=new')
        chrome_options.add_argument('--remote-debugging-port=9222')
        chrome_options.add_argument('--remote-debugging-address=0.0.0.0')
        
        try:
            self.driver = webdriver.Chrome(options=chrome_options)
            self.driver.set_window_size(screen_width, screen_height)
            self.driver.get(current_url)
            
            # Start screenshot thread
            self.running = True
            self.screenshot_thread = threading.Thread(target=self._screenshot_worker, daemon=True)
            self.screenshot_thread.start()
            
            # Start command processor
            command_thread = threading.Thread(target=self._command_processor, daemon=True)
            command_thread.start()
            
            browser = self
            print("Browser started successfully")
            return True
            
        except Exception as e:
            print(f"Failed to start browser: {e}")
            return False
    
    def _screenshot_worker(self):
        """Continuously capture screenshots"""
        while self.running and self.driver:
            try:
                # Take screenshot
                screenshot = self.driver.get_screenshot_as_png()
                
                # Optimize image
                img = Image.open(io.BytesIO(screenshot))
                
                # Resize if needed
                if img.size != (screen_width, screen_height):
                    img = img.resize((screen_width, screen_height), Image.Resampling.LANCZOS)
                
                # Convert to JPEG for smaller size
                buffer = io.BytesIO()
                img.save(buffer, format='JPEG', quality=85, optimize=True)
                self.last_screenshot = buffer.getvalue()
                self.screenshot_ready.set()
                
            except Exception as e:
                print(f"Screenshot error: {e}")
                time.sleep(1)
            
            time.sleep(screenshot_interval)
    
    def _command_processor(self):
        """Process commands from clients"""
        while self.running:
            try:
                command = command_queue.get(timeout=1)
                self._execute_command(command)
            except queue.Empty:
                continue
            except Exception as e:
                print(f"Command error: {e}")
    
    def _execute_command(self, command):
        """Execute a browser command"""
        try:
            cmd_type = command.get('type')
            
            if cmd_type == 'navigate':
                url = command.get('url')
                if url:
                    self.driver.get(url)
                    
            elif cmd_type == 'click':
                x = command.get('x', 0)
                y = command.get('y', 0)
                button = command.get('button', 'left')
                
                # Convert coordinates
                window_size = self.driver.get_window_size()
                scale_x = window_size['width'] / screen_width
                scale_y = window_size['height'] / screen_height
                
                actual_x = x * scale_x
                actual_y = y * scale_y
                
                actions = ActionChains(self.driver)
                actions.move_by_offset(actual_x, actual_y)
                
                if button == 'left':
                    actions.click()
                elif button == 'right':
                    actions.context_click()
                elif button == 'middle':
                    actions.click(button='middle')
                    
                actions.perform()
                # Reset mouse position
                actions.move_by_offset(-actual_x, -actual_y).perform()
                
            elif cmd_type == 'mousemove':
                mouse_x = command.get('x', 0)
                mouse_y = command.get('y', 0)
                # Just update coordinates for now
                
            elif cmd_type == 'keydown':
                key = command.get('key')
                if key:
                    if key == 'Backspace':
                        self.driver.find_element(By.TAG_NAME, 'body').send_keys(Keys.BACKSPACE)
                    elif key == 'Enter':
                        self.driver.find_element(By.TAG_NAME, 'body').send_keys(Keys.ENTER)
                    elif key == 'Tab':
                        self.driver.find_element(By.TAG_NAME, 'body').send_keys(Keys.TAB)
                    elif key == 'Escape':
                        self.driver.find_element(By.TAG_NAME, 'body').send_keys(Keys.ESCAPE)
                    elif len(key) == 1:
                        self.driver.find_element(By.TAG_NAME, 'body').send_keys(key)
                        
            elif cmd_type == 'scroll':
                delta = command.get('delta', 0)
                # Execute JavaScript to scroll
                self.driver.execute_script(f"window.scrollBy(0, {delta * 50});")
                
            elif cmd_type == 'refresh':
                self.driver.refresh()
                
            elif cmd_type == 'back':
                self.driver.back()
                
            elif cmd_type == 'forward':
                self.driver.forward()
                
        except Exception as e:
            print(f"Command execution error: {e}")
    
    def stop(self):
        """Stop the browser"""
        self.running = False
        if self.screenshot_thread:
            self.screenshot_thread.join(timeout=5)
        if self.driver:
            self.driver.quit()

# Initialize browser manager
browser_manager = BrowserManager()

@app.route('/')
def index():
    """Serve the main page"""
    return '''
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
            }
            #urlBar {
                flex: 1;
                padding: 10px 15px;
                background: #0f172a;
                border: 1px solid #475569;
                border-radius: 6px;
                color: white;
                font-size: 14px;
            }
            button {
                padding: 10px 20px;
                background: #3b82f6;
                color: white;
                border: none;
                border-radius: 6px;
                cursor: pointer;
                font-weight: 500;
            }
            button:hover { background: #2563eb; }
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
                image-rendering: pixelated;
            }
            #status {
                background: #1e293b;
                padding: 10px;
                border-top: 1px solid #334155;
                font-size: 12px;
                color: #94a3b8;
            }
            #loading {
                position: absolute;
                top: 50%;
                left: 50%;
                transform: translate(-50%, -50%);
                color: white;
                font-size: 18px;
            }
        </style>
    </head>
    <body>
        <div id="container">
            <div id="header">
                <button onclick="goBack()">←</button>
                <button onclick="goForward()">→</button>
                <button onclick="reload()">↻</button>
                <input type="text" id="urlBar" placeholder="Enter URL..." onkeypress="handleEnter(event)">
                <button onclick="navigate()">Go</button>
                <button onclick="fullscreen()" style="margin-left: auto;">⛶</button>
            </div>
            
            <div id="screen">
                <canvas id="browserCanvas"></canvas>
                <div id="loading">Connecting to remote browser...</div>
            </div>
            
            <div id="status">
                Status: <span id="statusText">Connecting...</span> | 
                FPS: <span id="fps">0</span> | 
                Resolution: 1280x720
            </div>
        </div>
        
        <script>
            const canvas = document.getElementById('browserCanvas');
            const ctx = canvas.getContext('2d');
            const urlBar = document.getElementById('urlBar');
            const statusText = document.getElementById('statusText');
            const fpsElement = document.getElementById('fps');
            
            let ws = null;
            let isConnected = false;
            let frameCount = 0;
            let lastFpsUpdate = Date.now();
            let fps = 0;
            
            // Set canvas size
            function resizeCanvas() {
                const screen = document.getElementById('screen');
                canvas.width = screen.clientWidth;
                canvas.height = screen.clientHeight - 60;
            }
            
            window.addEventListener('resize', resizeCanvas);
            resizeCanvas();
            
            // Connect to WebSocket
            function connect() {
                const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
                const wsUrl = `${protocol}//${window.location.host}/ws`;
                
                ws = new WebSocket(wsUrl);
                
                ws.onopen = () => {
                    console.log('Connected to browser server');
                    isConnected = true;
                    statusText.textContent = 'Connected';
                    document.getElementById('loading').style.display = 'none';
                };
                
                ws.onmessage = (event) => {
                    const data = JSON.parse(event.data);
                    
                    if (data.type === 'screenshot') {
                        // Update URL bar
                        if (data.url) {
                            urlBar.value = data.url;
                        }
                        
                        // Draw image
                        const img = new Image();
                        img.onload = () => {
                            ctx.clearRect(0, 0, canvas.width, canvas.height);
                            ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
                            
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
                };
                
                ws.onclose = () => {
                    console.log('Disconnected from server');
                    isConnected = false;
                    statusText.textContent = 'Disconnected';
                    
                    // Try to reconnect after 2 seconds
                    setTimeout(() => {
                        if (!isConnected) {
                            console.log('Reconnecting...');
                            connect();
                        }
                    }, 2000);
                };
                
                ws.onerror = (error) => {
                    console.error('WebSocket error:', error);
                };
            }
            
            // Send command to server
            function sendCommand(command) {
                if (ws && ws.readyState === WebSocket.OPEN) {
                    ws.send(JSON.stringify(command));
                }
            }
            
            // Navigation functions
            function navigate() {
                const url = urlBar.value.trim();
                if (url) {
                    sendCommand({
                        type: 'navigate',
                        url: url.startsWith('http') ? url : 'https://' + url
                    });
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
            }
            
            function fullscreen() {
                const elem = document.getElementById('container');
                if (!document.fullscreenElement) {
                    elem.requestFullscreen().catch(err => {
                        console.log(`Error attempting to enable fullscreen: ${err.message}`);
                    });
                } else {
                    document.exitFullscreen();
                }
            }
            
            // Mouse events
            canvas.addEventListener('mousedown', (e) => {
                const rect = canvas.getBoundingClientRect();
                const x = (e.clientX - rect.left) * (1280 / canvas.width);
                const y = (e.clientY - rect.top) * (720 / canvas.height);
                
                sendCommand({
                    type: 'click',
                    x: Math.floor(x),
                    y: Math.floor(y),
                    button: e.button === 2 ? 'right' : 'left'
                });
                
                e.preventDefault();
            });
            
            canvas.addEventListener('mousemove', (e) => {
                const rect = canvas.getBoundingClientRect();
                const x = (e.clientX - rect.left) * (1280 / canvas.width);
                const y = (e.clientY - rect.top) * (720 / canvas.height);
                
                sendCommand({
                    type: 'mousemove',
                    x: Math.floor(x),
                    y: Math.floor(y)
                });
            });
            
            canvas.addEventListener('wheel', (e) => {
                sendCommand({
                    type: 'scroll',
                    delta: Math.sign(e.deltaY)
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
            
            // Connect on load
            window.addEventListener('load', () => {
                connect();
            });
        </script>
    </body>
    </html>
    '''

@app.route('/screenshot')
def get_screenshot():
    """Get latest screenshot"""
    if not browser or not browser.last_screenshot:
        return jsonify({'error': 'Browser not ready'}), 503
    
    browser.screenshot_ready.wait(timeout=5)
    
    try:
        # Get current URL
        current_url = browser.driver.current_url if browser.driver else ""
        
        return jsonify({
            'image': base64.b64encode(browser.last_screenshot).decode('utf-8'),
            'url': current_url,
            'timestamp': time.time()
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/ws')
def websocket_endpoint():
    """WebSocket endpoint for real-time updates"""
    from flask import request as flask_request
    
    if flask_request.headers.get('Upgrade', '').lower() != 'websocket':
        return 'WebSocket endpoint only', 400
    
    # This is a simplified WebSocket handler
    # In production, use Flask-SocketIO or similar
    return Response(status=426)  # Upgrade Required

@app.route('/command', methods=['POST'])
def send_command():
    """Send a command to the browser"""
    try:
        command = request.json
        command_queue.put(command)
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/status')
def status():
    """Get browser status"""
    if browser and browser.driver:
        return jsonify({
            'status': 'running',
            'url': browser.driver.current_url,
            'title': browser.driver.title,
            'connected': True
        })
    return jsonify({'status': 'not_running', 'connected': False})

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'ok', 'browser_running': browser is not None})

def start_browser():
    """Start the browser in background"""
    print("Starting browser...")
    if browser_manager.start_browser():
        print("Browser started successfully")
    else:
        print("Failed to start browser")

if __name__ == '__main__':
    # Start browser in background thread
    import threading
    browser_thread = threading.Thread(target=start_browser, daemon=True)
    browser_thread.start()
    
    # Wait a bit for browser to start
    time.sleep(3)
    
    # Start Flask server
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, threaded=True)
