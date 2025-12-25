#!/usr/bin/env python3
"""
Real Browser Session Keeper for CodeSandbox
Uses actual Chrome browser to maintain anonymous icon
"""

import os
import time
import threading
from datetime import datetime
from flask import Flask, jsonify, render_template
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service

app = Flask(__name__)

# Browser session variables
browser_thread = None
browser_active = False
session_start_time = datetime.now()
last_activity_time = datetime.now()

def start_browser_session():
    """Start a real browser session in background"""
    global browser_active, last_activity_time
    
    try:
        print("🚀 Starting Chrome browser for CodeSandbox...")
        
        # Chrome options for headless browser
        chrome_options = Options()
        chrome_options.add_argument("--headless")  # Run in background
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        chrome_options.add_argument("--disable-gpu")
        chrome_options.add_argument("--window-size=1920,1080")
        chrome_options.add_argument("--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        
        # Start Chrome
        service = Service('/usr/local/bin/chromedriver')
        driver = webdriver.Chrome(service=service, options=chrome_options)
        
        browser_active = True
        print("✅ Chrome browser started successfully")
        
        # Navigate to CodeSandbox
        target_url = "https://codesandbox.io/p/devbox/vps-skt7xt"
        print(f"🌐 Navigating to: {target_url}")
        driver.get(target_url)
        
        # Wait for page to load
        time.sleep(10)
        print("✅ CodeSandbox loaded in Chrome browser")
        
        # Keep the session alive
        while browser_active:
            try:
                # Refresh page every 2 minutes to maintain session
                current_time = datetime.now().strftime("%H:%M:%S")
                print(f"[{current_time}] 🔄 Refreshing browser to maintain session...")
                
                # Refresh the page
                driver.refresh()
                last_activity_time = datetime.now()
                
                # Wait 2 minutes before next refresh
                time.sleep(120)
                
            except Exception as e:
                print(f"⚠️ Browser error: {e}")
                # Try to restart if there's an error
                try:
                    driver.quit()
                except:
                    pass
                
                # Wait and try to restart
                time.sleep(30)
                if browser_active:
                    print("🔄 Attempting to restart browser...")
                    try:
                        driver = webdriver.Chrome(service=service, options=chrome_options)
                        driver.get(target_url)
                        time.sleep(10)
                        print("✅ Browser restarted successfully")
                    except Exception as restart_error:
                        print(f"❌ Failed to restart browser: {restart_error}")
        
        # Cleanup
        print("🛑 Stopping browser...")
        driver.quit()
        
    except Exception as e:
        print(f"❌ Failed to start browser: {e}")
        browser_active = False

@app.route('/')
def index():
    """Dashboard"""
    uptime = datetime.now() - session_start_time
    hours, remainder = divmod(int(uptime.total_seconds()), 3600)
    minutes, seconds = divmod(remainder, 60)
    
    return render_template('index.html',
                         hours=hours,
                         minutes=minutes,
                         seconds=seconds,
                         browser_active=browser_active,
                         last_activity=last_activity_time.strftime("%H:%M:%S"))

@app.route('/start')
def start_session():
    """Start the browser session"""
    global browser_thread, browser_active
    
    if not browser_active:
        browser_thread = threading.Thread(target=start_browser_session, daemon=True)
        browser_thread.start()
        time.sleep(5)  # Wait for browser to start
        
        return jsonify({
            'status': 'started',
            'message': 'Chrome browser session started for CodeSandbox',
            'browser_active': browser_active,
            'timestamp': datetime.now().isoformat()
        })
    
    return jsonify({
        'status': 'already_running',
        'message': 'Browser session is already active',
        'browser_active': browser_active,
        'timestamp': datetime.now().isoformat()
    })

@app.route('/stop')
def stop_session():
    """Stop the browser session"""
    global browser_active
    
    if browser_active:
        browser_active = False
        return jsonify({
            'status': 'stopping',
            'message': 'Browser session is being stopped',
            'timestamp': datetime.now().isoformat()
        })
    
    return jsonify({
        'status': 'not_running',
        'message': 'No browser session is running',
        'timestamp': datetime.now().isoformat()
    })

@app.route('/status')
def status():
    """Check session status"""
    uptime = datetime.now() - session_start_time
    
    return jsonify({
        'service': 'codesandbox_browser_session',
        'status': 'active' if browser_active else 'inactive',
        'browser_running': browser_active,
        'session_started': session_start_time.isoformat(),
        'last_activity': last_activity_time.isoformat(),
        'uptime_seconds': int(uptime.total_seconds()),
        'target_url': 'https://codesandbox.io/p/devbox/vps-skt7xt',
        'features': [
            'real_chrome_browser',
            'headless_operation',
            'auto_refresh_120s',
            'cookie_session_persistence',
            '24_7_operation'
        ],
        'note': 'A real Chrome browser is running on Render, maintaining your CodeSandbox session. Close all local tabs - the cloud browser keeps the anonymous icon visible.'
    })

@app.route('/health')
def health():
    """Health check"""
    return jsonify({
        'status': 'healthy',
        'browser_active': browser_active,
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 10000))
    
    print(f"""
    🚀 REAL BROWSER SESSION KEEPER
    Port: {port}
    Started: {session_start_time.strftime("%Y-%m-%d %H:%M:%S")}
    
    🎯 TARGET: https://codesandbox.io/p/devbox/vps-skt7xt
    
    ✅ THIS IS THE REAL SOLUTION:
    1. Uses ACTUAL Chrome browser on Render
    2. Maintains real browser session with cookies
    3. Anonymous icon WILL be visible
    4. Runs 24/7 independently
    5. You can close ALL local browser tabs
    
    🔧 TECHNOLOGY:
    - Selenium WebDriver
    - Chrome browser in Docker
    - Headless mode (no display needed)
    - Auto-refresh every 2 minutes
    
    🌐 ACCESS:
    Dashboard:  http://localhost:{port}/
    Start:      http://localhost:{port}/start
    Status:     http://localhost:{port}/status
    Health:     http://localhost:{port}/health
    
    🚀 Starting browser session automatically...
    """)
    
    # Start browser session automatically
    try:
        browser_thread = threading.Thread(target=start_browser_session, daemon=True)
        browser_thread.start()
    except Exception as e:
        print(f"⚠️ Could not start browser automatically: {e}")
        print("ℹ️ You can start it manually by visiting /start")
    
    app.run(
        host='0.0.0.0',
        port=port,
        debug=False,
        threaded=True
    )
