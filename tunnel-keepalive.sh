#!/bin/bash
# tunnel-keepalive.sh - 自动保活 localtunnel 隧道
# 用法: bash /workspace/projects/tunnel-keepalive.sh

TUNNEL_SUBDOMAIN="shiplink-cargo"
LOCAL_PORT=5000
LOG_FILE="/tmp/tunnel-keepalive.log"
HEALTH_URL="https://${TUNNEL_SUBDOMAIN}.loca.lt/home.html"

echo "[$(date)] Tunnel keepalive started" >> "$LOG_FILE"

while true; do
  # 检查本地服务是否在运行
  if ! curl -s -o /dev/null --max-time 3 "http://localhost:${LOCAL_PORT}/home.html" > /dev/null 2>&1; then
    echo "[$(date)] Local server not responding on port ${LOCAL_PORT}" >> "$LOG_FILE"
    # 尝试重启本地服务
    cd /workspace/projects && python3 -m http.server $LOCAL_PORT &
    sleep 3
  fi

  # 检查隧道进程是否在运行
  if ! pgrep -f "localtunnel" > /dev/null 2>&1; then
    echo "[$(date)] Tunnel process died, restarting..." >> "$LOG_FILE"
    npx localtunnel -p $LOCAL_PORT -s $TUNNEL_SUBDOMAIN >> "$LOG_FILE" 2>&1 &
    sleep 5
  fi

  # 检查隧道是否真的能从外部访问
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$HEALTH_URL" 2>/dev/null)
  if [ "$http_code" != "200" ]; then
    echo "[$(date)] Tunnel health check failed (HTTP $http_code), restarting..." >> "$LOG_FILE"
    pkill -f "localtunnel" 2>/dev/null
    sleep 2
    npx localtunnel -p $LOCAL_PORT -s $TUNNEL_SUBDOMAIN >> "$LOG_FILE" 2>&1 &
    sleep 5
  else
    echo "[$(date)] Tunnel healthy (HTTP 200)" >> "$LOG_FILE"
  fi

  # 每 60 秒检查一次
  sleep 60
done
