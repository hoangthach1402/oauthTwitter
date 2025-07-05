@echo off
echo 🔒 Creating self-signed SSL certificate for localhost...

REM Create certs directory
if not exist "certs" mkdir certs
cd certs

REM Generate private key
openssl genrsa -out localhost.key 2048

REM Create certificate signing request config
echo [req] > localhost.conf
echo distinguished_name = req_distinguished_name >> localhost.conf
echo req_extensions = v3_req >> localhost.conf
echo prompt = no >> localhost.conf
echo. >> localhost.conf
echo [req_distinguished_name] >> localhost.conf
echo C = US >> localhost.conf
echo ST = State >> localhost.conf
echo L = City >> localhost.conf
echo O = Organization >> localhost.conf
echo OU = OrgUnit >> localhost.conf
echo CN = localhost >> localhost.conf
echo. >> localhost.conf
echo [v3_req] >> localhost.conf
echo basicConstraints = CA:FALSE >> localhost.conf
echo keyUsage = critical, digitalSignature, keyEncipherment >> localhost.conf
echo extendedKeyUsage = serverAuth >> localhost.conf
echo subjectAltName = @alt_names >> localhost.conf
echo. >> localhost.conf
echo [alt_names] >> localhost.conf
echo DNS.1 = localhost >> localhost.conf
echo DNS.2 = *.localhost >> localhost.conf
echo DNS.3 = 127.0.0.1 >> localhost.conf
echo IP.1 = 127.0.0.1 >> localhost.conf
echo IP.2 = ::1 >> localhost.conf

REM Generate certificate
openssl req -new -x509 -key localhost.key -out localhost.crt -days 365 -config localhost.conf -extensions v3_req

echo ✅ SSL certificate created!
echo 📁 Files: certs/localhost.key, certs/localhost.crt
echo 💡 Add certificate to Windows Trusted Root store for browser trust

cd ..
pause
