FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \
    firefox-esr \
    novnc websockify \
    xvfb x11vnc \
    fluxbox \
    xterm \
    && rm -rf /var/lib/apt/lists/*

# Create startup script directly
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'echo "Starting Xvfb..."' >> /start.sh && \
    echo 'Xvfb :99 -screen 0 1360x768x24 &' >> /start.sh && \
    echo 'sleep 2' >> /start.sh && \
    echo '' >> /start.sh && \
    echo 'echo "Starting x11vnc..."' >> /start.sh && \
    echo 'x11vnc -display :99 -forever -shared -nopw -listen 0.0.0.0 &' >> /start.sh && \
    echo 'sleep 2' >> /start.sh && \
    echo '' >> /start.sh && \
    echo 'echo "Starting Firefox..."' >> /start.sh && \
    echo 'DISPLAY=:99 firefox-esr &' >> /start.sh && \
    echo 'sleep 3' >> /start.sh && \
    echo '' >> /start.sh && \
    echo 'echo "Starting noVNC..."' >> /start.sh && \
    echo 'echo "Access: https://\$(hostname):8080/vnc.html"' >> /start.sh && \
    echo 'websockify --web=/usr/share/novnc 0.0.0.0:8080 localhost:5900' >> /start.sh && \
    chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
