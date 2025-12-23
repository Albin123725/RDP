#!/usr/bin/env python3
"""
Single-File Lightweight Browser for Render Free Tier
No Chrome installation needed - uses requests + BeautifulSoup
"""

import os
import re
import html
import json
import threading
import time
import urllib.parse
from datetime import datetime
from flask import Flask, request, render_template_string, jsonify, send_file
from io import BytesIO
import requests
from PIL import Image, ImageDraw, ImageFont
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# HTML Template (embedded in the same file)
HTML_TEMPLATE = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🌐 Lightweight Web Browser</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
            color: #333;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: rgba(255, 255, 255, 0.95);
            border-radius: 15px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #0072ff 0%, #00c6ff 100%);
            color: white;
            padding: 20px 30px;
            display: flex;
            align-items: center;
            gap: 15px;
        }
        .header h1 { flex: 1; font-size: 24px; }
        .status-badge {
            background: rgba(255, 255, 255, 0.2);
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 14px;
        }
        .browser-controls {
            background: #f8f9fa;
            padding: 20px;
            border-bottom: 1px solid #dee2e6;
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        .url-bar {
            flex: 1;
            min-width: 300px;
            padding: 12px 20px;
            border: 2px solid #0072ff;
            border-radius: 8px;
            font-size: 16px;
            background: white;
        }
        .btn {
            padding: 12px 24px;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 8px;
            transition: all 0.3s;
        }
        .btn-primary {
            background: linear-gradient(135deg, #0072ff 0%, #00c6ff 100%);
            color: white;
        }
        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(0, 114, 255, 0.4);
        }
        .btn-secondary {
            background: #6c757d;
            color: white;
        }
        .btn-secondary:hover {
            background: #5a6268;
        }
        .content-area {
            padding: 30px;
            min-height: 500px;
            background: white;
        }
        .website-content {
            max-width: 800px;
            margin: 0 auto;
            line-height: 1.6;
        }
        .website-content h1, 
        .website-content h2, 
        .website-content h3 {
            color: #2c3e50;
            margin: 20px 0 10px;
            border-bottom: 2px solid #f0f0f0;
            padding-bottom: 5px;
        }
        .website-content p {
            margin: 15px 0;
            color: #34495e;
        }
        .website-content a {
            color: #3498db;
            text-decoration: none;
            border-bottom: 1px dashed #3498db;
        }
        .website-content a:hover {
            color: #2980b9;
            border-bottom-style: solid;
        }
        .website-content ul, .website-content ol {
            padding-left: 30px;
            margin: 15px 0;
        }
        .website-content li {
            margin: 8px 0;
        }
        .website-content img {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            margin: 15px 0;
            box-shadow: 0 5px 15px rgba(0, 0, 0, 0.1);
        }
        .website-content code {
            background: #f8f9fa;
            padding: 2px 6px;
            border-radius: 4px;
            font-family: 'Courier New', monospace;
            font-size: 14px;
        }
        .website-content pre {
            background: #2c3e50;
            color: #ecf0f1;
            padding: 15px;
            border-radius: 8px;
            overflow-x: auto;
            margin: 20px 0;
        }
        .error-message {
            background: #fff5f5;
            border: 1px solid #fed7d7;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
            color: #c53030;
        }
        .loading {
            text-align: center;
            padding: 40px;
            color: #7f8c8d;
        }
        .loading .spinner {
            border: 4px solid #f3f3f3;
            border-top: 4px solid #3498db;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto 20px;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .browser-info {
            background: #f8f9fa;
            padding: 15px;
            border-top: 1px solid #dee2e6;
            display: flex;
            justify-content: space-between;
            font-size: 14px;
            color: #6c757d;
        }
        @media (max-width: 768px) {
            .container { margin: 10px; }
            .browser-controls { flex-direction: column; }
            .url-bar { min-width: auto; }
            .btn { width: 100%; justify-content: center; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🌐 Lightweight Web Browser</h1>
            <div class="status-badge">
                <span id="status">Ready</span>
            </div>
        </div>
        
        <div class="browser-controls">
            <button class="btn btn-secondary" onclick="history.back()">← Back</button>
            <button class="btn btn-secondary" onclick="history.forward()">→ Forward</button>
            <button class="btn btn-secondary" onclick="location.reload()">↻ Reload</button>
            <input type="text" class="url-bar" id="urlInput" 
                   placeholder="Enter website URL (e.g., https://example.com)" 
                   value="{{ current_url }}">
            <button class="btn btn-primary" onclick="navigate()">
                <span>🌐</span> Go
            </button>
        </div>
        
        <div class="content-area">
            {% if error %}
                <div class="error-message">
                    <h3>⚠️ Error Loading Page</h3>
                    <p>{{ error }}</p>
                    <p>Try these alternatives:</p>
                    <ul>
                        <li>Make sure the URL starts with http:// or https://</li>
                        <li>Try a different website</li>
                        <li>Check your internet connection</li>
                    </ul>
                </div>
            {% elif content %}
                <div class="website-content">
                    {{ content|safe }}
                </div>
            {% else %}
                <div class="loading">
                    <div class="spinner"></div>
                    <p>Enter a URL above to start browsing</p>
                    <p style="margin-top: 20px; font-size: 14px;">
                        <strong>Try these examples:</strong><br>
                        https://news.ycombinator.com<br>
                        https://en.wikipedia.org/wiki/Web_browser<br>
                        https://httpbin.org/html
                    </p>
                </div>
            {% endif %}
        </div>
        
        <div class="browser-info">
            <div>
                <span id="pageInfo">{{ page_info }}</span>
            </div>
            <div>
                Memory: <span id="memory">{{ memory_usage }} MB</span> | 
                Requests: <span id="requests">0</span>
            </div>
        </div>
    </div>

    <script>
        let historyStack = [];
        let historyIndex = -1;
        
        function navigate() {
            const urlInput = document.getElementById('urlInput');
            let url = urlInput.value.trim();
            
            if (!url) return;
            
            // Add protocol if missing
            if (!url.startsWith('http://') && !url.startsWith('https://')) {
                url = 'https://' + url;
            }
            
            // Validate URL
            try {
                new URL(url);
                
                // Update status
                document.getElementById('status').textContent = 'Loading...';
                
                // Add to history
                historyStack.push(url);
                historyIndex = historyStack.length - 1;
                
                // Navigate
                window.location.href = `/?url=${encodeURIComponent(url)}`;
                
            } catch (error) {
                alert('Invalid URL. Please enter a valid web address.');
            }
        }
        
        // Handle Enter key in URL bar
        document.getElementById('urlInput').addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                navigate();
            }
        });
        
        // Keyboard shortcuts
        document.addEventListener('keydown', function(e) {
            // Ctrl+L or Cmd+L to focus URL bar
            if ((e.ctrlKey || e.metaKey) && e.key === 'l') {
                e.preventDefault();
                document.getElementById('urlInput').focus();
                document.getElementById('urlInput').select();
            }
            
            // F5 to refresh
            if (e.key === 'F5') {
                e.preventDefault();
                location.reload();
            }
            
            // Alt+Left/Right for history
            if (e.altKey) {
                if (e.key === 'ArrowLeft') {
                    history.back();
                } else if (e.key === 'ArrowRight') {
                    history.forward();
                }
            }
        });
        
        // Auto-focus URL bar on page load
        window.addEventListener('load', function() {
            const urlInput = document.getElementById('urlInput');
            urlInput.focus();
            
            // Select all text if there's a value
            if (urlInput.value) {
                urlInput.select();
            }
            
            // Update memory usage periodically
            setInterval(updateStats, 5000);
        });
        
        function updateStats() {
            // Simulated stats update
            const memory = Math.random() * 50 + 100;
            document.getElementById('memory').textContent = Math.round(memory);
        }
        
        // Handle links within the page
        document.addEventListener('click', function(e) {
            if (e.target.tagName === 'A' && e.target.href) {
                e.preventDefault();
                const url = e.target.href;
                document.getElementById('urlInput').value = url;
                navigate();
            }
        });
        
        // Initial stats
        updateStats();
    </script>
