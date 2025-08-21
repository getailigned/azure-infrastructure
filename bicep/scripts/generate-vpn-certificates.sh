#!/bin/bash
# Generate certificates for Point-to-Site VPN authentication
# This script creates a self-signed root certificate and client certificates

set -e

CERT_DIR="azure/certificates"
ROOT_CERT_NAME="P2SRootCert"
CLIENT_CERT_NAME="P2SClientCert"

# Create certificates directory
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

echo "🔐 Generating VPN certificates for Point-to-Site authentication..."
echo "================================================================"

# Generate root certificate private key
echo "1. Generating root certificate private key..."
openssl genrsa -out "${ROOT_CERT_NAME}.key" 4096

# Generate root certificate
echo "2. Generating self-signed root certificate..."
openssl req -new -x509 -key "${ROOT_CERT_NAME}.key" -out "${ROOT_CERT_NAME}.crt" -days 3650 \
  -subj "/C=US/ST=WA/L=Seattle/O=HTMA/OU=Development/CN=HTMA-P2S-Root"

# Generate client certificate private key
echo "3. Generating client certificate private key..."
openssl genrsa -out "${CLIENT_CERT_NAME}.key" 4096

# Generate client certificate signing request
echo "4. Generating client certificate signing request..."
openssl req -new -key "${CLIENT_CERT_NAME}.key" -out "${CLIENT_CERT_NAME}.csr" \
  -subj "/C=US/ST=WA/L=Seattle/O=HTMA/OU=Development/CN=HTMA-P2S-Client"

# Sign client certificate with root certificate
echo "5. Signing client certificate with root certificate..."
openssl x509 -req -in "${CLIENT_CERT_NAME}.csr" -CA "${ROOT_CERT_NAME}.crt" -CAkey "${ROOT_CERT_NAME}.key" \
  -CAcreateserial -out "${CLIENT_CERT_NAME}.crt" -days 365

# Convert certificates to required formats
echo "6. Converting certificates to required formats..."

# Extract root certificate public key for Azure (base64 encoded, no headers)
openssl x509 -in "${ROOT_CERT_NAME}.crt" -outform DER | base64 -w 0 > "${ROOT_CERT_NAME}.b64"

# Create PKCS#12 file for client (includes private key)
echo "7. Creating PKCS#12 client certificate bundle..."
openssl pkcs12 -export -out "${CLIENT_CERT_NAME}.p12" \
  -inkey "${CLIENT_CERT_NAME}.key" \
  -in "${CLIENT_CERT_NAME}.crt" \
  -certfile "${ROOT_CERT_NAME}.crt" \
  -passout pass:htma2025

# Create certificate information file
cat > certificate-info.txt << EOF
HTMA Point-to-Site VPN Certificates
==================================

Generated: $(date)

Files created:
- ${ROOT_CERT_NAME}.crt          : Root certificate (public)
- ${ROOT_CERT_NAME}.key          : Root certificate private key (SECURE - do not share)
- ${ROOT_CERT_NAME}.b64          : Root certificate public key for Azure (base64)
- ${CLIENT_CERT_NAME}.crt        : Client certificate (public)
- ${CLIENT_CERT_NAME}.key        : Client certificate private key (SECURE - do not share)
- ${CLIENT_CERT_NAME}.p12        : Client certificate bundle for VPN client (password: htma2025)

Azure Configuration:
- Use the content of ${ROOT_CERT_NAME}.b64 as the rootCertData parameter in Bicep
- Install ${CLIENT_CERT_NAME}.p12 on client machines for VPN authentication

Security Notes:
- Keep .key files secure and never commit to version control
- Root certificate is valid for 10 years
- Client certificate is valid for 1 year
- Client certificate bundle password: htma2025

Client Setup:
1. Download and install the VPN client configuration from Azure
2. Install the ${CLIENT_CERT_NAME}.p12 certificate on your machine
3. Connect using the Azure VPN client
EOF

echo ""
echo "✅ Certificate generation completed!"
echo "📁 Certificates saved to: $(pwd)"
echo ""
echo "📋 Next steps:"
echo "1. Copy the content of ${ROOT_CERT_NAME}.b64 for Azure deployment"
echo "2. Install ${CLIENT_CERT_NAME}.p12 on client machines (password: htma2025)"
echo "3. Deploy VPN Gateway with the root certificate"
echo "4. Download VPN client configuration from Azure Portal"
echo ""
echo "🔐 Root certificate public key (for Azure):"
echo "======================================================"
cat "${ROOT_CERT_NAME}.b64"
echo ""
echo "======================================================"
echo ""
echo "⚠️  SECURITY WARNING: Keep .key files secure!"
echo "   Add azure/certificates/ to .gitignore to prevent accidental commits"
