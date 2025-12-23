#!/usr/bin/env python3
"""
Real Browser RDP - Working Version
"""

import os
import time
import base64
import threading
import queue
import json
from flask import Flask, Response, jsonify, request
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from PIL import Image
import io

app = Flask(__name__)

# HTML content
HTML = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Remote Browser</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            background: #1a1a1a; 
            color: white;
            font-family: Arial, sans-serif;
            height: 100vh;
            overflow: hidden;
        }
        .container {
            display: flex;
            flex-direction: column;
            height: 100vh;
        }
        .header {
            background: #2d2d2d;
            padding: 10px;
            display: flex;
            gap: 10px;
            align-items: center;
            border-bottom: 1px solid #444;
        }
        .url-bar {
            flex: 1;
            padding: 8px 12px;
            background: #1a1a1a;
            border: 1px solid #555;
            border-radius: 4px;
            color: white;
        }
        button {
            padding: 8px 16px;
            background: #4285f4;
            border: none;
            border-radius: 4px;
            color: white;
            cursor: pointer;
        }
        button:hover { background: #3367d6; }
        #browser-frame {
            flex: 1;
            background: black;
            display: flex;
            justify-content: center;
            align-items: center;
        }
        #screen {
            max-width: 100%;
            max-height: 100%;
        }
        #status {
            padding: 8px;
            background: #2d2d2d;
            border-top: 1px solid #444;
            font-size: 12px;
            color: #aaa;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <button onclick="goBack()">←</button>
            <button onclick="goForward()">→</button>
            <button onclick="reload()">↻</button>
            <input type="text" class="url-bar" id="url" placeholder="Enter URL..." onkeypress="if(event.key=='Enter')navigate()">
            <button onclick="navigate()">Go</button>
        </div>
        
        <div id="browser-frame">
            <img id="screen" src="" alt="Remote Browser">
        </div>
        
        <div id="status">
            Status: <span id="status-text">Loading...</span>
        </div>
    </div>

    <script>
        let currentUrl = '';
        let refreshInterval;
        
        function updateScreen() {
            fetch('/screenshot?' + new Date().getTime())
                .then(r => r.json())
                .then(data => {
                    if (data.image) {
                        document.getElementById('screen').src = 'data:image/jpeg;base64,' + data.image;
                        document.getElementById('status-text').textContent = 'Connected';
                        if (data.url && data.url !== currentUrl) {
                            currentUrl = data.url;
                            document.getElementById('url').value = data.url;
                        }
                    }
                })
                .catch(e => {
                    document.getElementById('status-text').textContent = 'Error: ' + e.message;
                });
        }
        
        function navigate() {
            const url = document.getElementById('url').value;
            if (url) {
                fetch('/navigate', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({url: url})
                });
                document.getElementById('status-text').textContent = 'Navigating...';
            }
        }
        
        function goBack() {
            fetch('/back', {method: 'POST'});
        }
        
        function goForward() {
            fetch('/forward', {method: 'POST'});
        }
        
        function reload() {
            fetch('/refresh', {method: 'POST'});
            document.getElementById('status-text').textContent = 'Refreshing...';
        }
        
        // Start auto-refresh
        setInterval(updateScreen, 500);
        updateScreen();
    </script>
</body>
</html>
'''

class BrowserManager:
    def __init__(self):
        self.driver = None
        self.lock = threading.Lock()
        self.start_browser()
    
    def start_browser(self):
        """Start Chrome browser"""
        try:
            print("Starting Chrome browser...")
            
            options = Options()
            options.add_argument('--no-sandbox')
            options.add_argument('--disable-dev-shm-usage')
            options.add_argument('--headless=new')
            options.add_argument('--window-size=1280,720')
            options.add_argument('--disable-gpu')
            
            # For Render compatibility
            options.binary_location = '/usr/bin/google-chrome'
            
            self.driver = webdriver.Chrome(options=options)
            self.driver.get('https://www.google.com')
            print("Browser started successfully")
            
        except Exception as e:
            print(f"Failed to start browser: {e}")
    
    def get_screenshot(self):
        """Get screenshot as base64"""
        with self.lock:
            if not self.driver:
                return None
            
            try:
                # Take screenshot
                screenshot = self.driver.get_screenshot_as_png()
                
                # Optimize image
                img = Image.open(io.BytesIO(screenshot))
                img = img.resize((1024, 576), Image.Resampling.LANCZOS)
                
                # Convert to JPEG
                buffer = io.BytesIO()
                img.save(buffer, format='JPEG', quality=85)
                return base64.b64encode(buffer.getvalue()).decode('utf-8')
                
            except Exception as e:
                print(f"Screenshot error: {e}")
                return None
    
    def navigate(self, url):
        """Navigate to URL"""
        with self.lock:
            if self.driver:
                try:
                    if not url.startswith(('http://', 'https://')):
                        url = 'https://' + url
                    self.driver.get(url)
                    return True
                except Exception as e:
                    print(f"Navigation error: {e}")
                    return False
        return False
    
    def back(self):
        """Go back"""
        with self.lock:
            if self.driver:
                try:
                    self.driver.back()
                    return True
                except:
                    return False
        return False
    
    def forward(self):
        """Go forward"""
        with self.lock:
            if self.driver:
                try:
                    self.driver.forward()
                    return True
                except:
                    return False
        return False
    
    def refresh(self):
        """Refresh page"""
        with self.lock:
            if self.driver:
                try:
                    self.driver.refresh()
                    return True
                except:
                    return False
        return False
    
    def get_current_url(self):
        """Get current URL"""
        with self.lock:
            if self.driver:
                try:
                    return self.driver.current_url
                except:
                    return ''
        return ''

# Initialize browser
browser = BrowserManager()

@app.route('/')
def index():
    return HTML

@app.route('/screenshot')
def screenshot():
    """Get screenshot"""
    image = browser.get_screenshot()
    if image:
        return jsonify({
            'image': image,
            'url': browser.get_current_url()
        })
    return jsonify({'error': 'Browser not ready'}), 503

@app.route('/navigate', methods=['POST'])
def navigate():
    """Navigate to URL"""
    data = request.json
    url = data.get('url', '')
    if url:
        success = browser.navigate(url)
        return jsonify({'success': success})
    return jsonify({'success': False}), 400

@app.route('/back', methods=['POST'])
def back():
    """Go back"""
    success = browser.back()
    return jsonify({'success': success})

@app.route('/forward', methods=['POST'])
def forward():
    """Go forward"""
    success = browser.forward()
    return jsonify({'success': success})

@app.route('/refresh', methods=['POST'])
def refresh():
    """Refresh page"""
    success = browser.refresh()
    return jsonify({'success': success})

@app.route('/status')
def status():
    """Get status"""
    return jsonify({
        'running': browser.driver is not None,
        'url': browser.get_current_url()
    })

@app.route('/health')
def health():
    """Health check"""
    return jsonify({'status': 'ok', 'browser': browser.driver is not None})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
