FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Kolkata
ENV USER=root
ENV HOME=/root
ENV DISPLAY=:1
ENV VNC_PASSWD=password123
ENV VNC_RESOLUTION=1024x576
ENV VNC_DEPTH=16
ENV ENABLE_SWAP=true
ENV SWAP_SIZE_GB=8

# Install minimal packages
RUN apt update && apt install -y \
    xfce4 \
    xfce4-goodies \
    tightvncserver \
    novnc \
    websockify \
    wget \
    sudo \
    dbus-x11 \
    x11-utils \
    gcc \
    python3 \
    python3-pip \
    htop \
    neofetch \
    stress-ng \
    net-tools \
    --no-install-recommends && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

# === MEMORY OPTIMIZATION ===
# Enable overcommit
RUN echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf && \
    echo "vm.overcommit_ratio = 95" >> /etc/sysctl.conf

# Create swap script
RUN cat > /create_swap.sh << 'EOF'
#!/bin/bash
if [ "$ENABLE_SWAP" = "true" ]; then
    echo "Creating ${SWAP_SIZE_GB}GB swap..."
    fallocate -l ${SWAP_SIZE_GB}G /swapfile 2>/dev/null || \
    dd if=/dev/zero of=/swapfile bs=1M count=$((SWAP_SIZE_GB * 1024))
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
    echo "Swap enabled: ${SWAP_SIZE_GB}GB"
fi
EOF

# === VNC SETUP ===
RUN mkdir -p ~/.vnc && \
    echo "$VNC_PASSWD" | vncpasswd -f > ~/.vnc/passwd && \
    chmod 600 ~/.vnc/passwd

# Simple xstartup
RUN echo '#!/bin/bash\nxsetroot -solid grey\nexport XKL_XMODMAP_DISABLE=1\nxfce4-session &' > ~/.vnc/xstartup && \
    chmod +x ~/.vnc/xstartup

# === NOVNC SETUP ===
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc && \
    git clone https://github.com/novnc/websockify.git /opt/novnc/utils/websockify

# === RESOURCE GRAB SCRIPT ===
RUN cat > /grab_resources.py << 'EOF'
#!/usr/bin/env python3
import mmap
import time
import threading
import sys

print("=== RESOURCE ALLOCATION STARTED ===")

def allocate_memory(size_mb, name):
    """Allocate and hold memory"""
    try:
        data = bytearray(size_mb * 1024 * 1024)
        data[0] = 1
        data[-1] = 1
        print(f"{name}: Allocated {size_mb}MB")
        return data
    except:
        print(f"{name}: Failed to allocate {size_mb}MB")
        return None

# Allocate in chunks
chunks = []
for i in range(8):  # 8 chunks of 512MB = 4GB
    chunk = allocate_memory(512, f"Chunk-{i+1}")
    if chunk:
        chunks.append(chunk)
        time.sleep(0.5)

print(f"Total allocated: {len(chunks) * 512}MB")
print("Holding memory...")

# Keep process alive
while True:
    time.sleep(3600)
EOF

# === STARTUP SCRIPT ===
RUN cat > /start.sh << 'EOF'
#!/bin/bash

echo "=== STARTING SYSTEM ==="

# Apply kernel settings
sysctl -p

# Create swap
bash /create_swap.sh

echo "=== MEMORY STATUS ==="
free -h

echo "=== STARTING RESOURCE ALLOCATION ==="
python3 /grab_resources.py &

echo "=== STARTING VNC ==="
vncserver :1 -geometry $VNC_RESOLUTION -depth $VNC_DEPTH -localhost no

echo "=== STARTING NOVNC ==="
/opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:10000 &

echo "=== SYSTEM READY ==="
echo "VNC Password: $VNC_PASSWD"
echo "Access URL: https://$(hostname).onrender.com/vnc.html"

# Keep container running
tail -f /dev/null
EOF

RUN chmod +x /start.sh /create_swap.sh /grab_resources.py

EXPOSE 10000

CMD ["/bin/bash", "/start.sh"]
