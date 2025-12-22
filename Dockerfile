FROM debian:bullseye

# Set environment variables to non-interactive to avoid install prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV USER=root

# 1. Enable 386 architecture
RUN dpkg --add-architecture i386

# 2. Update and Install Dependencies
# Added: python3 (for noVNC), procps, clean package names
RUN apt-get update && apt-get install -y \
    wine qemu-kvm xz-utils dbus-x11 curl firefox-esr \
    gnome-system-monitor git xfce4 xfce4-terminal \
    tightvncserver wget python3 python3-numpy \
    fonts-wqy-zenhei \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 3. Setup noVNC
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.2.0.tar.gz \
    && tar -xvf v1.2.0.tar.gz \
    && mv noVNC-1.2.0 /opt/noVNC \
    && rm v1.2.0.tar.gz

# 4. Setup VNC Directory and Password
# Note: It is safer to pass the password at runtime, but keeping your logic for now:
RUN mkdir -p $HOME/.vnc \
    && echo 'admin123@a' | vncpasswd -f > $HOME/.vnc/passwd \
    && chmod 600 $HOME/.vnc/passwd

# 5. Setup Xstartup (Configures VNC to use XFCE)
RUN echo '#!/bin/sh' > $HOME/.vnc/xstartup \
    && echo 'unset SESSION_MANAGER' >> $HOME/.vnc/xstartup \
    && echo 'unset DBUS_SESSION_BUS_ADDRESS' >> $HOME/.vnc/xstartup \
    && echo '/usr/bin/startxfce4' >> $HOME/.vnc/xstartup \
    && chmod +x $HOME/.vnc/xstartup

# 6. Copy the start script (See file below)
COPY start.sh /start.sh
RUN chmod +x /start.sh

# 7. Expose ports (8900 for web access)
EXPOSE 8900

CMD ["/start.sh"]
