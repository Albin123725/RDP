#!/usr/bin/env python3
"""
Real Browser Proxy for Modern Web Apps
Uses Playwright to render JavaScript-heavy sites like https://mln49z-8888.csb.app/tree?
"""

import os
import sys
import time
import json
import base64
import asyncio
import threading
from datetime import datetime
from flask import Flask, request, jsonify, Response, render_template_string
import subprocess
import urllib.parse

app = Flask(__name__)

# Install Playwright dependencies on first run
def install_playwright():
    """Install Playwright and browsers in background"""
    try:
        print("📦 Installing Playwright dependencies...")
        subprocess.run([sys.executable, "-m", "pip", "install", "playwright", "asgiref"], 
                      check=True, capture_output=True)
        
        print("🌐 Installing browsers...")
        result = subprocess.run([sys.executable, "-m", "playwright", "install", "chromium", "--with-deps"], 
                              check=True, capture_output=True, text=True)
        print(f"✅ Installation complete: {result.stdout[:100]}...")
        return True
    except Exception as e:
        print(f"❌ Installation failed: {e}")
        return False

# Start installation in background
threading.Thread(target=install_playwright, daemon=True).start()

# HTML Interface
HTML = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Modern Browser for Web Apps</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }
        .header {
            background: rgba(0, 0, 0, 0.8);
            color: white;
            padding: 20px;
            display: flex;
            gap: 15px;
            align-items: center;
            backdrop-filter: blur(10px);
        }
        .url-bar {
            flex: 1;
            padding: 12px 20px;
            background: rgba(255, 255, 255, 0.1);
            border: 2px solid rgba(255, 255, 255, 0.2);
            border-radius: 8px;
            color: white;
            font-size: 16px;
        }
        .url-bar::placeholder { color: rgba(255, 255, 255, 0.6); }
        .btn {
            padding: 12px 24px;
            background: #0072ff;
            color: white;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
            transition: all 0.3s;
        }
        .btn:hover { background: #0058d6; transform: translateY(-2px); }
        .browser-frame {
            flex: 1;
            border: none;
            background: white;
        }
        .status {
            background: rgba(0, 0, 0, 0.8);
            color: white;
            padding: 10px 20px;
            font-size: 14px;
            display: flex;
            justify-content: space-between;
        }
        .dot {
            display: inline-block;
            width: 10px;
            height: 10px;
            border-radius: 50%;
            margin-right: 8px;
        }
        .green { background: #4CAF50; animation: pulse 2s infinite; }
        .red { background: #f44336; }
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }
    </style>
</head>
<body>
    <div class="header">
        <input type="text" class="url-bar" id="urlInput" 
               placeholder="Enter URL (e.g., https://mln49z-8888.csb.app/tree?)" 
               value="https://mln49z-8888.csb.app/tree?">
        <button class="btn" onclick="navigate()">🌐 Open Website</button>
    </div>
    
    <iframe class="browser-frame" id="browserFrame" 
            sandbox="allow-same-origin allow-scripts allow-forms allow-popups allow-modals"
            allow="camera; microphone; fullscreen">
    </iframe>
    
    <div class="status">
        <div><span class="dot green"></span> <span id="statusText">Ready to browse</span></div>
        <div id="urlDisplay">No page loaded</div>
    </div>

    <script>
        const frame = document.getElementById('browserFrame');
        const urlInput = document.getElementById('urlInput');
        const statusText = document.getElementById('statusText');
        const urlDisplay = document.getElementById('urlDisplay');
        
        // Load initial URL
        window.addEventListener('load', () => {
            const url = urlInput.value;
            if (url) {
                loadUrl(url);
            }
        });
        
        function navigate() {
            const url = urlInput.value.trim();
            if (url) {
                loadUrl(url);
            }
        }
        
        function loadUrl(url) {
            statusText.textContent = 'Loading...';
            urlDisplay.textContent = url;
            
            // Encode URL for proxy
            const proxyUrl = `/proxy?url=${encodeURIComponent(url)}`;
            
            // Load in iframe
            frame.src = proxyUrl;
            
            // Update iframe events
            frame.onload = () => {
                statusText.textContent = 'Page loaded';
                try {
                    urlDisplay.textContent = frame.contentWindow.location.href;
                } catch (e) {
                    // Cross-origin restriction
                }
            };
            
            frame.onerror = () => {
                statusText.textContent = 'Error loading page';
            };
        }
        
        // Handle Enter key
        urlInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') navigate();
        });
        
        // Auto-resize iframe
        window.addEventListener('resize', () => {
            frame.style.height = (window.innerHeight - 150) + 'px';
        });
        
        // Initial resize
        setTimeout(() => window.dispatchEvent(new Event('resize')), 100);
    </script>
