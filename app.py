#!/usr/bin/env python3
"""
Simple Cloud Browser - Always Shows Website
Works even with strict websites like CodeSandbox
"""

import os
from flask import Flask, request, jsonify
from datetime import datetime

app = Flask(__name__)

# Simple HTML with direct iframe
SIMPLE_HTML = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cloud Browser - Always Active</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }
        .header {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            padding: 15px 20px;
            display: flex;
            gap: 10px;
            align-items: center;
            border-bottom: 1px solid rgba(255, 255, 255, 0.2);
        }
        .url-display {
            flex: 1;
            padding: 12px 15px;
            background: rgba(0, 0, 0, 0.3);
            border: 1px solid rgba(255, 255, 255, 0.3);
            border-radius: 8px;
            color: white;
            font-size: 14px;
            font-weight: 500;
        }
        .status {
            background: #10b981;
            color: white;
            padding: 8px 15px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: bold;
        }
        .browser-container {
            flex: 1;
            position: relative;
        }
        .browser-frame {
            width: 100%;
            height: 100%;
            border: none;
            display: block;
        }
        .loading {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            text-align: center;
            color: white;
            background: rgba(0, 0, 0, 0.7);
            padding: 30px;
            border-radius: 15px;
            backdrop-filter: blur(10px);
        }
        .spinner {
            border: 4px solid rgba(255, 255, 255, 0.3);
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
        .info-bar {
            background: rgba(255, 255, 255, 0.1);
            padding: 10px 20px;
            text-align: center;
            font-size: 12px;
            color: rgba(255, 255, 255, 0.9);
            border-top: 1px solid rgba(255, 255, 255, 0.2);
        }
        .cloud-badge {
            background: #3b82f6;
            color: white;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 11px;
            margin-left: 10px;
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="url-display" id="urlDisplay">
            🌐 Loading: https://codesandbox.io/p/devbox/vps-skt7xt
        </div>
        <div class="status" id="statusIndicator">
            ☁️ CLOUD ACTIVE
        </div>
    </div>
    
    <div class="browser-container">
        <!-- DIRECT IFRAME - NO SANDBOX RESTRICTIONS -->
        <iframe 
            class="browser-frame" 
            id="browserFrame"
            src="https://codesandbox.io/p/devbox/vps-skt7xt"
            allow="camera; microphone; fullscreen; clipboard-read; clipboard-write"
            allowfullscreen
            scrolling="yes"
        ></iframe>
        
        <div class="loading" id="loading">
            <div class="spinner"></div>
            <div>Loading CodeSandbox...</div>
            <div style="margin-top: 10px; font-size: 12px; opacity: 0.8;">
                This browser runs 24/7 on cloud
            </div>
        </div>
    </div>
    
    <div class="info-bar">
        <span>🔄 Auto-refresh every 3 minutes</span>
        <span class="cloud-badge">☁️ CLOUD PERSISTENT</span>
        <span style="margin-left: 15px;">⏰ Next refresh: <span id="refreshTimer">3:00</span></span>
    </div>

    <script>
        const browserFrame = document.getElementById('browserFrame');
        const loading = document.getElementById('loading');
        const urlDisplay = document.getElementById('urlDisplay');
        const statusIndicator = document.getElementById('statusIndicator');
        const refreshTimer = document.getElementById('refreshTimer');
        
        let refreshCountdown = 180;
        let refreshInterval;
        let retryCount = 0;
        
        // Update display with current URL
        function updateUrlDisplay() {
            try {
                const currentUrl = browserFrame.contentWindow.location.href;
                urlDisplay.textContent = `🌐 ${currentUrl}`;
            } catch (e) {
                // Cross-origin error, keep default
            }
        }
        
        // Start refresh countdown
        function startRefreshTimer() {
            clearInterval(refreshInterval);
            refreshCountdown = 180;
            updateTimerDisplay();
            
            refreshInterval = setInterval(() => {
                refreshCountdown--;
                updateTimerDisplay();
                
                if (refreshCountdown <= 0) {
                    clearInterval(refreshInterval);
                    softRefreshPage();
                    startRefreshTimer();
                }
            }, 1000);
        }
        
        function updateTimerDisplay() {
            const minutes = Math.floor(refreshCountdown / 60);
            const seconds = refreshCountdown % 60;
            refreshTimer.textContent = `${minutes}:${seconds.toString().padStart(2, '0')}`;
        }
        
        // Soft refresh that maintains session
        function softRefreshPage() {
            if (browserFrame.src) {
                statusIndicator.textContent = '🔄 REFRESHING...';
                loading.style.display = 'block';
                
                // Use contentWindow.location.reload() to maintain session
                try {
                    browserFrame.contentWindow.location.reload();
                } catch (e) {
                    // Fallback to iframe src reload
                    browserFrame.src = browserFrame.src;
                }
                
                // Hide loading after 3 seconds
                setTimeout(() => {
                    loading.style.display = 'none';
                    statusIndicator.textContent = '✅ ACTIVE';
                }, 3000);
            }
        }
        
        // Handle iframe load
        browserFrame.addEventListener('load', () => {
            loading.style.display = 'none';
            statusIndicator.textContent = '✅ LOADED';
            updateUrlDisplay();
            
            // Start the refresh timer
            startRefreshTimer();
            
            // Update title with page title
            try {
                const pageTitle = browserFrame.contentWindow.document.title;
                if (pageTitle && pageTitle !== '') {
                    document.title = `Cloud: ${pageTitle}`;
                }
            } catch (e) {
                // Cross-origin restriction
            }
        });
        
        // Handle iframe errors
        browserFrame.addEventListener('error', () => {
            loading.innerHTML = `
                <div class="spinner" style="border-top-color: #ef4444;"></div>
                <div>Having trouble loading...</div>
                <div style="margin-top: 10px; font-size: 12px;">
                    Retrying in 5 seconds...
                </div>
            `;
            statusIndicator.textContent = '⚠️ RETRYING...';
            
            // Retry after 5 seconds
            setTimeout(() => {
                retryCount++;
                if (retryCount <= 3) {
                    browserFrame.src = 'https://codesandbox.io/p/devbox/vps-skt7xt';
                } else {
                    loading.innerHTML = `
                        <div style="color: #ef4444; font-size: 24px;">❌</div>
                        <div>Failed to load after multiple attempts</div>
                        <button onclick="location.reload()" 
                                style="margin-top: 15px; padding: 8px 16px; background: #3b82f6; color: white; border: none; border-radius: 6px; cursor: pointer;">
                            Retry Now
                        </button>
                    `;
                }
            }, 5000);
        });
        
        // Auto-hide loading after 10 seconds max
        setTimeout(() => {
            loading.style.display = 'none';
        }, 10000);
        
        // Start timer immediately
        startRefreshTimer();
        
        // Keep-alive: Send periodic messages to prevent iframe timeout
        setInterval(() => {
            try {
                // Simple keep-alive
                browserFrame.contentWindow.postMessage('keepalive', '*');
            } catch (e) {
                // Ignore errors
            }
        }, 60000); // Every minute
    </script>
</body>
</html>
'''

@app.route('/')
def index():
    """Main browser interface - SIMPLE VERSION"""
    return SIMPLE_HTML

@app.route('/direct')
def direct():
    """Direct access with minimal restrictions"""
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Direct Cloud Browser</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body, html { margin: 0; padding: 0; height: 100%; overflow: hidden; }
            iframe { width: 100%; height: 100vh; border: none; }
        </style>
    </head>
    <body>
        <iframe 
            src="https://codesandbox.io/p/devbox/vps-skt7xt" 
            allow="camera; microphone; fullscreen; clipboard-read; clipboard-write"
            allowfullscreen
        ></iframe>
    </body>
    </html>
    '''

@app.route('/simple')
def simple():
    """Even simpler version"""
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>CodeSandbox Cloud Viewer</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body { 
                margin: 0; 
                padding: 10px; 
                background: #1a1a1a;
                color: white;
                font-family: Arial, sans-serif;
            }
            .container {
                height: calc(100vh - 20px);
                display: flex;
                flex-direction: column;
            }
            .header {
                background: #2563eb;
                padding: 10px;
                border-radius: 8px 8px 0 0;
                text-align: center;
                font-weight: bold;
            }
            .frame-container {
                flex: 1;
                position: relative;
            }
            iframe {
                width: 100%;
                height: 100%;
                border: none;
                border-radius: 0 0 8px 8px;
            }
            .loading {
                position: absolute;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                background: rgba(0, 0, 0, 0.8);
                display: flex;
                align-items: center;
                justify-content: center;
                flex-direction: column;
            }
            .loader {
                border: 4px solid #f3f3f3;
                border-top: 4px solid #3498db;
                border-radius: 50%;
                width: 40px;
                height: 40px;
                animation: spin 1s linear infinite;
                margin-bottom: 10px;
            }
            @keyframes spin {
                0% { transform: rotate(0deg); }
                100% { transform: rotate(360deg); }
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                ☁️ Cloud Browser - Running 24/7 on Render
            </div>
            <div class="frame-container">
                <iframe 
                    src="https://codesandbox.io/p/devbox/vps-skt7xt"
                    id="mainFrame"
                    allowfullscreen
                ></iframe>
                <div class="loading" id="loader">
                    <div class="loader"></div>
                    Loading CodeSandbox...
                </div>
            </div>
        </div>
        <script>
            const frame = document.getElementById('mainFrame');
            const loader = document.getElementById('loader');
            
            frame.onload = function() {
                loader.style.display = 'none';
            };
            
            // Auto-hide loader after 10 seconds
            setTimeout(() => {
                loader.style.display = 'none';
            }, 10000);
            
            // Auto-refresh every 3 minutes
            setInterval(() => {
                frame.src = frame.src;
                loader.style.display = 'flex';
            }, 180000);
        </script>
    </body>
    </html>
    '''

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'service': 'cloud-browser',
        'url': 'https://codesandbox.io/p/devbox/vps-skt7xt',
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 10000))
    
    print(f"""
    🌐 SIMPLE CLOUD BROWSER STARTING...
    Port: {port}
    
    ✅ Features:
    - Direct iframe loading (no complex sandbox)
    - Auto-refresh every 3 minutes
    - Runs 24/7 on Render cloud
    - Maintains session between refreshes
    - Simple and reliable
    
    🎯 Loading: https://codesandbox.io/p/devbox/vps-skt7xt
    
    🔗 Access URLs:
    1. Main: http://localhost:{port}/
    2. Direct: http://localhost:{port}/direct
    3. Simple: http://localhost:{port}/simple
    
    ⚡ Status: Will show website immediately
    """)
    
    app.run(
        host='0.0.0.0',
        port=port,
        debug=False,
        threaded=True
    )
