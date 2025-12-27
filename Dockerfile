FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV VNC_PASSWORD=password123
ENV DISPLAY=:1

# Install minimal packages
RUN apt update && apt install -y \
    x11vnc \
    xvfb \
    fluxbox \
    chromium-browser \
    wget \
    python3 \
    net-tools \
    --no-install-recommends && \
    apt clean

# Download noVNC 1.2.0 (very stable)
RUN wget -q https://github.com/novnc/noVNC/archive/v1.2.0.tar.gz -O /tmp/novnc.tar.gz && \
    tar -xzf /tmp/novnc.tar.gz -C /opt/ && \
    mv /opt/noVNC-1.2.0 /opt/novnc && \
    rm /tmp/novnc.tar.gz

# Set VNC password
RUN mkdir -p ~/.vnc && \
    x11vnc -storepasswd ${VNC_PASSWORD} ~/.vnc/passwd

# Create startup script
RUN echo '#!/bin/bash' > /start.sh
RUN echo 'echo "Starting Xvfb..."' >> /start.sh
RUN echo 'Xvfb :1 -screen 0 1024x768x16 &' >> /start.sh
RUN echo 'sleep 3' >> /start.sh
RUN echo 'echo "Starting fluxbox..."' >> /start.sh
RUN echo 'fluxbox &' >> /start.sh
RUN echo 'sleep 2' >> /start.sh
RUN echo 'echo "Starting x11vnc..."' >> /start.sh
RUN echo 'x11vnc -display :1 -forever -shared -rfbauth ~/.vnc/passwd -bg' >> /start.sh
RUN echo 'sleep 2' >> /start.sh
RUN echo 'echo "Starting browser..."' >> /start.sh
RUN echo 'chromium-browser --no-sandbox --disable-dev-shm-usage --window-size=1024,768 about:blank &' >> /start.sh
RUN echo 'sleep 2' >> /start.sh
RUN echo 'echo "Starting noVNC..."' >> /start.sh
RUN echo 'cd /opt/novnc && python3 -m websockify --web=. 8080 localhost:5900' >> /start.sh
RUN echo 'wait' >> /start.sh

RUN chmod +x /start.sh

EXPOSE 8080

CMD /start.sh
