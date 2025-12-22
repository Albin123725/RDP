# XFCE VNC Desktop for Render

A lightweight, optimized XFCE desktop environment running on Render.com with VNC access.

## Features
- XFCE 4.16 Desktop Environment
- TigerVNC Server
- noVNC Web Access
- Pre-installed applications (Firefox, Terminal, File Manager)
- Optimized for Render's free tier

## Deployment

### Option 1: Deploy to Render
[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy)

### Option 2: Manual Setup
1. Fork this repository
2. Create a new Web Service on Render
3. Connect your GitHub repository
4. Set build command: `docker build -t xfce-vnc .`
5. Set start command: `docker run -p 5901:5901 -p 6080:6080 xfce-vnc`
6. Add environment variables (optional):
   - `VNC_PASSWORD`: Your VNC password
   - `RESOLUTION`: Desktop resolution (default: 1920x1080)

## Access

### Via VNC Client
- Host: `your-service.onrender.com`
- Port: `5901`
- Password: Set via VNC_PASSWORD environment variable

### Via Web Browser (noVNC)
- URL: `https://your-service.onrender.com:6080/vnc.html`
- Password: Same as VNC password

## Customization
Edit the `Dockerfile` to:
- Add more applications
- Change desktop theme
- Modify startup applications

## Notes
- Render free tier has limitations (sleeps after inactivity)
- Use Basic or higher plans for always-on service
- VNC over public internet should use strong passwords
