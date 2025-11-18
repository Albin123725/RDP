# 24/7 Ubuntu noVNC Desktop Environment

A fully-featured Ubuntu 22.04 desktop environment accessible through your web browser using noVNC, with GitHub CLI and development tools pre-installed. Designed for 24/7 deployment on Render with high resource allocation.

## Features

- **Ubuntu 22.04 LTS** base system
- **XFCE4 Desktop Environment** (lightweight and responsive)
- **noVNC Web Interface** - Access your desktop from any browser
- **VNC Server** - TigerVNC for reliable remote desktop access
- **GitHub CLI** pre-installed and ready to use
- **Development Tools** including:
  - Git
  - Node.js & npm
  - Python 3
  - Build essentials (gcc, g++, make)
  - Firefox web browser
  - Vim & Nano text editors
- **Persistent Storage** for your files and configurations

## Resource Requirements

For optimal performance, recommended Render plan:
- **Standard Plan** (4GB RAM) - Good for general use
- **Pro Plan** (8GB RAM) - Better for development workloads
- **Pro Plus/Max** (16GB+ RAM) - Best for intensive tasks

## Quick Deploy to Render

### Method 1: One-Click Deploy (Recommended)

1. Push this repository to GitHub
2. Go to [Render Dashboard](https://dashboard.render.com/)
3. Click "New +" → "Blueprint"
4. Connect your GitHub repository
5. Render will automatically detect `render.yaml` and configure everything
6. Click "Apply" to deploy

### Method 2: Manual Deployment

1. Push this repository to GitHub
2. Go to [Render Dashboard](https://dashboard.render.com/)
3. Click "New +" → "Web Service"
4. Connect your GitHub repository
5. Configure:
   - **Name**: ubuntu-novnc-desktop
   - **Runtime**: Docker
   - **Plan**: Standard or higher (recommended: Pro for 8GB RAM)
   - **Docker Command**: Leave default (uses Dockerfile)
6. Add Environment Variables:
   - `VNC_PASSWORD`: Your secure VNC password
   - `VNC_RESOLUTION`: 1920x1080 (or your preference)
7. Click "Create Web Service"

## Accessing Your Desktop

Once deployed, Render will provide you with a URL (e.g., `https://your-app.onrender.com`).

1. Open the URL in your web browser
2. You'll see the noVNC connection screen
3. Click "Connect"
4. Enter your VNC password (from environment variable)
5. Your Ubuntu desktop will appear in the browser!

## Default Credentials

- **VNC Password**: Set via `VNC_PASSWORD` environment variable
- **Default**: `password` (change this immediately!)

## Configuration Options

### Environment Variables

Edit these in Render Dashboard → Your Service → Environment:

| Variable | Default | Description |
|----------|---------|-------------|
| `VNC_PASSWORD` | password | Password for VNC access (CHANGE THIS!) |
| `VNC_RESOLUTION` | 1920x1080 | Desktop resolution |
| `VNC_COL_DEPTH` | 24 | Color depth (16 or 24) |

### Changing Resolution

Common resolutions:
- `1920x1080` (Full HD)
- `1680x1050` (Wide)
- `1440x900` (Laptop)
- `1280x720` (HD)

## Using GitHub in Your Desktop

GitHub CLI is pre-installed. To authenticate:

1. Open Terminal in the desktop
2. Run: `gh auth login`
3. Follow the prompts to authenticate with GitHub

## Local Testing (Docker Required)

If you have Docker installed locally:

```bash
cp .env.example .env
docker-compose up -d
```

Access at: http://localhost:6080

## File Persistence

All files in `/root` directory are persisted. Your Desktop, Documents, and Downloads folders will remain between restarts.

## Troubleshooting

### Cannot Connect
- Check Render logs for errors
- Verify service is running
- Check VNC_PASSWORD is set correctly

### Low Performance
- Upgrade to a higher Render plan (more RAM/CPU)
- Reduce VNC_RESOLUTION in environment variables
- Close unnecessary applications in the desktop

### Connection Keeps Dropping
- Check your internet connection
- Render free tier may have limitations; upgrade to paid plan

## Security Notes

1. **Change the default VNC password immediately**
2. VNC traffic is not encrypted by default (Render provides HTTPS)
3. Do not expose sensitive credentials in the desktop environment
4. Use GitHub CLI authentication instead of storing tokens

## Cost Estimate (Render)

- **Starter Plan**: $7/month (512MB RAM) - Not recommended
- **Standard Plan**: $25/month (4GB RAM) - Minimum recommended
- **Pro Plan**: $85/month (8GB RAM) - Recommended for development
- **Pro Plus**: $175/month (16GB RAM) - Best for heavy workloads

24/7 uptime included with paid plans.

## Support

For issues:
1. Check Render service logs
2. Verify environment variables are set correctly
3. Ensure you're on an appropriate Render plan (4GB+ RAM recommended)

## License

MIT License - Feel free to modify and use as needed.
