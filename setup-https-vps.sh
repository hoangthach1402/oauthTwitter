#!/bin/bash
# setup-https-vps.sh - Complete HTTPS setup for VPS

set -e

DOMAIN="thachdev.zapto.org"
EMAIL="your-email@gmail.com"  # Thay bằng email thực của bạn
VPS_IP="207.180.251.81"

echo "🔒 Setting up HTTPS for $DOMAIN on VPS $VPS_IP..."

# 1. Install required packages
echo "📦 Installing Nginx and Certbot..."
apt update
apt install -y nginx certbot python3-certbot-nginx

# 2. Stop nginx để clear port 80 cho certbot
systemctl stop nginx

# 3. Create Nginx configuration
echo "⚙️ Creating Nginx configuration..."
cat > /etc/nginx/sites-available/$DOMAIN << 'EOF'
# HTTP server block - redirect to HTTPS
server {
    listen 80;
    server_name thachdev.zapto.org;
    
    # Allow certbot challenges
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        allow all;
    }
    
    # Redirect all other HTTP to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS server block
server {
    listen 443 ssl http2;
    server_name thachdev.zapto.org;
    
    # SSL configuration (will be managed by Certbot)
    ssl_certificate /etc/letsencrypt/live/thachdev.zapto.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/thachdev.zapto.org/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    
    # Proxy to Node.js backend
    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $server_name;
        proxy_cache_bypass $http_upgrade;
        
        # CORS headers for API
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS, PUT, DELETE";
        add_header Access-Control-Allow-Headers "Origin, Content-Type, Accept, Authorization, X-Requested-With";
        
        # Handle preflight requests
        if ($request_method = 'OPTIONS') {
            add_header Access-Control-Allow-Origin *;
            add_header Access-Control-Allow-Methods "GET, POST, OPTIONS, PUT, DELETE";
            add_header Access-Control-Allow-Headers "Origin, Content-Type, Accept, Authorization, X-Requested-With";
            add_header Access-Control-Max-Age 1728000;
            add_header Content-Type 'text/plain; charset=utf-8';
            add_header Content-Length 0;
            return 204;
        }
    }
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
}
EOF

# 4. Remove default nginx site
rm -f /etc/nginx/sites-enabled/default

# 5. Enable our site
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

# 6. Test nginx configuration
nginx -t

# 7. Start nginx
systemctl start nginx
systemctl enable nginx

# 8. Get SSL certificate using standalone mode first
echo "📜 Obtaining SSL certificate..."
certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos --email $EMAIL

# 9. Restart nginx to load SSL
systemctl restart nginx

# 10. Setup auto-renewal
echo "🔄 Setting up auto-renewal..."
crontab -l 2>/dev/null | { cat; echo "0 12 * * * /usr/bin/certbot renew --quiet && systemctl reload nginx"; } | crontab -

# 11. Update backend environment
echo "🔧 Updating backend configuration..."
cd ~/oauthTwitter

# Create new .env with HTTPS (localhost for development)
cat > .env << 'EOF'
NODE_ENV=production
PORT=3001
TWITTER_CLIENT_ID=T3pWbWVEY29pR3doaldteWhUdUI6MTpjaQ
TWITTER_CLIENT_SECRET=9R8RECRDHOuFpZCT_7U4FwrPYI4WjAGllHmJq52
TWITTER_REDIRECT_URI=https://localhost:5173/auth/twitter/callback
FIRESTARTER_API_BASE_URL=https://api2.khanhdev.tech/api/v1/trustcore
EOF

# 12. Restart Docker container with new config
echo "🐳 Restarting Docker container..."
docker stop oauth-twitter-backend || true
docker rm oauth-twitter-backend || true
docker build -t oauth-twitter-backend .
docker run -d \
  --name oauth-twitter-backend \
  --restart unless-stopped \
  -p 3001:3001 \
  --env-file .env \
  oauth-twitter-backend

# 13. Configure firewall
echo "🔥 Configuring firewall..."
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 22/tcp  # SSH
ufw --force enable

# 14. Wait for services to start
echo "⏳ Waiting for services to start..."
sleep 10

# 15. Test setup
echo "🧪 Testing HTTPS setup..."
echo "Testing HTTP redirect..."
curl -I http://$DOMAIN/ || echo "HTTP test failed"

echo "Testing HTTPS..."
curl -I https://$DOMAIN/health || echo "HTTPS test failed"

echo "Testing SSL certificate..."
openssl s_client -connect $DOMAIN:443 -servername $DOMAIN </dev/null 2>/dev/null | openssl x509 -noout -dates

echo ""
echo "✅ HTTPS setup completed!"
echo "🌐 Your API is now available at:"
echo "   https://thachdev.zapto.org/health"
echo "   https://thachdev.zapto.org/debug/env"
echo "   https://thachdev.zapto.org/api/twitter/exchange-and-connect"
echo ""
echo "🔒 SSL Certificate details:"
echo "   Domain: $DOMAIN"
echo "   Auto-renewal: Configured"
echo "   Certificate path: /etc/letsencrypt/live/$DOMAIN/"
echo ""
echo "🎯 Next steps:"
echo "   1. Update Twitter App callback URL to: https://$DOMAIN/auth/twitter/callback"
echo "   2. Update frontend API URL to: https://$DOMAIN"
echo "   3. Test OAuth flow end-to-end"
