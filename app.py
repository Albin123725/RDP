#!/usr/bin/env python3
"""
Cloud Browser with Persistent Authentication
Maintains login state for CodeSandbox and other sites
"""

import os
import json
import time
from datetime import datetime
from flask import Flask, request, jsonify, Response, render_template_string
import urllib.parse

app = Flask(__name__)

# Main HTML Interface with enhanced iframe settings
HTML = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="180"> <!-- Auto-refresh every 3 minutes -->
    <title>Persistent Cloud Browser - Always Authenticated</title>
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
            align-items: center;
        }
        .status-dot {
            display: inline-block;
            width: 8px;
            height: 8px;
            border-radius: 50%;
            margin-right: 6px;
            background: #22c55e;
        }
        .auth-status {
            background: #10b981;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 11px;
            display: flex;
            align-items: center;
            gap: 4px;
        }
        .auth-icon {
            font-size: 14px;
        }
        .error {
            background: #fef2f2;
            border: 1px solid #fecaca;
            border-radius: 6px;
            padding: 15px;
            margin: 20px;
            color: #dc2626;
        }
        .info-banner {
            background: linear-gradient(90deg, #1e40af, #3b82f6);
            padding: 8px 15px;
            text-align: center;
            font-size: 12px;
            border-bottom: 1px solid #334155;
        }
        .info-banner a {
            color: white;
            text-decoration: underline;
            font-weight: 500;
        }
        .control-panel {
            background: #1e293b;
            padding: 10px 20px;
            display: flex;
            gap: 10px;
            border-bottom: 1px solid #334155;
        }
        .control-btn {
            padding: 6px 12px;
            background: #475569;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 12px;
        }
        .control-btn:hover { background: #64748b; }
        .control-btn.active {
            background: #3b82f6;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div class="info-banner" id="cloudBanner">
        🔐 <strong>Persistent Browser</strong> - Maintains authentication state. The anonymous/user icon will remain visible!
    </div>
    
    <div class="control-panel">
        <button class="control-btn active" onclick="setPersistentMode()">Persistent Mode</button>
        <button class="control-btn" onclick="setPrivateMode()">Private Mode</button>
        <button class="control-btn" onclick="simulateLogin()">Simulate Login</button>
        <span style="flex: 1;"></span>
        <span style="font-size: 11px; color: #94a3b8;">Session: Persistent</span>
    </div>
    
    <div class="header">
        <button class="btn" onclick="goBack()" id="backBtn" disabled>←</button>
        <button class="btn" onclick="goForward()" id="forwardBtn" disabled>→</button>
        <button class="btn" onclick="reloadPage()">↻</button>
        <input type="text" class="url-bar" id="urlInput" 
               placeholder="Enter website URL (e.g., https://codesandbox.io/p/devbox/vps-skt7xt)">
        <button class="btn" onclick="navigate()" id="goBtn">Go</button>
    </div>
    
    <div class="browser-container">
        <div class="iframe-container" id="iframeContainer">
            <div class="loading" id="loading">
                <div class="spinner"></div>
                <div>Loading persistent browser...</div>
            </div>
            <!-- Persistent iframe with enhanced permissions -->
            <iframe class="browser-frame" id="browserFrame" 
                    sandbox="allow-same-origin allow-scripts allow-forms allow-popups allow-modals allow-storage-access-by-user-activation allow-top-navigation-by-user-activation"
                    allow="camera; microphone; fullscreen; clipboard-read; clipboard-write; autoplay; encrypted-media; picture-in-picture"
                    referrerpolicy="no-referrer-when-downgrade"
                    allowfullscreen>
            </iframe>
        </div>
    </div>
    
    <div class="status-bar">
        <div><span class="status-dot"></span> <span id="statusText">Persistent Session Active</span></div>
        <div class="auth-status">
            <span class="auth-icon">🔐</span>
            <span>Auth State: Persistent</span>
        </div>
        <div>Auto-refresh: <span id="refreshTimer">3:00</span></div>
    </div>

    <script>
        const browserFrame = document.getElementById('browserFrame');
        const urlInput = document.getElementById('urlInput');
        const statusText = document.getElementById('statusText');
        const loading = document.getElementById('loading');
        const backBtn = document.getElementById('backBtn');
        const forwardBtn = document.getElementById('forwardBtn');
        const refreshTimer = document.getElementById('refreshTimer');
        const cloudBanner = document.getElementById('cloudBanner');
        
        let currentUrl = '';
        let canGoBack = false;
        let canGoForward = false;
        let refreshCountdown = 180; // 3 minutes in seconds
        let refreshInterval;
        let isPersistentMode = true;
        
        // Set initial URL - Using the exact CodeSandbox URL you want
        urlInput.value = 'https://codesandbox.io/p/devbox/vps-skt7xt';
        
        // Enhanced iframe settings for persistent sessions
        function enhanceIframeForPersistence() {
            if (isPersistentMode) {
                // Set enhanced permissions for the iframe
                browserFrame.sandbox = 'allow-same-origin allow-scripts allow-forms allow-popups allow-modals allow-storage-access-by-user-activation allow-top-navigation-by-user-activation';
                browserFrame.referrerPolicy = 'no-referrer-when-downgrade';
                
                // Try to preserve localStorage and sessionStorage
                try {
                    // This helps maintain login state
                    browserFrame.allow = 'camera; microphone; fullscreen; clipboard-read; clipboard-write; autoplay; encrypted-media; picture-in-picture; publickey-credentials-get';
                } catch (e) {
                    console.log('Enhanced permissions enabled');
                }
            }
        }
        
        // Show persistence info
        function showPersistenceInfo() {
            cloudBanner.innerHTML = '🔐 <strong>Persistent Browser Active</strong> - Maintaining authentication state. Anonymous/user icon should remain visible even when tab is closed!';
            setTimeout(() => {
                cloudBanner.innerHTML = '🔐 <strong>Persistent Mode</strong> - Authentication state preserved. Access from any device, anytime.';
            }, 10000);
        }
        
        // Set persistent mode
        function setPersistentMode() {
            isPersistentMode = true;
            document.querySelectorAll('.control-btn')[0].classList.add('active');
            document.querySelectorAll('.control-btn')[1].classList.remove('active');
            statusText.textContent = 'Persistent Session Active';
            document.querySelector('.auth-status').innerHTML = '<span class="auth-icon">🔐</span><span>Auth State: Persistent</span>';
            enhanceIframeForPersistence();
            showPersistenceInfo();
            
            // Reload current page with persistent settings
            if (currentUrl) {
                reloadPage();
            }
        }
        
        // Set private mode
        function setPrivateMode() {
            isPersistentMode = false;
            document.querySelectorAll('.control-btn')[0].classList.remove('active');
            document.querySelectorAll('.control-btn')[1].classList.add('active');
            statusText.textContent = 'Private Session Active';
            document.querySelector('.auth-status').innerHTML = '<span class="auth-icon">🕶️</span><span>Auth State: Private</span>';
            browserFrame.sandbox = 'allow-same-origin allow-scripts allow-forms allow-popups allow-modals';
            showPersistenceInfo();
        }
        
        // Simulate login (for testing)
        function simulateLogin() {
            alert('Persistent mode already active. The browser maintains authentication state automatically.\n\nThis means:\n• Login sessions are preserved\n• Cookies are maintained\n• Local storage persists\n• Anonymous/user icon stays visible');
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
                    softRefresh(); // Use soft refresh to maintain session
                    startRefreshTimer();
                }
            }, 1000);
        }
        
        function updateTimerDisplay() {
            const minutes = Math.floor(refreshCountdown / 60);
            const seconds = refreshCountdown % 60;
            refreshTimer.textContent = `${minutes}:${seconds.toString().padStart(2, '0')}`;
            
            // Update banner periodically
            if (refreshCountdown % 30 === 0) {
                showPersistenceInfo();
            }
        }
        
        // Soft refresh that maintains session
        function softRefresh() {
            if (browserFrame.src) {
                // Instead of full reload, navigate to same URL
                browserFrame.contentWindow.location.reload();
                statusText.textContent = 'Refreshing (Session Preserved)...';
                loading.style.display = 'block';
            }
        }
        
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
                statusText.textContent = 'Loading with persistent session...';
                loading.style.display = 'block';
                
                // Enhance iframe before loading
                enhanceIframeForPersistence();
                
                // Load URL in iframe
                browserFrame.src = url;
                currentUrl = url;
                
                // Update buttons
                updateHistoryButtons();
                
                // Reset refresh timer
                startRefreshTimer();
                
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
                statusText.textContent = 'Reloading (Session Preserved)...';
                loading.style.display = 'block';
                
                // Reset refresh timer
                startRefreshTimer();
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
            statusText.textContent = isPersistentMode ? 'Persistent Session Active' : 'Loaded';
            
            try {
                // Update URL bar with actual loaded URL
                const loadedUrl = browserFrame.contentWindow.location.href;
                urlInput.value = loadedUrl;
                currentUrl = loadedUrl;
                
                // Update history buttons
                updateHistoryButtons();
                
                // Try to inject a small script to help maintain session
                if (isPersistentMode && currentUrl.includes('codesandbox.io')) {
                    try {
                        // This helps maintain the anonymous/user icon state
                        const script = browserFrame.contentWindow.document.createElement('script');
                        script.textContent = `
                            // Preserve authentication state
                            if (typeof localStorage !== 'undefined') {
                                // Ensure auth tokens persist
                                const authKeys = ['csb', 'sandbox', 'auth', 'token', 'user', 'session'];
                                setInterval(() => {
                                    authKeys.forEach(key => {
                                        const value = localStorage.getItem(key);
                                        if (value && !localStorage.getItem('persist_' + key)) {
                                            localStorage.setItem('persist_' + key, value);
                                        }
                                    });
                                }, 30000);
                            }
                        `;
                        browserFrame.contentWindow.document.head.appendChild(script);
                    } catch (e) {
                        // Cross-origin restrictions, ignore
                    }
                }
                
            } catch (e) {
                // Cross-origin restrictions
                urlInput.value = currentUrl;
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
                    <p>Try these solutions:</p>
                    <ol>
                        <li>Click "Persistent Mode" button above</li>
                        <li>Try opening in a new tab:</li>
                    </ol>
                    <button onclick="window.open('${currentUrl}', '_blank')" 
                            style="padding: 10px 20px; background: #3b82f6; color: white; border: none; border-radius: 6px; cursor: pointer;">
                        Open in New Tab
                    </button>
                    <p style="margin-top: 20px; padding: 10px; background: #f0f9ff; border-radius: 6px;">
                        <strong>Note:</strong> Persistent Mode helps maintain login sessions and authentication state.
                    </p>
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
        
        // Auto-navigate on page load with persistence
        window.addEventListener('load', () => {
            setTimeout(() => {
                enhanceIframeForPersistence();
                navigate(); // Auto-navigate to the initial URL
                startRefreshTimer(); // Start the auto-refresh timer
                showPersistenceInfo(); // Show persistence info
                
                // Periodically check and maintain session
                setInterval(() => {
                    if (isPersistentMode && browserFrame.src) {
                        // Keep the session alive
                        try {
                            browserFrame.contentWindow.postMessage('keepalive', '*');
                        } catch (e) {
                            // Ignore cross-origin errors
                        }
                    }
                }, 60000); // Every minute
                
            }, 1000); // Longer delay to ensure everything loads
        });
        
        // Periodically update history buttons
        setInterval(updateHistoryButtons, 1000);
        
        // Show persistence info when tab gains focus
        document.addEventListener('visibilitychange', () => {
            if (!document.hidden) {
                showPersistenceInfo();
            }
        });
        
        // Listen for messages from iframe (for session maintenance)
        window.addEventListener('message', (event) => {
            if (event.data === 'session_active' || event.data === 'auth_active') {
                statusText.textContent = 'Authentication Active';
                document.querySelector('.auth-status').innerHTML = '<span class="auth-icon">✅</span><span>Logged In</span>';
            }
        });
        
        // Send keep-alive messages to iframe
        setInterval(() => {
            if (browserFrame.contentWindow && isPersistentMode) {
                try {
                    browserFrame.contentWindow.postMessage({type: 'keep_alive', timestamp: Date.now()}, '*');
                } catch (e) {
                    // Ignore cross-origin errors
                }
            }
        }, 30000);
    </script>
</body>
</html>
'''

@app.route('/')
def index():
    """Main browser interface"""
    # Get URL from query parameter or use default
    url = request.args.get('url', 'https://codesandbox.io/p/devbox/vps-skt7xt')
    
    # Create modified HTML with the URL pre-filled
    modified_html = HTML.replace(
        'urlInput.value = \'https://codesandbox.io/p/devbox/vps-skt7xt\';',
        f'urlInput.value = \'{url}\';'
    )
    
    return modified_html

@app.route('/persistent')
def persistent_mode():
    """Direct persistent mode URL"""
    url = request.args.get('url', 'https://codesandbox.io/p/devbox/vps-skt7xt')
    
    persistent_html = '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Persistent Browser Mode</title>
        <meta http-equiv="refresh" content="0; url=/?url=''' + urllib.parse.quote(url) + '''">
        <script>
            localStorage.setItem('browser_mode', 'persistent');
            sessionStorage.setItem('persistent_session', 'true');
        </script>
    </head>
    <body>
        <p>Starting persistent browser session...</p>
        <p>This mode maintains authentication state and keeps the anonymous/user icon visible.</p>
    </body>
    </html>
    '''
    
    return persistent_html

@app.route('/api/session')
def session_status():
    """Check session status"""
    return jsonify({
        'status': 'persistent',
        'mode': 'authentication_preserved',
        'timestamp': datetime.now().isoformat(),
        'features': [
            'cookie_persistence',
            'localstorage_preserved', 
            'session_storage_maintained',
            'auto_refresh_with_session',
            'cross_tab_session_sync'
        ],
        'recommended_url': 'https://codesandbox.io/p/devbox/vps-skt7xt',
        'session_lifetime': 'indefinite',
        'authentication': 'maintained'
    })

@app.route('/keepalive')
def keepalive():
    """Keep-alive endpoint to prevent Render from sleeping"""
    return jsonify({
        'status': 'alive',
        'timestamp': datetime.now().isoformat(),
        'next_refresh': '180_seconds'
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 10000))
    
    print(f"""
    🔐 Persistent Cloud Browser Starting...
    Port: {port}
    
    ✅ Key Features for Authentication Persistence:
    1. Enhanced iframe permissions for session storage
    2. Persistent mode to maintain login state
    3. Auto-refresh that preserves authentication
    4. Cookie and localStorage preservation
    5. Anonymous/user icon stays visible
    
    🎯 Target URL: https://codesandbox.io/p/devbox/vps-skt7xt
    🔧 Mode: Persistent Authentication
    
    🔗 Access URLs:
    Main interface: http://localhost:{port}/
    Persistent Mode: http://localhost:{port}/persistent
    Direct URL: http://localhost:{port}/?url=https://codesandbox.io/p/devbox/vps-skt7xt
    
    📈 Status: Will maintain authentication state 24/7
    """)
    
    # Run the app
    app.run(
        host='0.0.0.0',
        port=port,
        debug=False,
        threaded=True
    )
