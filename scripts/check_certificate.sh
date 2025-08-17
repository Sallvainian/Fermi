#!/bin/bash
# Script to check certificate information
# Usage: ./check_certificate.sh path/to/certificate.p12 [password]

if [ $# -eq 0 ]; then
    echo "Usage: $0 <path-to-p12-file> [password]"
    exit 1
fi

CERT_PATH="$1"
PASSWORD="${2:-}"

if [ ! -f "$CERT_PATH" ]; then
    echo "Error: File not found: $CERT_PATH"
    exit 1
fi

echo "=== Certificate Information ==="
echo ""

# Check certificate info
if [ -n "$PASSWORD" ]; then
    echo "Certificate details:"
    openssl pkcs12 -in "$CERT_PATH" -passin "pass:$PASSWORD" -nokeys -clcerts 2>/dev/null | openssl x509 -noout -subject -issuer -dates -serial
    
    echo ""
    echo "Certificate Common Name (CN):"
    openssl pkcs12 -in "$CERT_PATH" -passin "pass:$PASSWORD" -nokeys -clcerts 2>/dev/null | openssl x509 -noout -subject | sed -n 's/.*CN=\([^/]*\).*/\1/p'
    
    echo ""
    echo "Certificate Type:"
    CN=$(openssl pkcs12 -in "$CERT_PATH" -passin "pass:$PASSWORD" -nokeys -clcerts 2>/dev/null | openssl x509 -noout -subject | sed -n 's/.*CN=\([^/]*\).*/\1/p')
    if [[ "$CN" == *"Distribution"* ]]; then
        echo "Apple Distribution Certificate"
    elif [[ "$CN" == *"Development"* ]] || [[ "$CN" == *"Developer"* ]]; then
        echo "Apple Development Certificate"
    else
        echo "Unknown type: $CN"
    fi
    
    echo ""
    echo "Team/Organization:"
    openssl pkcs12 -in "$CERT_PATH" -passin "pass:$PASSWORD" -nokeys -clcerts 2>/dev/null | openssl x509 -noout -subject | sed -n 's/.*O=\([^/]*\).*/\1/p'
    
    echo ""
    echo "Team ID (OU):"
    openssl pkcs12 -in "$CERT_PATH" -passin "pass:$PASSWORD" -nokeys -clcerts 2>/dev/null | openssl x509 -noout -subject | sed -n 's/.*OU=\([^/]*\).*/\1/p'
else
    echo "No password provided. Attempting to read without password..."
    openssl pkcs12 -in "$CERT_PATH" -nokeys -clcerts -passin pass: 2>/dev/null | openssl x509 -noout -subject -issuer -dates -serial || echo "Certificate requires a password."
fi

echo ""
echo "=== Import Instructions ==="
echo "To import this certificate into a keychain:"
echo "  security import \"$CERT_PATH\" -P \"PASSWORD\" -A -t cert -f pkcs12 -k ~/Library/Keychains/login.keychain-db"
echo ""
echo "For GitHub Actions, encode in base64:"
echo "  base64 -i \"$CERT_PATH\" | pbcopy"
echo "  (The base64 string is now in your clipboard)"