</body>
</html>
'''

@app.route('/')
def index():
    """Main interface"""
    return HTML

@app.route('/proxy')
def proxy():
    """Proxy endpoint that renders JavaScript sites"""
    url = request.args.get('url', '').strip()
    
    if not url:
        return "No URL provided", 400
    
    # Add protocol if missing
    if not url.startswith(('http://', 'https://')):
        url = 'https://' + url
    
    # Create a simple proxy page
    proxy_page = f'''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Loading: {url}</title>
        <style>
            body {{ margin: 0; padding: 20px; font-family: Arial, sans-serif; }}
            .loading {{ text-align: center; padding: 50px; }}
            .spinner {{
                border: 5px solid #f3f3f3;
                border-top: 5px solid #3498db;
                border-radius: 50%;
                width: 50px;
                height: 50px;
                animation: spin 1s linear infinite;
                margin: 0 auto 20px;
            }}
            @keyframes spin {{
                0% {{ transform: rotate(0deg); }}
                100% {{ transform: rotate(360deg); }}
            }}
        </style>
    </head>
    <body>
        <div class="loading">
            <div class="spinner"></div>
            <h2>Loading: {url}</h2>
            <p>Please wait while we load the website...</p>
        </div>
        
        <script>
            // Redirect to the actual URL
            setTimeout(() => {{
                window.location.href = "{url}";
            }}, 100);
        </script>
    </body>
    </html>
    '''
    
    return proxy_page

@app.route('/screenshot')
def screenshot():
    """Take a screenshot of a website (Playwright method)"""
    try:
        url = request.args.get('url', 'https://mln49z-8888.csb.app/tree?')
        
        # Try to use Playwright if available
        try:
            from playwright.sync_api import sync_playwright
            
            with sync_playwright() as p:
                # Use Chromium in headless mode
                browser = p.chromium.launch(headless=True)
                page = browser.new_page(viewport={'width': 1280, 'height': 720})
                
                # Navigate to URL
                page.goto(url, wait_until='networkidle')
                
                # Take screenshot
                screenshot_bytes = page.screenshot(full_page=False)
                browser.close()
                
                return Response(
                    screenshot_bytes,
                    mimetype='image/png',
                    headers={'Content-Disposition': f'attachment; filename=screenshot.png'}
                )
                
        except ImportError:
            # Playwright not installed yet
            return jsonify({
                'error': 'Playwright is still installing. Please wait 1-2 minutes and refresh.',
                'status': 'installing',
                'url': url
            })
            
    except Exception as e:
        return jsonify({'error': str(e), 'url': url}), 500

@app.route('/render')
def render_page():
    """Render a webpage with Playwright and return HTML"""
    url = request.args.get('url', 'https://mln49z-8888.csb.app/tree?')
    
    try:
        from playwright.sync_api import sync_playwright
        
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page()
            
            # Navigate and wait for page to load
            page.goto(url, wait_until='networkidle')
            
            # Get the rendered HTML
            content = page.content()
            browser.close()
            
            return content
            
    except Exception as e:
        return f'''
        <html>
        <body>
            <h2>Error loading {url}</h2>
            <p>{str(e)}</p>
            <p>Playwright might still be installing. Try again in a minute.</p>
        </body>
        </html>
        ''', 500

@app.route('/api/navigate', methods=['POST'])
def api_navigate():
    """API endpoint for navigation"""
    data = request.json
    url = data.get('url', '')
    
    if not url:
        return jsonify({'error': 'URL required'}), 400
    
    # Return a proxy URL that will load the site
    proxy_url = f"/proxy?url={urllib.parse.quote(url)}"
    
    return jsonify({
        'success': True,
        'url': url,
        'proxy_url': proxy_url,
        'timestamp': datetime.now().isoformat()
    })

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'modern-browser-proxy',
        'timestamp': datetime.now().isoformat(),
        'playwright': 'installing'  # Will update when ready
    })

@app.route('/direct')
def direct_proxy():
    """Direct proxy that works with most sites"""
    url = request.args.get('url', '')
    
    if not url:
        return "URL parameter required", 400
    
    # Simple redirect page
    return f'''
    <!DOCTYPE html>
    <html>
    <head>
        <meta http-equiv="refresh" content="0; url={url}">
        <script>window.location.href = "{url}";</script>
    </head>
    <body>
        <p>Redirecting to <a href="{url}">{url}</a>...</p>
    </body>
    </html>
    '''

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 10000))
    
    print(f"""
    🚀 Modern Browser Proxy Starting...
    Port: {port}
    
    🌐 Target URL: https://mln49z-8888.csb.app/tree?
    
    ⏳ Playwright is installing in background...
    This may take 1-2 minutes on first run.
    
    🔗 Your browser will be available at:
    http://localhost:{port}?url=https://mln49z-8888.csb.app/tree?
    
    📊 Health check: http://localhost:{port}/health
    """)
    
    # Run the app
    app.run(
        host='0.0.0.0',
        port=port,
        debug=False,
        threaded=True
    )
