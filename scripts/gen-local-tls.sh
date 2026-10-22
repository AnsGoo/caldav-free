#!/usr/bin/env bash
# Generate a local CA and a TLS server certificate for caldav-free.
#
# Usage:
#   scripts/gen-local-tls.sh [data-dir] [lan-ip] [hostname]
#
# Example:
#   scripts/gen-local-tls.sh ./data 192.168.124.8 my-mac
#
# The generated CA certificate can be installed on phones/clients. The CA
# private key stays on this machine and is never needed by clients.
set -euo pipefail

DATA_DIR="${1:-./data}"
LAN_IP="${2:-}"
HOST_NAME="${3:-}"

if [[ -z "$LAN_IP" ]]; then
  LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
fi
if [[ -z "$LAN_IP" ]]; then
  LAN_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
fi
if [[ -z "$HOST_NAME" ]]; then
  HOST_NAME="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
fi

TLS_DIR="${DATA_DIR}/tls"
mkdir -p "$TLS_DIR"
chmod 700 "$TLS_DIR"

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required" >&2
  exit 1
fi

cd "$TLS_DIR"

if [[ ! -s ca.crt || ! -s ca.key ]]; then
  echo "==> creating local CA"
  openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout ca.key -out ca.crt \
    -subj "/O=caldav-free/CN=caldav-free Local CA" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" \
    -addext "subjectKeyIdentifier=hash" >/dev/null 2>&1
else
  echo "==> reusing existing local CA"
fi

SAN="DNS:localhost,IP:127.0.0.1"
if [[ -n "$HOST_NAME" ]]; then
  SAN="${SAN},DNS:${HOST_NAME}.local"
fi
if [[ -n "$LAN_IP" ]]; then
  SAN="${SAN},IP:${LAN_IP}"
fi

cat > server-ext.cnf <<EOF
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
subjectAltName=${SAN}
EOF

echo "==> creating server certificate (SAN: ${SAN})"
openssl req -newkey rsa:2048 -sha256 -nodes \
  -keyout server.key -out server.csr \
  -subj "/O=caldav-free/CN=${LAN_IP:-localhost}" >/dev/null 2>&1
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 365 -sha256 -extfile server-ext.cnf >/dev/null 2>&1

rm -f server.csr server-ext.cnf
chmod 600 ca.key server.key
chmod 644 ca.crt server.crt

echo
echo "TLS files:"
echo "  CA certificate: $TLS_DIR/ca.crt"
echo "  Server cert:    $TLS_DIR/server.crt"
echo "  Server key:     $TLS_DIR/server.key"
echo
echo "Start caldav-free with:"
echo "  ./bin/caldav-free -addr :5232 -data \"$DATA_DIR\" \\"
echo "    -tls-cert \"$TLS_DIR/server.crt\" -tls-key \"$TLS_DIR/server.key\" \\"
echo "    -external-url \"https://${LAN_IP:-127.0.0.1}:5232\""
