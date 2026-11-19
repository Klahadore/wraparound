#!/bin/bash
# Creates a local self-signed code-signing identity ("WrapAround Local Signing") in the
# login keychain. A stable identity means macOS keeps the Accessibility grant across rebuilds
# (ad-hoc signatures change every build, so the grant would be lost each time).
set -euo pipefail
NAME="WrapAround Local Signing"
if security find-certificate -c "$NAME" >/dev/null 2>&1; then echo "identity exists"; exit 0; fi
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/cfg" <<CFG
[req]
distinguished_name=dn
x509_extensions=ext
prompt=no
[dn]
CN=$NAME
[ext]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
CFG
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -days 3650 -config "$TMP/cfg"
/usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -out "$TMP/id.p12" -passout pass:wrap -name "$NAME"
security import "$TMP/id.p12" -k ~/Library/Keychains/login.keychain-db -P wrap -T /usr/bin/codesign
echo "created $NAME"
