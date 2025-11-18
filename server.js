const express = require('express');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 5000;

app.use(express.static('public'));

app.get('/', (req, res) => {
  const readme = fs.readFileSync('README.md', 'utf8');
  
  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Ubuntu noVNC Desktop - Render Deployment</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: #333;
          line-height: 1.6;
          padding: 20px;
        }
        .container {
          max-width: 1200px;
          margin: 0 auto;
          background: white;
          border-radius: 15px;
          padding: 40px;
          box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        h1 {
          color: #667eea;
          font-size: 2.5em;
          margin-bottom: 20px;
          border-bottom: 3px solid #667eea;
          padding-bottom: 10px;
        }
        h2 {
          color: #764ba2;
          margin-top: 30px;
          margin-bottom: 15px;
        }
        .status-card {
          background: #f8f9fa;
          border-left: 4px solid #28a745;
          padding: 20px;
          margin: 20px 0;
          border-radius: 5px;
        }
        .warning-card {
          background: #fff3cd;
          border-left: 4px solid #ffc107;
          padding: 20px;
          margin: 20px 0;
          border-radius: 5px;
        }
        .info-card {
          background: #d1ecf1;
          border-left: 4px solid #17a2b8;
          padding: 20px;
          margin: 20px 0;
          border-radius: 5px;
        }
        .deploy-btn {
          display: inline-block;
          background: #667eea;
          color: white;
          padding: 15px 30px;
          text-decoration: none;
          border-radius: 5px;
          font-weight: bold;
          margin: 10px 10px 10px 0;
          transition: background 0.3s;
        }
        .deploy-btn:hover {
          background: #764ba2;
        }
        .file-list {
          background: #f8f9fa;
          padding: 20px;
          border-radius: 5px;
          margin: 20px 0;
        }
        .file-list ul {
          list-style: none;
          padding-left: 0;
        }
        .file-list li {
          padding: 8px 0;
          border-bottom: 1px solid #dee2e6;
        }
        .file-list li:before {
          content: "📄 ";
          margin-right: 10px;
        }
        code {
          background: #f8f9fa;
          padding: 2px 6px;
          border-radius: 3px;
          font-family: 'Courier New', monospace;
          color: #e83e8c;
        }
        .specs {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
          gap: 20px;
          margin: 20px 0;
        }
        .spec-item {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          padding: 20px;
          border-radius: 10px;
          text-align: center;
        }
        .spec-item h3 {
          font-size: 1.2em;
          margin-bottom: 10px;
        }
        .spec-item p {
          font-size: 0.95em;
          opacity: 0.9;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>🖥️ Ubuntu noVNC Desktop Environment</h1>
        
        <div class="status-card">
          <h3>✅ Project Ready for Deployment</h3>
          <p>All configuration files have been created and are ready to deploy to Render.com</p>
        </div>

        <div class="warning-card">
          <h3>⚠️ Important Notice</h3>
          <p><strong>This application requires Docker and cannot run in Replit.</strong> You must deploy it to Render or another Docker-compatible platform for it to function.</p>
        </div>

        <h2>🚀 Quick Deploy to Render</h2>
        <div class="info-card">
          <p><strong>Step 1:</strong> Push this repository to GitHub</p>
          <p><strong>Step 2:</strong> Click the button below to deploy to Render</p>
          <p><strong>Step 3:</strong> Set your VNC password in environment variables</p>
          <p><strong>Step 4:</strong> Access your desktop via the Render URL</p>
        </div>

        <a href="https://dashboard.render.com/select-repo?type=web" class="deploy-btn" target="_blank">
          🚀 Deploy to Render
        </a>
        <a href="https://github.com/new" class="deploy-btn" target="_blank">
          📦 Create GitHub Repo
        </a>

        <h2>📋 What's Included</h2>
        <div class="specs">
          <div class="spec-item">
            <h3>🐧 Ubuntu 22.04</h3>
            <p>Latest LTS release with full desktop environment</p>
          </div>
          <div class="spec-item">
            <h3>🖼️ XFCE Desktop</h3>
            <p>Lightweight, fast, and responsive UI</p>
          </div>
          <div class="spec-item">
            <h3>🌐 noVNC Access</h3>
            <p>Web-based VNC client, no software needed</p>
          </div>
          <div class="spec-item">
            <h3>💻 GitHub CLI</h3>
            <p>Pre-installed and ready for development</p>
          </div>
        </div>

        <h2>📦 Project Files</h2>
        <div class="file-list">
          <ul>
            <li><code>Dockerfile</code> - Ubuntu 22.04 with XFCE, VNC, noVNC</li>
            <li><code>docker-compose.yml</code> - Local testing configuration</li>
            <li><code>render.yaml</code> - Render deployment blueprint</li>
            <li><code>supervisord.conf</code> - Process management for VNC services</li>
            <li><code>entrypoint.sh</code> - Container startup script</li>
            <li><code>README.md</code> - Complete documentation</li>
          </ul>
        </div>

        <h2>💰 Recommended Render Plans</h2>
        <div class="info-card">
          <p><strong>Standard Plan ($25/month)</strong> - 4GB RAM - Minimum recommended</p>
          <p><strong>Pro Plan ($85/month)</strong> - 8GB RAM - Best for development</p>
          <p><strong>Pro Plus ($175/month)</strong> - 16GB RAM - Heavy workloads</p>
          <p style="margin-top: 10px; font-style: italic;">All plans include 24/7 uptime and persistent storage</p>
        </div>

        <h2>🔐 Default Configuration</h2>
        <div class="warning-card">
          <p><strong>Default VNC Password:</strong> <code>password</code></p>
          <p><strong>⚠️ CHANGE THIS IMMEDIATELY!</strong> Set <code>VNC_PASSWORD</code> environment variable in Render</p>
          <p><strong>Desktop Resolution:</strong> 1920x1080 (configurable via <code>VNC_RESOLUTION</code>)</p>
        </div>

        <h2>📖 Full Documentation</h2>
        <p>See <code>README.md</code> in this project for complete deployment instructions, troubleshooting, and configuration options.</p>

        <div style="margin-top: 40px; padding-top: 20px; border-top: 2px solid #dee2e6; text-align: center; color: #6c757d;">
          <p>Built with ❤️ for 24/7 Ubuntu desktop access | Deploy to Render for best results</p>
        </div>
      </div>
    </body>
    </html>
  `);
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'Project files ready for Render deployment' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ Project info server running on http://0.0.0.0:${PORT}`);
  console.log(`📝 This is an information page - the actual noVNC desktop runs on Render`);
  console.log(`🚀 Deploy to Render: https://dashboard.render.com/`);
});
