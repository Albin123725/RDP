FROM dorowu/ubuntu-desktop-lxde-vnc

# Expose port 80 for VNC server
EXPOSE 80

# Set the container's startup command
CMD ["sh", "-c", "start-desktop"]