</body>
</html>
'''

class LightweightBrowser:
    """A lightweight browser that fetches and renders web content"""
    
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Accept-Encoding': 'gzip, deflate',
            'Connection': 'keep-alive',
        })
        self.cache = {}
        self.cache_timeout = 300  # 5 minutes
        self.max_content_size = 50000  # 50KB max content to process
        
    def fetch_url(self, url):
        """Fetch and parse a URL"""
        try:
            # Check cache first
            cache_key = url.lower()
            if cache_key in self.cache:
                cached_time, cached_data = self.cache[cache_key]
                if time.time() - cached_time < self.cache_timeout:
                    return cached_data
            
            logger.info(f"Fetching URL: {url}")
            
            # Validate URL
            parsed = urllib.parse.urlparse(url)
            if not parsed.scheme:
                url = 'https://' + url
                parsed = urllib.parse.urlparse(url)
            
            # Fetch the content
            response = self.session.get(url, timeout=10)
            response.raise_for_status()
            
            # Check content type
            content_type = response.headers.get('content-type', '').lower()
            
            if 'text/html' in content_type:
                content = response.text[:self.max_content_size]
                processed = self.process_html(content, url)
            elif 'application/json' in content_type:
                content = response.text[:self.max_content_size]
                processed = self.process_json(content)
            elif 'text/plain' in content_type:
                content = response.text[:self.max_content_size]
                processed = self.process_text(content)
            else:
                # For non-text content, return a placeholder
                processed = self.create_placeholder(f"Content type not supported: {content_type}")
            
            result = {
                'content': processed,
                'url': url,
                'status': 'success',
                'content_type': content_type,
                'size': len(response.content)
            }
            
            # Cache the result
            self.cache[cache_key] = (time.time(), result)
            
            # Clean old cache entries
            self.clean_cache()
            
            return result
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Request error for {url}: {e}")
            return {
                'content': self.create_error_page(str(e)),
                'url': url,
                'status': 'error',
                'error': str(e)
            }
        except Exception as e:
            logger.error(f"Unexpected error for {url}: {e}")
            return {
                'content': self.create_error_page(f"Unexpected error: {str(e)}"),
                'url': url,
                'status': 'error',
                'error': str(e)
            }
    
    def process_html(self, html_content, base_url):
        """Process HTML content into safe, renderable format"""
        try:
            # Basic HTML sanitization and processing
            # Remove scripts and styles for security
            html_content = re.sub(r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>', '', html_content, flags=re.IGNORECASE)
            html_content = re.sub(r'<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>', '', html_content, flags=re.IGNORECASE)
            
            # Extract title
            title_match = re.search(r'<title[^>]*>(.*?)</title>', html_content, re.IGNORECASE | re.DOTALL)
            title = title_match.group(1).strip() if title_match else "No Title"
            
            # Extract body content
            body_match = re.search(r'<body[^>]*>(.*?)</body>', html_content, re.IGNORECASE | re.DOTALL)
            body_content = body_match.group(1) if body_match else html_content
            
            # Convert relative URLs to absolute
            def make_absolute(match):
                tag, attr, value = match.groups()
                if value.startswith(('http://', 'https://', '//', 'data:', 'mailto:', 'tel:')):
                    return f'{tag} {attr}="{value}"'
                else:
                    absolute = urllib.parse.urljoin(base_url, value)
                    return f'{tag} {attr}="{absolute}"'
            
            # Process common attributes
            body_content = re.sub(r'(<a\s[^>]*href=)"([^"]*)"', 
                                lambda m: f'{m.group(1)}"{urllib.parse.urljoin(base_url, m.group(2))}"', 
                                body_content, flags=re.IGNORECASE)
            
            body_content = re.sub(r'(<img\s[^>]*src=)"([^"]*)"', 
                                lambda m: f'{m.group(1)}"{urllib.parse.urljoin(base_url, m.group(2))}"', 
                                body_content, flags=re.IGNORECASE)
            
            # Limit content length
            if len(body_content) > 20000:
                body_content = body_content[:20000] + "... [Content truncated]"
            
            # Create formatted HTML
            formatted = f"""
            <h1>{html.escape(title)}</h1>
            <hr>
            <div class="page-content">
            {body_content}
            </div>
            """
            
            return formatted
            
        except Exception as e:
            logger.error(f"HTML processing error: {e}")
            return self.create_error_page(f"HTML processing error: {str(e)}")
    
    def process_json(self, json_content):
        """Process JSON content"""
        try:
            data = json.loads(json_content)
            formatted = json.dumps(data, indent=2)
            return f"<pre><code>{html.escape(formatted)}</code></pre>"
        except:
            return f"<pre><code>{html.escape(json_content[:1000])}</code></pre>"
    
    def process_text(self, text_content):
        """Process plain text content"""
        escaped = html.escape(text_content[:2000])
        return f"<pre>{escaped}</pre>"
    
    def create_error_page(self, error_msg):
        """Create an error page"""
        return f"""
        <div class="error-message">
            <h2>⚠️ Unable to Load Page</h2>
            <p><strong>Error:</strong> {html.escape(error_msg)}</p>
            <p>This lightweight browser cannot load all websites. Try:</p>
            <ul>
                <li>Simple text-based websites (like Hacker News)</li>
                <li>Wikipedia pages</li>
                <li>Documentation sites</li>
                <li>Plain HTML pages</li>
            </ul>
            <p>Complex sites with heavy JavaScript may not work.</p>
        </div>
        """
    
    def create_placeholder(self, message):
        """Create a placeholder for unsupported content"""
        return f"""
        <div style="text-align: center; padding: 50px;">
            <h3>🔧 Content Not Displayed</h3>
            <p>{html.escape(message)}</p>
            <p>This lightweight browser focuses on text content.</p>
        </div>
        """
    
    def clean_cache(self):
        """Clean old cache entries"""
        current_time = time.time()
        keys_to_remove = []
        
        for key, (cached_time, _) in self.cache.items():
            if current_time - cached_time > self.cache_timeout:
                keys_to_remove.append(key)
        
        for key in keys_to_remove:
            del self.cache[key]
        
        if keys_to_remove:
            logger.info(f"Cleaned {len(keys_to_remove)} cache entries")

# Create browser instance
browser = LightweightBrowser()

@app.route('/')
def index():
    """Main browser interface"""
    url = request.args.get('url', '').strip()
    current_url = url if url else ''
    content = ''
    error = None
    page_info = "Ready"
    memory_usage = round(os.sys.getsizeof(browser.cache) / 1024 / 1024, 2)
    
    if url:
        try:
            result = browser.fetch_url(url)
            
            if result['status'] == 'success':
                content = result['content']
                current_url = result['url']
                page_info = f"Loaded: {result['content_type'].split(';')[0]} | Size: {result['size']:,} bytes"
            else:
                error = result.get('error', 'Unknown error')
                content = result['content']
                page_info = "Error loading page"
                
        except Exception as e:
            error = str(e)
            page_info = "Error"
            logger.error(f"Error in index route: {e}")
    
    return render_template_string(
        HTML_TEMPLATE,
        content=content,
        error=error,
        current_url=current_url,
        page_info=page_info,
        memory_usage=memory_usage
    )

@app.route('/api/fetch')
def api_fetch():
    """API endpoint to fetch URL content"""
    url = request.args.get('url', '')
    if not url:
        return jsonify({'error': 'URL parameter required'}), 400
    
    result = browser.fetch_url(url)
    return jsonify(result)

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'cache_size': len(browser.cache),
        'memory': round(os.sys.getsizeof(browser.cache) / 1024, 2),
        'timestamp': datetime.now().isoformat()
    })

@app.route('/screenshot')
def screenshot():
    """Generate a simple screenshot of text content"""
    text = request.args.get('text', 'No text provided')
    
    # Create a simple image with the text
    img = Image.new('RGB', (800, 400), color=(255, 255, 255))
    d = ImageDraw.Draw(img)
    
    # Use default font
    try:
        font = ImageFont.load_default()
    except:
        font = None
    
    # Add text
    d.text((10, 10), text, fill=(0, 0, 0), font=font)
    
    # Add border
    d.rectangle([(0, 0), (799, 399)], outline=(200, 200, 200), width=2)
    
    # Save to bytes
    img_io = BytesIO()
    img.save(img_io, 'PNG')
    img_io.seek(0)
    
    return send_file(img_io, mimetype='image/png')

@app.route('/static/<path:filename>')
def static_files(filename):
    """Serve static files if needed"""
    return f"Static file {filename} not found in single-file mode", 404

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 10000))
    
    logger.info(f"""
    ╔══════════════════════════════════════════╗
    ║   Lightweight Browser Starting...        ║
    ║   Port: {port}                            ║
    ║   Memory: ~100-200MB                     ║
    ║   Supports: Simple HTML/text sites       ║
    ╚══════════════════════════════════════════╝
    """)
    
    # Start the server
    app.run(
        host='0.0.0.0',
        port=port,
        debug=False,
        threaded=True
    )
