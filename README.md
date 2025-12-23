# Real Browser RDP

A real browser running in the cloud that you can control from your web browser.

## Features
- 🌐 **Real Chrome Browser** - Actual Chrome running on Render
- 🎮 **Full Remote Control** - Mouse, keyboard, navigation
- 🚀 **Instant Deployment** - One-click deploy to Render
- 🆓 **Free Tier** - Runs on Render's free tier
- 📱 **Responsive** - Works on desktop and mobile

## Quick Deploy

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy)

Or manually:
1. Fork this repository
2. Go to [Render Dashboard](https://dashboard.render.com)
3. Click "New +" → "Web Service"
4. Connect your GitHub repository
5. Select the repository
6. Click "Create Web Service"

## How It Works

1. **Render runs Chrome** in a Docker container
2. **Flask server** captures screenshots
3. **Your browser** connects via WebSocket
4. **Commands** are sent back to control Chrome

## Local Development

```bash
# Clone repository
git clone <your-repo>
cd real-browser-rdp

# Install dependencies
pip install -r requirements.txt

# Download ChromeDriver
python -m webdriver_manager chrome

# Run locally
python app.py

# Open http://localhost:8080
