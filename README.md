# ksionda.me

Personal website. Static HTML and CSS.

## Local Development with nginx

### 1. Install nginx

```bash
sudo pacman -S nginx
```

### 2. Generate the local config

```bash
bash scripts/gen-local-nginx.sh
```

This writes `nginx/local.conf` with the `root` set to the absolute path of the repo on your machine. Re-run it if you move the repo. The file is gitignored.

### 3. Include the config

Add an include line to `/etc/nginx/nginx.conf` inside the `http {}` block:

```nginx
http {
    ...
    include /etc/nginx/conf.d/*.conf;
}
```

Then symlink the generated config:

```bash
sudo mkdir -p /etc/nginx/conf.d
sudo ln -s "$PWD/nginx/local.conf" /etc/nginx/conf.d/ksionda-local.conf
```

### 4. Allow nginx to read the repo

The nginx worker runs as the `http` user and needs execute permission on your home directory to traverse into it:

```bash
chmod o+x ~
```

### 5. Start nginx

```bash
sudo systemctl enable --now nginx
```

The site will be available at `http://localhost:8080`.

After making changes to the nginx config, reload without downtime:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

---

## Production Deployment

These steps assume an Arch Linux server with a domain pointing at it.

### 1. Install nginx

```bash
sudo pacman -S nginx
```

### 2. Create the web root and deploy files

```bash
sudo mkdir -p /var/www/ksionda.me
sudo chown $USER:$USER /var/www/ksionda.me
cp index.html blog.html style.css /var/www/ksionda.me/
```

For future deploys, rsync works well:

```bash
rsync -av --delete --exclude='.git' --exclude='nginx' --exclude='README.md' \
    ./ user@your-server:/var/www/ksionda.me/
```

### 3. Install the nginx config

```bash
sudo mkdir -p /etc/nginx/conf.d
sudo cp nginx/production.conf /etc/nginx/conf.d/ksionda.me.conf
```

Make sure `/etc/nginx/nginx.conf` includes conf.d (same as local setup above).

```bash
sudo nginx -t && sudo systemctl enable --now nginx
```

The site will be live on port 80.

### 4. Set up HTTPS with Let's Encrypt

```bash
sudo pacman -S certbot certbot-nginx
sudo certbot --nginx -d ksionda.me -d www.ksionda.me
```

Certbot will modify the nginx config automatically. After it runs, uncomment the HTTPS server block in `nginx/production.conf` as a reference for what it set up.

Set up auto-renewal:

```bash
sudo systemctl enable --now certbot-renew.timer
```
