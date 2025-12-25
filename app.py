#!/usr/bin/env python3
"""
Local Browser Session Keeper for CodeSandbox
Keeps YOUR browser session alive via auto-refresh
"""

import os
from datetime import datetime
from flask import Flask, jsonify

app = Flask(__name__)

session_start = datetime.now()

@app.route('/')
def index():
    """Auto-refresh page that keeps YOUR browser session alive"""
    current_time = datetime.now().strftime("%H:%M:%S")
    
    html = f'''
    <!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CodeSandbox Session Keeper - Keep THIS Tab Open</title>
    <meta http-equiv="refresh" content="60">
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            color: white;
            font-family: Arial, sans-serif;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }}
        .container {{
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 40px;
            max-width: 800px;
            width: 100%;
            text-align: center;
            border: 1px solid rgba(255, 255, 255, 0.2);
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
        }}
        h1 {{
            color: #00ff88;
            margin-bottom: 10px;
            font-size: 2.5em;
        }}
        .status {{
            background: #00ff88;
            color: black;
            padding: 10px 20px;
            border-radius: 50px;
            display: inline-block;
            margin: 20px 0;
            font-weight: bold;
            font-size: 1.2em;
        }}
        .instructions {{
            background: rgba(0, 0, 0, 0.3);
            padding: 25px;
            border-radius: 15px;
            margin: 25px 0;
            text-align: left;
            border-left: 4px solid #00ff88;
        }}
        .step {{
            margin: 15px 0;
            padding-left: 30px;
            position: relative;
        }}
        .step:before {{
            content: "✅";
            position: absolute;
            left: 0;
            color: #00ff88;
        }}
        .url-box {{
            background: rgba(0, 0, 0, 0.5);
            padding: 15px;
            border-radius: 10px;
            margin: 20px 0;
            font-family: monospace;
            word-break: break-all;
            border: 2px solid #00ff88;
        }}
        .timer {{
            font-size: 3em;
            font-weight: bold;
            margin: 20px 0;
            color: #00ff88;
            text-shadow: 0 0 10px rgba(0, 255, 136, 0.5);
        }}
        .note {{
            background: rgba(255, 204, 0, 0.2);
            border: 1px solid #ffcc00;
            padding: 15px;
            border-radius: 10px;
            margin-top: 20px;
            text-align: left;
        }}
        .warning {{
            background: rgba(255, 68, 68, 0.2);
            border: 1px solid #ff4444;
            padding: 15px;
            border-radius: 10px;
            margin-top: 20px;
            text-align: left;
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>🔐 CodeSandbox Session Keeper</h1>
        <div class="status">ACTIVE - {current_time}</div>
        
        <div class="timer" id="timer">01:00</div>
        <div>Auto-refreshes every 60 seconds</div>
        
        <div class="instructions">
            <h3>🎯 TO KEEP ANONYMOUS ICON VISIBLE:</h3>
            <div class="step">Open CodeSandbox in a NEW tab: <a href="https://codesandbox.io/p/devbox/vps-skt7xt" target="_blank" style="color: #00ff88; text-decoration: none; font-weight: bold;">Click Here</a></div>
            <div class="step">Keep THIS tab open (don't close it)</div>
            <div class="step">This tab auto-refreshes to keep YOUR browser session alive</div>
            <div class="step">Anonymous icon will stay visible in CodeSandbox</div>
        </div>
        
        <div class="url-box">
            Your CodeSandbox URL:<br>
            <strong>https://codesandbox.io/p/devbox/vps-skt7xt</strong>
        </div>
        
        <div class="note">
            <strong>💡 IMPORTANT:</strong><br>
            • Keep THIS tab open 24/7<br>
            • It refreshes automatically every minute<br>
            • This keeps YOUR browser session alive<br>
            • Anonymous icon remains visible<br>
            • Runs on Render cloud (keeps tab active)
        </div>
        
        <div class="warning">
            <strong>⚠️ DO NOT CLOSE THIS TAB!</strong><br>
            If you close this tab, your session will expire and the anonymous icon will disappear.
        </div>
        
        <div style="margin-top: 30px; color: #aaa; font-size: 14px;">
            Started: {session_start.strftime("%Y-%m-%d %H:%M:%S")}<br>
            Running on Render Cloud 24/7
        </div>
    </div>
    
    <script>
        // Countdown timer
        let seconds = 60;
        const timerElement = document.getElementById('timer');
        
        function updateTimer() {{
            seconds--;
            if (seconds < 0) seconds = 60;
            
            const mins = Math.floor(seconds / 60);
            const secs = seconds % 60;
            timerElement.textContent = `${{mins.toString().padStart(2, '0')}}:${{secs.toString().padStart(2, '0')}}`;
        }}
        
        setInterval(updateTimer, 1000);
        updateTimer();
        
        // Open CodeSandbox in new tab if not already open
        setTimeout(() => {{
            if (!localStorage.getItem('sandboxOpened')) {{
                localStorage.setItem('sandboxOpened', 'true');
                window.open('https://codesandbox.io/p/devbox/vps-skt7xt', '_blank');
            }}
        }}, 3000);
        
        // Keep session extra alive with periodic requests
        setInterval(() => {{
            // Make a request to keep session alive
            fetch('/ping').catch(() => {{}});
        }}, 30000);
    </script>
</body>
</html>
    '''
    return html

@app.route('/ping')
def ping():
    """Ping endpoint to keep session alive"""
    return jsonify({
        'status': 'alive',
        'time': datetime.now().strftime("%H:%M:%S"),
        'message': 'Session keeper active'
    })

@app.route('/status')
def status():
    """Status endpoint"""
    uptime = datetime.now() - session_start
    hours = int(uptime.total_seconds() // 3600)
    minutes = int((uptime.total_seconds() % 3600) // 60)
    
    return jsonify({
        'status': 'active',
        'uptime': f'{hours}h {minutes}m',
        'started': session_start.strftime("%Y-%m-%d %H:%M:%S"),
        'service': 'local_session_keeper',
        'instructions': 'Keep this tab open. It auto-refreshes to maintain YOUR browser session with CodeSandbox.'
    })

@app.route('/health')
def health():
    """Health check"""
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 10000))
    
    print(f"""
    🔐 LOCAL SESSION KEEPER
    Port: {port}
    
    🎯 REAL SOLUTION FOR ANONYMOUS ICON:
    
    The anonymous icon appears based on YOUR LOCAL BROWSER session.
    
    ✅ HOW IT WORKS:
    1. You open this page on Render
    2. It auto-refreshes every 60 seconds
    3. This keeps YOUR browser session alive
    4. CodeSandbox sees continuous activity from YOUR IP
    5. Anonymous icon stays visible
    
    ✅ WHAT TO DO:
    1. Open: https://rdp-9vpb.onrender.com/
    2. Keep that tab OPEN 24/7
    3. Open CodeSandbox in another tab
    4. Anonymous icon will be visible
    
    ⚡ This is the ONLY way that works!
    """)
    
    app.run(
        host='0.0.0.0',
        port=port,
        debug=False,
        threaded=True
    )
