#!/bin/bash

VNC_PASSWORD=${VNC_PASSWORD:-"password"}

mkdir -p /root/.vnc
echo "$VNC_PASSWORD" | vncpasswd -f > /root/.vnc/passwd
chmod 600 /root/.vnc/passwd

rm -rf /tmp/.X1-lock /tmp/.X11-unix

exec "$@"
