#!/bin/bash
# tunnel-keepalive.sh - 自动保活 localtunnel 隧道（增强版）
# 用法: bash /workspace/projects/tunnel-keepalive.sh

TUNNEL_SUBDOMAIN="shiplink-cargo"
LOCAL_PORT=5000
LOG_FILE="/tmp/tunnel-keepalive.log"
HEALTH_URL="https://${TUNNEL_SUBDOMAIN}.loca.lt/home.html"

echo "[$(date)] Tunnel keepalive started (enhanced)" >> "$LOG_FILE"

while true; do
  # 1. 检查本地HTTP服务是否在运行
  if ! curl -s -o /dev/null --max-time 3 "http://localhost:${LOCAL_PORT}/home.html" > /dev/null 2>&1; then
    echo "[$(date)] Local server not responding, restarting..." >> "$LOG_FILE"
    cd /workspace/projects && (nohup python3 -m http.server $LOCAL_PORT > /tmp/httpd.log 2>&1 &)
    sleep 3
  fi

  # 2. 检查隧道进程是否在运行
  if ! pgrep -f "localtunnel" > /dev/null 2>&1; then
    echo "[$(date)] Tunnel process died, restarting..." >> "$LOG_FILE"
    (nohup npx localtunnel -p $LOCAL_PORT -s $TUNNEL_SUBDOMAIN > /tmp/lt.log 2>&1 &)
    sleep 8
  fi

  # 3. 端到端健康检查（隧道+本地服务）
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$HEALTH_URL" 2>/dev/null)
  if [ "$http_code" != "200" ]; then
    echo "[$(date)] Health check failed (HTTP $http_code), full restart..." >> "$LOG_FILE"
    pkill -f "localtunnel" 2>/dev/null
    sleep 2
    (nohup npx localtunnel -p $LOCAL_PORT -s $TUNNEL_SUBDOMAIN > /tmp/lt.log 2>&1 &)
    sleep 8
  else
    echo "[$(date)] Tunnel healthy (HTTP 200)" >> "$LOG_FILE"
  fi

  # 每 20 秒检查一次（更频繁）
  sleep 20
done
