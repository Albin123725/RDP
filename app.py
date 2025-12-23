#!/usr/bin/env python3
"""
Lightweight Browser for Modern Web Apps
Works with Render Free Tier - No Playwright needed
"""

import os
import json
import time
from datetime import datetime
from flask import Flask, request, jsonify, Response, render_template_string
import urllib.parse

app = Flask(__name__)

# Main HTML Interface
HTML = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Lightweight Web Browser</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #0f172a;
            color: white;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }
        .header {
            background: #1e293b;
            padding: 15px 20px;
            display: flex;
            gap: 10px;
            align-items: center;
            border-bottom: 1px solid #334155;
        }
        .url-bar {
            flex: 1;
            padding: 10px 15px;
            background: #0f172a;
            border: 1px solid #475569;
            border-radius: 6px;
            color: white;
            font-size: 14px;
        }
        .btn {
            padding: 10px 20px;
            background: #3b82f6;
            color: white;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-weight: 500;
        }
        .btn:hover { background: #2563eb; }
        .browser-container {
            flex: 1;
            display: flex;
            flex-direction: column;
        }
        .iframe-container {
            flex: 1;
            position: relative;
            background: white;
        }
        .browser-frame {
            width: 100%;
            height: 100%;
            border: none;
        }
        .loading {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            color: #64748b;
            text-align: center;
        }
        .spinner {
            border: 3px solid #f3f3f3;
            border-top: 3px solid #3b82f6;
            border-radius: 50%;
            width: 30px;
            height: 30px;
            animation: spin 1s linear infinite;
            margin: 0 auto 10px;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .status-bar {
            background: #1e293b;
            padding: 8px 15px;
            border-top: 1px solid #334155;
            font-size: 12px;
            color: #94a3b8;
            display: flex;
            justify-content: space-between;
        }
        .status-dot {
            display: inline-block;
            width: 8px;
            height: 8px;
            border-radius: 50%;
            margin-right: 6px;
            background: #22c55e;
        }
        .error {
            background: #fef2f2;
            border: 1px solid #fecaca;
            border-radius: 6px;
            padding: 15px;
            margin: 20px;
            color: #dc2626;
        }
    </style>
</head>
<body>
    <div class="header">
        <button class="btn" onclick="goBack()" id="backBtn" disabled>←</button>
        <button class="btn" onclick="goForward()" id="forwardBtn" disabled>→</button>
        <button class="btn" onclick="reloadPage()">↻</button>
        <input type="text" class="url-bar" id="urlInput" 
               placeholder="Enter website URL (e.g., https://mln49z-8888.csb.app/tree?)">
        <button class="btn" onclick="navigate()" id="goBtn">Go</button>
    </div>
    
    <div class="browser-container">
        <div class="iframe-container" id="iframeContainer">
            <div class="loading" id="loading">
                <div class="spinner"></div>
                <div>Loading browser...</div>
            </div>
            <iframe class="browser-frame" id="browserFrame" 
                    sandbox="allow-same-origin allow-scripts allow-forms allow-popups allow-modals"
                    allow="camera; microphone; fullscreen; clipboard-read; clipboard-write">
            </iframe>
        </div>
    </div>
    
    <div class="status-bar">
        <div><span class="status-dot"></span> <span id="statusText">Ready</span></div>
        <div>Browser: <span id="browserInfo">Lightweight</span></div>
    </div>

    <script>
        const browserFrame = document.getElementById('browserFrame');
        const urlInput = document.getElementById('urlInput');
        const statusText = document.getElementById('statusText');
        const loading = document.getElementById('loading');
        const backBtn = document.getElementById('backBtn');
        const forwardBtn = document.getElementById('forwardBtn');
        const browserInfo = document.getElementById('browserInfo');
        
        let currentUrl = '';
        let canGoBack = false;
        let canGoForward = false;
        
        // Set initial URL
        urlInput.value = 'https://mln49z-8888.csb.app/tree?';
        
        // Resize iframe to fit container
        function resizeIframe() {
            const container = document.getElementById('iframeContainer');
            browserFrame.style.height = container.clientHeight + 'px';
            browserFrame.style.width = '100%';
        }
        
        window.addEventListener('resize', resizeIframe);
        setTimeout(resizeIframe, 100);
        
        // Navigation functions
        function navigate() {
            let url = urlInput.value.trim();
            
            if (!url) {
                alert('Please enter a URL');
                return;
            }
            
            // Add protocol if missing
            if (!url.startsWith('http://') && !url.startsWith('https://')) {
                url = 'https://' + url;
            }
            
            try {
                // Validate URL
                new URL(url);
                
                // Update status
                statusText.textContent = 'Loading...';
                loading.style.display = 'block';
                
                // Load URL in iframe
                browserFrame.src = url;
                currentUrl = url;
                
                // Update buttons
                updateHistoryButtons();
                
            } catch (error) {
                alert('Invalid URL: ' + error.message);
            }
        }
        
        function goBack() {
            if (canGoBack) {
                browserFrame.contentWindow.history.back();
            }
        }
        
        function goForward() {
            if (canGoForward) {
                browserFrame.contentWindow.history.forward();
            }
        }
        
        function reloadPage() {
            if (browserFrame.src) {
                browserFrame.src = browserFrame.src;
                statusText.textContent = 'Reloading...';
                loading.style.display = 'block';
            }
        }
        
        function updateHistoryButtons() {
            try {
                if (browserFrame.contentWindow) {
                    canGoBack = browserFrame.contentWindow.history.length > 1;
                    canGoForward = false; // Can't detect forward state easily
                    
                    backBtn.disabled = !canGoBack;
                    forwardBtn.disabled = !canGoForward;
                }
            } catch (e) {
                // Cross-origin error
                backBtn.disabled = true;
                forwardBtn.disabled = true;
            }
        }
        
        // Iframe event listeners
        browserFrame.addEventListener('load', () => {
            loading.style.display = 'none';
            statusText.textContent = 'Loaded';
            
            try {
                // Update URL bar with actual loaded URL
                const loadedUrl = browserFrame.contentWindow.location.href;
                urlInput.value = loadedUrl;
                currentUrl = loadedUrl;
                
                // Get page info
                const title = browserFrame.contentWindow.document.title;
                browserInfo.textContent = title || 'Web Page';
                
                // Update history buttons
                updateHistoryButtons();
                
            } catch (e) {
                // Cross-origin restrictions
                urlInput.value = currentUrl;
                browserInfo.textContent = 'Web Page (Restricted)';
            }
        });
        
        browserFrame.addEventListener('error', () => {
            loading.style.display = 'none';
            statusText.textContent = 'Error loading page';
            
            // Show error in iframe
            const errorHtml = `
                <html>
                <body style="padding: 40px; font-family: Arial, sans-serif;">
                    <h2>⚠️ Unable to Load Page</h2>
                    <p>There was an error loading: <strong>${currentUrl}</strong></p>
                    <p>Possible reasons:</p>
                    <ul>
                        <li>The website blocked the iframe</li>
                        <li>SSL/TLS certificate issue</li>
                        <li>Network connectivity problem</li>
                    </ul>
                    <p>Try opening in a new tab:</p>
                    <button onclick="window.open('${currentUrl}', '_blank')" 
                            style="padding: 10px 20px; background: #3b82f6; color: white; border: none; border-radius: 6px; cursor: pointer;">
                        Open in New Tab
                    </button>
                </body>
                </html>
            `;
            
            browserFrame.srcdoc = errorHtml;
        });
        
        // Handle Enter key in URL bar
        urlInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                navigate();
            }
        });
        
        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            // Ctrl+L or Cmd+L to focus URL bar
            if ((e.ctrlKey || e.metaKey) && e.key === 'l') {
                e.preventDefault();
                urlInput.focus();
                urlInput.select();
            }
            
            // F5 to refresh
            if (e.key === 'F5') {
                e.preventDefault();
                reloadPage();
            }
            
            // Alt+Left/Right for navigation
            if (e.altKey) {
                if (e.key === 'ArrowLeft') {
                    goBack();
                } else if (e.key === 'ArrowRight') {
                    goForward();
                }
            }
        });
        
        // Auto-navigate on page load
        window.addEventListener('load', () => {
            setTimeout(() => {
                navigate(); // Auto-navigate to the initial URL
            }, 500);
        });
        
        // Periodically update history buttons
        setInterval(updateHistoryButtons, 1000);
    </script>
