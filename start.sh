#!/bin/bash

echo "========================================="
echo "Starting VNC Desktop Environment"
echo "========================================="
echo "VNC Password: $VNC_PASSWORD"
echo "Resolution: $RESOLUTION"
echo "VNC Port: $VNC_PORT"
echo "Web Interface Port: $WEB_PORT"
echo "========================================="

# Set permissions
chown -R appuser:appuser /home/appuser
chmod 755 /home/appuser

# Start services
echo "Starting all services via supervisord..."
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
