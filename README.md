# VNC Desktop for Render

A Dockerized VNC desktop environment with XFCE4 that can be deployed on Render.

## Features
- XFCE4 Desktop Environment
- VNC Access via Browser
- Firefox Browser
- Terminal Access
- Supervisord for process management
- Nginx reverse proxy

## Deployment on Render

1. **Create a new repository** with all these files
2. **Go to [Render Dashboard](https://dashboard.render.com)**
3. Click **"New +"** → **"Web Service"**
4. Connect your GitHub/GitLab repository
5. Configure:
   - **Name:** vnc-desktop
   - **Environment:** Docker
   - **Plan:** Free
6. Click **"Create Web Service"**

## Access

Once deployed:
1. Go to your Render service URL
2. Click "Connect" in the noVNC interface
3. Enter password: `Albin4242`
4. Enjoy your desktop!

## Environment Variables

You can customize these in Render dashboard:
- `VNC_PASSWORD`: VNC access password (default: Albin4242)
- `RESOLUTION`: Screen resolution (default: 1360x768x24)
- `WEB_PORT`: Web interface port (default: 8080)

## Files Description

- `Dockerfile`: Main container definition
- `start.sh`: Startup script
- `supervisord.conf`: Process manager configuration
- `nginx.conf`: Web server configuration
- `render.yaml`: Render deployment configuration
- `xfce4-desktop.xml`: XFCE desktop customization (optional)

## Security Notes

1. The VNC password is set to "Albin4242" by default
2. Consider changing the password before production use
3. Free tier on Render sleeps after inactivity
4. Data is not persistent (container is ephemeral)

## Troubleshooting

1. **Service won't start**: Check Render logs for errors
2. **Can't connect via VNC**: Wait 2-3 minutes for full startup
3. **Black screen**: Refresh the browser page
4. **High memory usage**: Free tier has 512MB RAM limit
