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
# Memory optimization variables
ENV ENABLE_SWAP=true
ENV SWAP_SIZE_GB=8
ENV OVERCOMMIT_MEMORY=1

# Set timezone
RUN ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo "Asia/Kolkata" > /etc/timezone

# === PHASE 1: Install with aggressive cleanup ===
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
    x11-xserver-utils \
    xfonts-base \
    gcc \
    python3 \
    python3-pip \
    htop \
    neofetch \
    stress-ng \
    --no-install-recommends && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/locale/* && \
    apt purge -y xfce4-screensaver xfce4-power-manager xscreensaver* && \
    apt autoremove -y && \
    apt autoclean

# === PHASE 2: Memory optimization setup ===
# Enable memory overcommit (allows allocating more than available)
RUN echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf && \
    echo "vm.overcommit_ratio = 95" >> /etc/sysctl.conf && \
    echo "vm.swappiness = 10" >> /etc/sysctl.conf

# Create large swap file (virtual memory)
RUN cat > /create_swap.sh << 'EOF'
#!/bin/bash
if [ "$ENABLE_SWAP" = "true" ]; then
    echo "Creating ${SWAP_SIZE_GB}GB swap file..."
    fallocate -l ${SWAP_SIZE_GB}G /swapfile || \
    dd if=/dev/zero of=/swapfile bs=1G count=${SWAP_SIZE_GB}
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
    echo "Swap created successfully"
fi
EOF

RUN chmod +x /create_swap.sh

# === PHASE 3: Setup VNC ===
RUN mkdir -p /root/.vnc && \
    printf "${VNC_PASSWD}\n${VNC_PASSWD}\nn\n" | vncpasswd && \
    chmod 600 /root/.vnc/passwd

# Optimized xstartup
RUN cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
xsetroot -solid grey
vncconfig -iconic &
# Memory-optimized Xfce
xfwm4 --compositor=off &
xfsettingsd --daemon
xfce4-panel &
xfdesktop &
EOF

RUN chmod +x /root/.vnc/xstartup

# === PHASE 4: Install noVNC ===
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt/ && \
    mv /opt/noVNC-1.4.0 /opt/novnc && \
    rm /tmp/novnc.tar.gz && \
    wget -q https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz -O /tmp/websockify.tar.gz && \
    tar -xzf /tmp/websockify.tar.gz -C /opt/novnc/utils/ && \
    mv /opt/novnc/utils/websockify-0.11.0 /opt/novnc/utils/websockify && \
    rm /tmp/websockify.tar.gz

# === PHASE 5: Resource maximization scripts ===
# Memory reservation script (uses overcommit)
RUN cat > /reserve_memory.py << 'EOF'
#!/usr/bin/env python3
import mmap
import time
import sys
import os

def reserve_memory(target_gb=16):
    """Reserve memory using mmap with MAP_NORESERVE"""
    print(f"Attempting to reserve {target_gb}GB of address space...")
    
    try:
        # Reserve virtual address space (doesn't use physical memory yet)
        size = target_gb * 1024 * 1024 * 1024
        mem = mmap.mmap(-1, size, flags=mmap.MAP_PRIVATE | mmap.MAP_ANONYMOUS)
        
        print(f"✓ Reserved {target_gb}GB virtual address space")
        print("Physical memory will be allocated on-demand")
        
        # Commit memory gradually to avoid OOM
        commit_size = 1024 * 1024  # 1MB chunks
        committed = 0
        target_commit = 8 * 1024 * 1024 * 1024  # Commit up to 8GB
        
        for i in range(0, min(size, target_commit), commit_size):
            mem[i] = b'x'  # This commits the page
            committed += 1
            
            if i % (100 * 1024 * 1024) == 0:  # Every 100MB
                print(f"Committed {committed}MB...")
                time.sleep(0.1)
        
        print(f"✓ Successfully committed {committed}MB")
        print("Holding memory...")
        
        # Keep the memory
        while True:
            time.sleep(3600)
            
    except Exception as e:
        print(f"Error: {e}")
        # Try smaller allocation
        if target_gb > 4:
            reserve_memory(target_gb // 2)

if __name__ == "__main__":
    # Start with 16GB, will reduce if fails
    reserve_memory(16)
EOF

RUN chmod +x /reserve_memory.py

# Process that claims CPU resources
RUN cat > /claim_cpu.sh << 'EOF'
#!/bin/bash
echo "=== CPU Resource Claim ==="
echo "Starting stress-ng to utilize available CPU..."
# Use 80% of available CPU cores
cores=$(nproc)
stress_cores=$((cores * 80 / 100))
if [ $stress_cores -lt 1 ]; then
    stress_cores=1
fi

# Start stress test in background
stress-ng --cpu $stress_cores --timeout 0 --metrics-brief &
echo "CPU stress running on $stress_cores cores"
EOF

RUN chmod +x /claim_cpu.sh

# === PHASE 6: Startup optimization ===
# Create optimized startup script
RUN cat > /startup.sh << 'EOF'
#!/bin/bash

echo "=== System Information ==="
neofetch --stdout
echo ""

# Apply sysctl settings
sysctl -p

# Create swap
/create_swap.sh

echo "=== Memory Status ==="
free -h
echo ""

# Start memory reservation in background
echo "Starting memory reservation..."
python3 /reserve_memory.py &

# Start CPU claim
/claim_cpu.sh &

echo "=== Starting VNC Server ==="
# Fix font path issue
sed -i 's/\$fontPath =.*/\$fontPath = "";/' /usr/bin/vncserver

# Start VNC
vncserver :1 -geometry ${VNC_RESOLUTION} -depth ${VNC_DEPTH} \
  -noxstartup -xstartup /root/.vnc/xstartup

echo "VNC started on display :1"

echo "=== Starting noVNC ==="
/opt/novnc/utils/novnc_proxy \
  --vnc localhost:5901 \
  --listen 0.0.0.0:10000 \
  --heartbeat 30 \
  --web /opt/novnc &

echo "noVNC started on port 10000"
echo "Access at: http://[RENDER_URL]/vnc_lite.html"
echo "Password: ${VNC_PASSWD}"

# Show resource usage
echo ""
echo "=== Current Resource Usage ==="
htop --version >/dev/null 2>&1 && htop -d 10 &

# Keep container alive
tail -f /dev/null
EOF

RUN chmod +x /startup.sh

# === PHASE 7: Copy noVNC files ===
RUN cp /opt/novnc/vnc_lite.html /opt/novnc/index.html

EXPOSE 10000

# Use optimized startup
CMD ["/bin/bash", "/startup.sh"]