</body>
</html>
'''

@app.route('/')
def index():
    """Main browser interface"""
    # Get URL from query parameter or use default
    url = request.args.get('url', 'https://mln49z-8888.csb.app/tree?')
    
    # Create modified HTML with the URL pre-filled
    modified_html = HTML.replace(
        'urlInput.value = \'https://mln49z-8888.csb.app/tree?\';',
        f'urlInput.value = \'{url}\';'
    )
    
    return modified_html

@app.route('/proxy')
def proxy():
    """Simple proxy endpoint for loading pages"""
    url = request.args.get('url', '')
    
    if not url:
        return '''
        <html>
        <body style="padding: 40px; font-family: Arial, sans-serif;">
            <h2>No URL Provided</h2>
            <p>Please provide a URL parameter: /proxy?url=https://example.com</p>
        </body>
        </html>
        '''
    
    # Create a simple page that redirects to the URL
    return f'''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Redirecting to {url}</title>
        <meta http-equiv="refresh" content="0; url={url}">
        <script>
            window.location.href = "{url}";
        </script>
    </head>
    <body>
        <p>Redirecting to <a href="{url}">{url}</a>...</p>
        <p>If you are not redirected automatically, click the link above.</p>
    </body>
    </html>
    '''

@app.route('/api/info')
def api_info():
    """API endpoint to get browser information"""
    return jsonify({
        'service': 'lightweight-browser',
        'version': '1.0',
        'status': 'running',
        'timestamp': datetime.now().isoformat(),
        'features': ['iframe-browsing', 'url-navigation', 'keyboard-shortcuts'],
        'memory_usage': 'low',
        'compatible_with': ['Render Free Tier', 'Python 3.7+'],
        'default_url': 'https://mln49z-8888.csb.app/tree?'
    })

@app.route('/open')
def open_url():
    """Open a specific URL in the browser"""
    url = request.args.get('url', '')
    
    if not url:
        return index()  # Return main interface
    
    # Redirect to main page with the URL
    return f'''
    <!DOCTYPE html>
    <html>
    <head>
        <meta http-equiv="refresh" content="0; url=/?url={urllib.parse.quote(url)}">
    </head>
    <body>
        <p>Opening {url}...</p>
    </body>
    </html>
    '''

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'lightweight-browser',
        'timestamp': datetime.now().isoformat(),
        'uptime': 'running'
    })

@app.route('/direct/<path:url>')
def direct_url(url):
    """Direct URL access"""
    if not url.startswith(('http://', 'https://')):
        url = 'https://' + url
    
    return f'''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Direct Browser Access</title>
        <style>
            body {{ margin: 0; padding: 20px; font-family: Arial, sans-serif; }}
            iframe {{ width: 100%; height: 90vh; border: none; }}
        </style>
    </head>
    <body>
        <h3>Browsing: {url}</h3>
        <iframe src="{url}" sandbox="allow-same-origin allow-scripts allow-forms allow-popups"></iframe>
    </body>
    </html>
    '''

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 10000))
    
    print(f"""
    🌐 Lightweight Browser Starting...
    Port: {port}
    
    ✅ Features:
    - Real browser using iframe
    - Works with JavaScript sites
    - No heavy dependencies
    - Perfect for Render Free Tier
    
    🔗 Access URLs:
    Main interface: http://localhost:{port}/
    Your URL: http://localhost:{port}/?url=https://mln49z-8888.csb.app/tree?
    Direct: http://localhost:{port}/direct/https://mln49z-8888.csb.app/tree?
    
    ⚡ Memory: ~50MB (Very lightweight)
    """)
    
    # Run the app
    app.run(
        host='0.0.0.0',
        port=port,
        debug=False,
        threaded=True
    )
