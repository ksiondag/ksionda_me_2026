#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_ROOT/nginx/local.conf"

cat > "$OUT" <<NGINX
server {
    listen 8080;
    server_name localhost;

    root $REPO_ROOT;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ ^/([^.]+)$ {
        try_files \$uri \$uri.html \$uri/ =404;
    }
}
NGINX

echo "Generated $OUT"
