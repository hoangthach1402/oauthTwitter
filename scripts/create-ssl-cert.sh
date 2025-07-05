#!/bin/bash
# create-ssl-cert.sh - Create self-signed SSL certificate for localhost

echo "🔒 Creating self-signed SSL certificate for localhost..."

# Create certs directory
mkdir -p certs
cd certs

# Generate private key
openssl genrsa -out localhost.key 2048

# Create certificate config
cat > localhost.conf << 'EOF'
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Organization
OU = OrgUnit
CN = localhost

[v3_req]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = *.localhost
DNS.3 = 127.0.0.1
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

# Generate certificate
openssl req -new -x509 -key localhost.key -out localhost.crt -days 365 -config localhost.conf -extensions v3_req

echo "✅ SSL certificate created!"
echo "📁 Files: certs/localhost.key, certs/localhost.crt"
echo "💡 For browser trust, add certificate to system trust store"

cd ..
