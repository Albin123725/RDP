#!/usr/bin/env python3
"""
Cloud Browser for CodeSandbox - Simple Version
Maintains session without complex dependencies
"""

import os
from flask import Flask, request, jsonify
from datetime import datetime
import time

app = Flask(__name__)

# Store session info
session_start = datetime.now()

@app.route('/')
def index():
    """Main Cloud Browser Interface"""
    current_time = datetime.now().strftime("%H:%M:%S")
    
    html = '''
    <!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cloud Browser - CodeSandbox Session Keeper</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .container {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 20px;
            padding: 40px;
            max-width: 600px;
            width: 100%;
            text-align: center;
            box-shadow: 0 20px 40px rgba(0,0,0,0.2);
        }
        h1 {
            color: #333;
            margin-bottom: 20px;
            font-size: 2.2em;
        }
        .status {
            background: #10b981;
            color: white;
            padding: 10px 20px;
            border-radius: 50px;
            display: inline-block;
            margin-bottom: 25px;
            font-weight: bold;
        }
        .url-box {
            background: #f8fafc;
            border: 2px solid #e2e8f0;
            border-radius: 10px;
            padding: 20px;
            margin: 20px 0;
        }
        .url {
            font-family: monospace;
            background: white;
            padding: 12px;
            border-radius: 6px;
            margin-top: 10px;
            color: #1e293b;
            word-break: break-all;
        }
        .btn {
            background: #3b82f6;
            color: white;
            border: none;
            padding: 15px 30px;
            border-radius: 10px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            margin: 10px;
            width: 100%;
            transition: all 0.3s;
        }
        .btn:hover {
            background: #2563eb;
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(37, 99, 235, 0.3);
        }
        .btn-secondary {
            background: #f59e0b;
        }
        .btn-secondary:hover {
            background: #d97706;
        }
        .info {
            background: #f0f9ff;
            border-left: 4px solid #3b82f6;
            padding: 15px;
            margin-top: 25px;
            text-align: left;
            border-radius: 0 8px 8px 0;
        }
        .timer {
            position: fixed;
            bottom: 20px;
            right: 20px;
            background: rgba(0,0,0,0.8);
            color: white;
            padding: 10px 20px;
            border-radius: 50px;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>☁️ Cloud Browser</h1>
        <div class="status">✅ ACTIVE - ''' + current_time + '''</div>
        
        <div class="url-box">
            <strong>🎯 Your CodeSandbox:</strong>
            <div class="url">https://codesandbox.io/p/devbox/vps-skt7xt</div>
        </div>
        
        <button class="btn" onclick="openSandbox()">
            🚀 Open CodeSandbox in New Tab
        </button>
        
        <button class="btn btn-secondary" onclick="openAutoRefresh()">
            🔄 Open with Auto-Refresh
        </button>
        
        <div class="info">
            <strong>💡 How to keep anonymous icon:</strong><br>
            1. Click button above<br>
            2. Open CodeSandbox in new tab<br>
            3. Keep THIS tab open<br>
            4. Cloud maintains your session 24/7
        </div>
    </div>
    
    <div class="timer" id="timer">Session: 00:00:00</div>
    
    <script>
        let sessionSeconds = 0;
        
        // Update timer
        setInterval(() => {
            sessionSeconds++;
            const hours = Math.floor(sessionSeconds / 3600).toString().padStart(2, '0');
            const minutes = Math.floor((sessionSeconds % 3600) / 60).toString().padStart(2, '0');
            const seconds = (sessionSeconds % 60).toString().padStart(2, '0');
            document.getElementById('timer').textContent = `Session: ${hours}:${minutes}:${seconds}`;
        }, 1000);
        
        // Open CodeSandbox
        function openSandbox() {
            window.open('https://codesandbox.io/p/devbox/vps-skt7xt', '_blank');
            alert('✅ CodeSandbox opened!\\n\\nKeep THIS Cloud Browser tab open to maintain the anonymous icon.');
        }
        
        // Open auto-refresh version
        function openAutoRefresh() {
            window.open('/auto-refresh', '_blank', 'width=1000,height=700');
        }
        
        // Keep session alive
        setInterval(() => {
            fetch('/ping');
        }, 30000);
    </script>
</body>
</html>
    '''
    return html

@app.route('/auto-refresh')
def auto_refresh():
    """Auto-refreshing version"""
    return '''
    <!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CodeSandbox - Auto Refresh</title>
    <style>
        body, html {
            margin: 0;
            padding: 0;
            height: 100%;
            overflow: hidden;
            font-family: Arial, sans-serif;
        }
        .header {
            background: #2563eb;
            color: white;
            padding: 10px;
            text-align: center;
            font-weight: bold;
        }
        iframe {
            width: 100%;
            height: calc(100vh - 40px);
            border: none;
        }
        .status {
            background: #333;
            color: white;
            padding: 5px 10px;
            font-size: 12px;
            position: fixed;
            bottom: 0;
            right: 0;
            border-radius: 4px 0 0 0;
        }
    </style>
</head>
<body>
    <div class="header">
        🔄 CodeSandbox - Cloud Session (Refreshes every 3 minutes)
    </div>
    <iframe src="https://codesandbox.io/p/devbox/vps-skt7xt"></iframe>
    <div class="status">☁️ Cloud Active</div>
    
    <script>
        // Auto-refresh every 3 minutes (180000 ms)
        setInterval(() => {
            window.location.reload();
        }, 180000);
        
        // Keep alive every 30 seconds
        setInterval(() => {
            // Try to keep session alive
            try {
                window.frames[0].postMessage('keepalive', '*');
            } catch(e) {
                // Ignore
            }
        }, 30000);
    </script>
</body>
</html>
    '''

@app.route('/ping')
def ping():
    """Simple ping endpoint"""
    return jsonify({
        'status': 'alive',
        'time': datetime.now().strftime("%H:%M:%S"),
        'session_start': session_start.strftime("%Y-%m-%d %H:%M:%S")
    })

@app.route('/health')
def health():
    """Health check"""
    return jsonify({
        'status': 'healthy',
        'service': 'cloud-browser',
        'uptime': str(datetime.now() - session_start)
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 10000))
    
    print(f"""
    ☁️  CLOUD BROWSER STARTED
    Port: {port}
    Time: {datetime.now().strftime("%H:%M:%S")}
    
    🎯 Target: https://codesandbox.io/p/devbox/vps-skt7xt
    
    ✅ How to use:
    1. Open this URL in browser
    2. Click "Open CodeSandbox in New Tab"
    3. Keep BOTH tabs open
    4. Anonymous icon will stay visible
    
    🔗 Access URLs:
    Main:     http://localhost:{port}/
    Auto-ref: http://localhost:{port}/auto-refresh
    Health:   http://localhost:{port}/health
    
    ⚡ Running on Render Cloud 24/7
    """)
    
    app.run(
        host='0.0.0.0',
        port=port,
        debug=False,
        threaded=True
    )
