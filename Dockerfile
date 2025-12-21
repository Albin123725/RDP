FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV USER=root
ENV HOME=/root
ENV DISPLAY=:99

RUN apt-get update && \
    apt-get install -y \
    dbus-x11 \
    xfce4 xfce4-terminal \
    firefox-esr \
    novnc websockify \
    xvfb x11vnc \
    && rm -rf /var/lib/apt/lists/*

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
