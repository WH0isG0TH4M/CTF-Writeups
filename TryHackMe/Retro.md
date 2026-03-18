# Room: Retro
Difficulty: Hard

The first step in penetration testing is to enumerate open ports and services. I used:
``` bash
nmap -sC -sV -Pn -p- -T4 TARGET_IP
```
Result:
```
PORT     STATE SERVICE       VERSION
80/tcp   open  http          Microsoft IIS httpd 10.0
|_http-title: IIS Windows Server
| http-methods: 
|_  Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/10.0
3389/tcp open  ms-wbt-server Microsoft Terminal Services
|_ssl-date: 2026-03-14T07:34:24+00:00; +3s from scanner time.
| rdp-ntlm-info: 
|   Target_Name: RETROWEB
|   NetBIOS_Domain_Name: RETROWEB
|   NetBIOS_Computer_Name: RETROWEB
|   DNS_Domain_Name: RetroWeb
|   DNS_Computer_Name: RetroWeb
|   Product_Version: 10.0.14393
|_  System_Time: 2026-03-14T07:34:19+00:00
| ssl-cert: Subject: commonName=RetroWeb
| Not valid before: 2026-03-13T07:26:37
|_Not valid after:  2026-09-12T07:26:37
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows
```
From the scan, I identified:

- The target is running Windows

- A web server is hosted on port 80 (IIS)

- RDP (3389) is enabled

After visiting the website, it only showed the default IIS page. To discover hidden directories, I used ffuf and found:
``` bash
/retro
```
### Question: A web server is running on the target. What is the hidden directory which the website lives on?
### Answer: /retro

While browsing /retro, I found a blog authored by a user named Wade. In one of his posts (Ready Player One), he mentioned:
### “I keep mistyping the name of his avatar whenever I log in”
This suggests a potential password hint.

In the comments, Wade also wrote:
### “Leaving myself a note here just in case I forget how to spell it: parzival”

From this, I inferred:
- Username: Wade

- Password: parzival

 I then located a WordPress login page and used these credentials. The login was successful.

 Since RDP (port 3389) is open, I attempted to authenticate using the same credentials. The login was successful, granting me remote access to the system.
 
 After logging in via RDP, I was able to retrieve the user flag.
 
 While exploring the system, I discovered a potential privilege escalation vector: CVE-2019-1388. However, after multiple attempts, the exploit did not work because the link was not showing.

## Alternative Privilege Escalation

I gathered system information using:

``` bash
systeminfo
```
From this, I identified that the system is vulnerable to:

### CVE-2017-0213 (Windows Kernel Privilege Escalation)

I used the following exploit:
https://github.com/SecWiki/windows-kernel-exploits/blob/master/CVE-2017-0213/CVE-2017-0213_x86.zip

After transferring the exploit to the target machine and executing it, I successfully escalated privileges to:

``` bash
NT AUTHORITY\SYSTEM
```
