#!/bin/bash

echo "========================================="
echo "Starting VNC Desktop Environment"
echo "========================================="
echo "VNC Password: $VNC_PASSWORD"
echo "Resolution: $RESOLUTION"
echo "========================================="

# Set up directories
mkdir -p /var/run/supervisor /var/log/supervisor
chown -R appuser:appuser /home/appuser

# Start supervisord
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
