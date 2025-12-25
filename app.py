#!/usr/bin/env python3
"""
CodeSandbox Session Keeper using Playwright
Simpler and more reliable than Selenium
"""

import os
import time
import threading
import asyncio
from datetime import datetime
from flask import Flask, jsonify, render_template

app = Flask(__name__)

# Session variables
session_active = False
session_start_time = datetime.now()
last_refresh_time = datetime.now()

async def keep_session_alive():
    """Use Playwright to maintain a real browser session"""
    global session_active, last_refresh_time
    
    try:
        # Import Playwright
        from playwright.async_api import async_playwright
        
        print("🚀 Starting Playwright browser session...")
        
        async with async_playwright() as p:
            # Launch browser
            browser = await p.chromium.launch(
                headless=True,
                args=['--no-sandbox', '--disable-dev-shm-usage']
            )
            
            # Create context with persistent storage
            context = await browser.new_context(
                viewport={'width': 1920, 'height': 1080},
                user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            )
            
            # Create page
            page = await context.new_page()
            
            # Navigate to CodeSandbox
            target_url = "https://codesandbox.io/p/devbox/vps-skt7xt"
            print(f"🌐 Navigating to: {target_url}")
            await page.goto(target_url, wait_until='networkidle')
            
            print("✅ CodeSandbox loaded successfully")
            session_active = True
            
            # Keep session alive
            while session_active:
                try:
                    current_time = datetime.now().strftime("%H:%M:%S")
                    print(f"[{current_time}] 🔄 Refreshing to maintain session...")
                    
                    # Refresh the page
                    await page.reload(wait_until='networkidle')
                    last_refresh_time = datetime.now()
                    
                    # Wait 2 minutes before next refresh
                    await asyncio.sleep(120)
                    
                except Exception as e:
                    print(f"⚠️ Page error: {e}")
                    # Try to recover
                    try:
                        await page.goto(target_url, wait_until='networkidle')
                    except:
                        pass
                    await asyncio.sleep(30)
            
            # Cleanup
            print("🛑 Closing browser...")
            await browser.close()
            
    except Exception as e:
        print(f"❌ Playwright error: {e}")
        session_active = False

def run_session_keeper():
    """Run the async session keeper"""
    asyncio.run(keep_session_alive())

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
                         session_active=session_active,
                         last_refresh=last_refresh_time.strftime("%H:%M:%S"))

@app.route('/start')
def start_session():
    """Start the session keeper"""
    global session_active
    
    if not session_active:
        # Start in a separate thread
        thread = threading.Thread(target=run_session_keeper, daemon=True)
        thread.start()
        
        # Wait a moment
        time.sleep(3)
        
        return jsonify({
            'status': 'started',
            'message': 'Playwright browser session started',
            'session_active': session_active,
            'timestamp': datetime.now().isoformat()
        })
    
    return jsonify({
        'status': 'already_running',
        'message': 'Session is already active',
        'session_active': session_active,
        'timestamp': datetime.now().isoformat()
    })

@app.route('/stop')
def stop_session():
    """Stop the session"""
    global session_active
    
    if session_active:
        session_active = False
        return jsonify({
            'status': 'stopping',
            'message': 'Session is being stopped',
            'timestamp': datetime.now().isoformat()
        })
    
    return jsonify({
        'status': 'not_running',
        'message': 'No session is running',
        'timestamp': datetime.now().isoformat()
    })

@app.route('/status')
def status():
    """Check session status"""
    uptime = datetime.now() - session_start_time
    
    return jsonify({
        'service': 'codesandbox_session_keeper',
        'status': 'active' if session_active else 'inactive',
        'session_active': session_active,
        'session_started': session_start_time.isoformat(),
        'last_refresh': last_refresh_time.isoformat(),
        'uptime_seconds': int(uptime.total_seconds()),
        'target_url': 'https://codesandbox.io/p/devbox/vps-skt7xt',
        'technology': 'playwright_chromium',
        'note': 'Real browser session maintained on Render cloud. Close all local tabs - anonymous icon stays visible.'
    })

@app.route('/health')
def health():
    """Health check"""
    return jsonify({
        'status': 'healthy',
        'session_active': session_active,
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 10000))
    
    print(f"""
    🎭 PLAYWRIGHT SESSION KEEPER
    Port: {port}
    Started: {session_start_time.strftime("%Y-%m-%d %H:%M:%S")}
    
    🎯 TARGET: https://codesandbox.io/p/devbox/vps-skt7xt
    
    ✅ SIMPLER SOLUTION:
    1. Uses Playwright (handles Chrome automatically)
    2. Real browser session maintained
    3. Anonymous icon WILL be visible
    4. No complex Docker setup needed
    
    🔧 FEATURES:
    - Playwright auto-installs browsers
    - Real Chromium browser
    - Auto-refresh every 2 minutes
    - Persistent session
    
    🌐 ACCESS:
    Dashboard:  http://localhost:{port}/
    Start:      http://localhost:{port}/start
    Status:     http://localhost:{port}/status
    Health:     http://localhost:{port}/health
    
    🚀 Ready to maintain your CodeSandbox session!
    """)
    
    app.run(
        host='0.0.0.0',
        port=port,
        debug=False,
        threaded=True
    )
